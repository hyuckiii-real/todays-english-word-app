import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TodaysWordApp());
}

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
          seedColor: const Color(0xFF1E40AF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MainScaffold(),
    );
  }
}

class ExampleSentence {
  final String en;
  final String ko;

  ExampleSentence({required this.en, required this.ko});

  factory ExampleSentence.fromJson(Map<String, dynamic> json) {
    return ExampleSentence(
      en: (json['en'] ?? '').toString(),
      ko: (json['ko'] ?? '').toString(),
    );
  }
}

class WordItem {
  final int id;
  final String date;
  final String category;
  final String title;
  final String subtitle;
  final String summary;
  final String partOfSpeech;
  final List<ExampleSentence> examples;
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
    final rawSynonyms = payload['synonyms'] as List<dynamic>? ?? [];
    final rawDistractors = payload['quiz_distractors'] as List<dynamic>? ?? [];

    return WordItem(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      category: json['category'] ?? '일반',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      summary: json['summary'] ?? '',
      partOfSpeech: payload['part_of_speech'] ?? '',
      examples: rawExamples
          .map((e) => ExampleSentence.fromJson(e as Map<String, dynamic>))
          .toList(),
      synonyms: rawSynonyms.map((e) => e.toString()).toList(),
      quizDistractors: rawDistractors.map((e) => e.toString()).toList(),
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
