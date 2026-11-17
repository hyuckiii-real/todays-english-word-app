import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TodaysWordApp());
}

/// 앱 설정 (추후 인물/요리 시리즈 복제 시 이 상수만 변경)
class AppConfig {
  static const String appName = '오늘의 영단어';
  static const String dataUrl =
      'https://raw.githubusercontent.com/hyuckiii-real/todays-x-data/main/data/daily_words.json';
  static const String cacheKey = 'cached_words_json_v1';
  static const String bookmarkKey = 'bookmarked_word_ids_v1';
}

class TodaysWordApp extends StatelessWidget {
  const TodaysWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E40AF), // 신뢰감 있는 딥 블루 테마
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: const MainScaffold(),
    );
  }
}

/// 데이터 모델
class WordItem {
  final int id;
  final String date;
  final String category;
  final String title;
  final String subtitle;
  final String summary;
  final String partOfSpeech;
  final List> examples;
  final List<String> synonyms;
  final List<String> quizDistractors;

  WordItem({
    required this.id,
    required this.date,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.partOfSpeech,
    required this.examples,
    required this.synonyms,
    required this.quizDistractors,
  });

  factory WordItem.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    final rawExamples = payload['examples'] as List<dynamic>? ?? [];
    return WordItem(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      category: json['category'] ?? '일반',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      summary: json['summary'] ?? '',
      partOfSpeech: payload['part_of_speech'] ?? '',
      examples: rawExamples
          .map((e) => {
                'en': (e['en'] ?? '').toString(),
                'ko': (e['ko'] ?? '').toString(),
              })
          .toList(),
      synonyms: List<String>.from(payload['synonyms'] ?? []),
      quizDistractors: List<String>.from(payload['quiz_distractors'] ?? []),
    );
  }
}

/// 메인 하단 탭 네비게이션 (오늘의 단어 / 미니 퀴즈 / 단어장)
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  List<WordItem> _words = [];
  Set<int> _bookmarkedIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  final FlutterTts _tts = FlutterTts();
  bool _isSlowSpeech = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadBookmarksAndSyncData();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.setSpeechRate(_isSlowSpeech ? 0.32 : 0.5);
    await _tts.speak(text);
  }

  Future<void> _loadBookmarksAndSyncData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final savedBookmarks = prefs.getStringList(AppConfig.bookmarkKey) ?? [];
    _bookmarkedIds = savedBookmarks.map(int.parse).toSet();

    // 1. 오프라인 캐시 먼저 로드
    final cachedJson = prefs.getString(AppConfig.cacheKey);
    if (cachedJson != null) {
      _parseAndSetWords(cachedJson);
    }

    // 2. GitHub 원격 JSON 풀링(Pulling)
    try {
      final response = await http
          .get(Uri.parse(AppConfig.dataUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        await prefs.setString(AppConfig.cacheKey, decodedBody);
        _parseAndSetWords(decodedBody);
      } else if (_words.isEmpty) {
        _errorMessage = '데이터를 불러오지 못했습니다. (HTTP ${response.statusCode})';
      }
    } catch (e) {
      if (_words.isEmpty) {
        _errorMessage = '네트워크 연결을 확인해 주세요.';
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _parseAndSetWords(String rawJson) {
    final Map<String, dynamic> data = json.decode(rawJson);
    final List<dynamic> items = data['items'] ?? [];
    if (mounted) {
      setState(() {
        _words = items.map((e) => WordItem.fromJson(e)).toList();
      });
    }
  }

  Future<void> _toggleBookmark(int id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_bookmarkedIds.contains(id)) {
        _bookmarkedIds.remove(id);
      } else {
        _bookmarkedIds.add(id);
      }
    });
    await prefs.setStringList(
      AppConfig.bookmarkKey,
      _bookmarkedIds.map((e) => e.toString()).toList(),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      TodayWordScreen(
        words: _words,
        bookmarkedIds: _bookmarkedIds,
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isSlowSpeech: _isSlowSpeech,
        onToggleSlow: () => setState(() => _isSlowSpeech = !_isSlowSpeech),
        onSpeak: _speak,
        onToggleBookmark: _toggleBookmark,
        onRefresh: _loadBookmarksAndSyncData,
      ),
      QuizScreen(words: _words),
      ArchiveScreen(
        words: _words,
        bookmarkedIds: _bookmarkedIds,
        onSpeak: _speak,
        onToggleBookmark: _toggleBookmark,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConfig.appName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '최신 단어 동기화',
            onPressed: _loadBookmarksAndSyncData,
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '오늘의 단어',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: '미니 퀴즈',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks),
            label: '단어장',
          ),
        ],
      ),
    );
  }
}

/// 1. 오늘의 단어 화면 (TTS + 예문 가리기 + 북마크)
class TodayWordScreen extends StatefulWidget {
  final List<WordItem> words;
  final Set<int> bookmarkedIds;
  final bool isLoading;
  final String? errorMessage;
  final bool isSlowSpeech;
  final VoidCallback onToggleSlow;
  final Future<void> Function(String) onSpeak;
  final Future<void> Function(int) onToggleBookmark;
  final Future<void> Function() onRefresh;

  const TodayWordScreen({
    super.key,
    required this.words,
    required this.bookmarkedIds,
    required this.isLoading,
    required this.errorMessage,
    required this.isSlowSpeech,
    required this.onToggleSlow,
    required this.onSpeak,
    required this.onToggleBookmark,
    required this.onRefresh,
  });

  @override
  State<TodayWordScreen> createState() => _TodayWordScreenState();
}

class _TodayWordScreenState extends State<TodayWordScreen> {
  bool _showMeaning = true;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.words.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.errorMessage != null && widget.words.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.errorMessage!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: widget.onRefresh,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    final todayWord = widget.words.first;
    final isBookmarked = widget.bookmarkedIds.contains(todayWord.id);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(
                label: Text('${todayWord.date} · ${todayWord.category}'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              FilterChip(
                label: Text(widget.isSlowSpeech ? '0.6x 느리게' : '1.0x 보통 속도'),
                selected: widget.isSlowSpeech,
                onSelected: (_) => widget.onToggleSlow(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          todayWord.title,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        iconSize: 30,
                        icon: Icon(
                          isBookmarked ? Icons.star : Icons.star_border,
                          color: isBookmarked ? Colors.amber : Colors.grey,
                        ),
                        onPressed: () => widget.onToggleBookmark(todayWord.id),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '${todayWord.subtitle}  ·  ${todayWord.partOfSpeech}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => widget.onSpeak(todayWord.title),
                        icon: const Icon(Icons.volume_up, size: 20),
                        label: const Text('발음 듣기'),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  InkWell(
                    onTap: () => setState(() => _showMeaning = !_showMeaning),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _showMeaning ? todayWord.summary : '터치하여 뜻 확인하기',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _showMeaning ? null : Colors.grey,
                            ),
                          ),
                          if (todayWord.synonyms.isNotEmpty && _showMeaning) ...[
                            const SizedBox(height: 8),
                            Text(
                              '유의어: ${todayWord.synonyms.join(', ')}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '실생활 예문',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...todayWord.examples.map(
            (ex) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  ex['en'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(ex['ko'] ?? ''),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.volume_up_outlined),
                  onPressed: () => widget.onSpeak(ex['en'] ?? ''),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. 4지선다 미니 퀴즈 화면
class QuizScreen extends StatefulWidget {
  final List<WordItem> words;
  const QuizScreen({super.key, required this.words});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _questionIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  List<String> _currentOptions = [];

  @override
  void initState() {
    super.initState();
    _setupQuestion();
  }

  void _setupQuestion() {
    if (widget.words.isEmpty) return;
    final currentWord = widget.words[_questionIndex % widget.words.length];
    final options = <String>[
      currentWord.summary,
      ...currentWord.quizDistractors.take(3),
    ];
    options.shuffle(Random());
    setState(() {
      _selectedAnswer = null;
      _currentOptions = options;
    });
  }

  void _submitAnswer(String option) {
    if (_selectedAnswer != null) return;
    final currentWord = widget.words[_questionIndex % widget.words.length];
    setState(() {
      _selectedAnswer = option;
      if (option == currentWord.summary) {
        _score++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) {
      return const Center(child: Text('퀴즈를 출제할 단어 데이터가 없습니다.'));
    }

    final currentWord = widget.words[_questionIndex % widget.words.length];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '문제 ${_questionIndex + 1}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '정답 수: $_score',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                children: [
                  Text(
                    currentWord.title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentWord.subtitle,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ..._currentOptions.map((option) {
            final isCorrect = option == currentWord.summary;
            final isSelected = option == _selectedAnswer;
            Color? tileColor;
            if (_selectedAnswer != null) {
              if (isCorrect) {
                tileColor = Colors.green.shade100;
              } else if (isSelected) {
                tileColor = Colors.red.shade100;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: tileColor,
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => _submitAnswer(option),
                child: Text(option, style: const TextStyle(fontSize: 16)),
              ),
            );
          }),
          const Spacer(),
          if (_selectedAnswer != null)
            FilledButton(
              onPressed: () {
                _questionIndex++;
                _setupQuestion();
              },
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('다음 문제', style: TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 3. 단어장 & 히스토리 화면 (북마크 필터 + 암기 모드)
class ArchiveScreen extends StatefulWidget {
  final List<WordItem> words;
  final Set<int> bookmarkedIds;
  final Future<void> Function(String) onSpeak;
  final Future<void> Function(int) onToggleBookmark;

  const ArchiveScreen({
    super.key,
    required this.words,
    required this.bookmarkedIds,
    required this.onSpeak,
    required this.onToggleBookmark,
  });

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  bool _onlyBookmarked = false;
  bool _hideMeanings = false;

  @override
  Widget build(BuildContext context) {
    final filtered = _onlyBookmarked
        ? widget.words.where((w) => widget.bookmarkedIds.contains(w.id)).toList()
        : widget.words;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('즐겨찾기만 보기'),
                selected: _onlyBookmarked,
                onSelected: (v) => setState(() => _onlyBookmarked = v),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('암기 모드 (뜻 가리기)'),
                selected: _hideMeanings,
                onSelected: (v) => setState(() => _hideMeanings = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('표시할 단어가 없습니다.'))
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final word = filtered[idx];
                    final isStar = widget.bookmarkedIds.contains(word.id);
                    return ListTile(
                      title: Text(
                        word.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _hideMeanings ? '••••••' : word.summary,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.volume_up_outlined),
                            onPressed: () => widget.onSpeak(word.title),
                          ),
                          IconButton(
                            icon: Icon(
                              isStar ? Icons.star : Icons.star_border,
                              color: isStar ? Colors.amber : null,
                            ),
                            onPressed: () => widget.onToggleBookmark(word.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
