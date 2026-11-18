import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'screens.dart';

void main() {
  runApp(const TodaysWordApp());
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
          seedColor: const Color(0xFF1E40AF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MainScaffold(),
    );
  }
}

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

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSlowSpeech = false;

  @override
  void initState() {
    super.initState();
    _loadBookmarksAndSyncData();
  }

  Future<void> _playAudio(String url) async {
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오디오 파일이 아직 준비되지 않았습니다.')),
        );
      }
      return;
    }
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setPlaybackRate(_isSlowSpeech ? 0.75 : 1.0);
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('음성 재생에 실패했습니다. 네트워크를 확인해 주세요.')),
        );
      }
    }
  }

  Future<void> _loadBookmarksAndSyncData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final savedBookmarks = prefs.getStringList(AppConfig.bookmarkKey) ?? [];
    _bookmarkedIds = savedBookmarks.map(int.parse).toSet();

    final cachedJson = prefs.getString(AppConfig.cacheKey);
    if (cachedJson != null) {
      _parseAndSetWords(cachedJson);
    }

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
    _audioPlayer.dispose();
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
        onPlayAudio: _playAudio,
        onToggleBookmark: _toggleBookmark,
        onRefresh: _loadBookmarksAndSyncData,
      ),
      QuizScreen(words: _words),
      ArchiveScreen(
        words: _words,
        bookmarkedIds: _bookmarkedIds,
        onPlayAudio: _playAudio,
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
