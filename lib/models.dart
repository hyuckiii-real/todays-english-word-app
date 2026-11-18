class AppConfig {
  static const String appName = '오늘의 영단어';
  static const String dataUrl =
      'https://raw.githubusercontent.com/hyuckiii-real/todays-x-data/main/data/daily_words.json';
  static const String cacheKey = 'cached_words_json_v2';
  static const String bookmarkKey = 'bookmarked_word_ids_v1';
}

class ExampleSentence {
  final String en;
  final String ko;
  final String audioUrl;

  ExampleSentence({
    required this.en,
    required this.ko,
    required this.audioUrl,
  });

  factory ExampleSentence.fromJson(Map<String, dynamic> json) {
    return ExampleSentence(
      en: (json['en'] ?? '').toString(),
      ko: (json['ko'] ?? '').toString(),
      audioUrl: (json['audio_url'] ?? '').toString(),
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
  final String wordAudioUrl;
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
    required this.wordAudioUrl,
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
      wordAudioUrl: (payload['word_audio_url'] ?? '').toString(),
      examples: rawExamples
          .map((e) => ExampleSentence.fromJson(e as Map<String, dynamic>))
          .toList(),
      synonyms: rawSynonyms.map((e) => e.toString()).toList(),
      quizDistractors: rawDistractors.map((e) => e.toString()).toList(),
    );
  }
}
