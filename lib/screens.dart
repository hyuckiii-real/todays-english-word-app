import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';

class TodayWordScreen extends StatefulWidget {
  final List<WordItem> words;
  final Set<int> bookmarkedIds;
  final bool isLoading;
  final String? errorMessage;
  final bool isSlowSpeech;
  final VoidCallback onToggleSlow;
  final Future<void> Function(String) onPlayAudio;
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
    required this.onPlayAudio,
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
                label: Text(widget.isSlowSpeech ? '0.75x 느리게' : '1.0x 보통 속도'),
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
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => widget.onPlayAudio(todayWord.wordAudioUrl),
                        icon: const Icon(Icons.volume_up, size: 20),
                        label: const Text('원어민 발음'),
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
                            .withValues(alpha: 0.5),
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
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
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
          const Text('실생활 예문', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...todayWord.examples.map(
            (ex) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(ex.en, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(ex.ko),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.volume_up_outlined),
                  onPressed: () => widget.onPlayAudio(ex.audioUrl),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
              Text('문제 ${_questionIndex + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('정답 수: $_score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                children: [
                  Text(currentWord.title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(currentWord.subtitle, style: TextStyle(color: Colors.grey.shade600)),
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
              if (isCorrect) tileColor = Colors.green.shade100;
              else if (isSelected) tileColor = Colors.red.shade100;
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

class ArchiveScreen extends StatefulWidget {
  final List<WordItem> words;
  final Set<int> bookmarkedIds;
  final Future<void> Function(String) onPlayAudio;
  final Future<void> Function(int) onToggleBookmark;

  const ArchiveScreen({
    super.key,
    required this.words,
    required this.bookmarkedIds,
    required this.onPlayAudio,
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
                      title: Text(word.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_hideMeanings ? '••••••' : word.summary),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.volume_up_outlined),
                            onPressed: () => widget.onPlayAudio(word.wordAudioUrl),
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
