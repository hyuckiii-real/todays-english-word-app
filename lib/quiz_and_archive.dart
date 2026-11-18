import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';

class QuizScreen extends StatefulWidget {
  final List<WordItem> words;
  const QuizScreen({super.key, required this.words});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _questionIndex = 0;
  int _score = 0;
  bool _isCompleted = false;
  String? _selectedAnswer;
  List<String> _currentOptions = [];

  @override
  void initState() {
    super.initState();
    _setupQuestion();
  }

  void _setupQuestion() {
    if (widget.words.isEmpty) return;
    if (_questionIndex >= widget.words.length) {
      setState(() {
        _isCompleted = true;
      });
      return;
    }

    final currentWord = widget.words[_questionIndex];
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
    final currentWord = widget.words[_questionIndex];
    setState(() {
      _selectedAnswer = option;
      if (option == currentWord.summary) {
        _score++;
      }
    });
  }

  void _restartQuiz() {
    setState(() {
      _questionIndex = 0;
      _score = 0;
      _isCompleted = false;
      _selectedAnswer = null;
    });
    _setupQuestion();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) {
      return const Center(child: Text('퀴즈를 출제할 단어 데이터가 없습니다.'));
    }

    if (_isCompleted) {
      final total = widget.words.length;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                '오늘의 퀴즈 완료!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '총 $total문제 중 $_score문제를 맞혔습니다.',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _restartQuiz,
                icon: const Icon(Icons.refresh),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Text('처음부터 다시 풀기', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalCount = widget.words.length;
    final currentWord = widget.words[_questionIndex];
    final isLastQuestion = _questionIndex + 1 == totalCount;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '문제 ${_questionIndex + 1} / $totalCount',
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
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
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
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  isLastQuestion ? '결과 보기' : '다음 문제',
                  style: const TextStyle(fontSize: 16),
                ),
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
                      title: Text(
                        word.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
