class ThoughtTask {
  const ThoughtTask({
    required this.id,
    required this.title,
    required this.priority,
    this.isComplete = false,
  });

  final String id;
  final String title;
  final String priority;
  final bool isComplete;

  ThoughtTask copyWith({
    String? title,
    String? priority,
    bool? isComplete,
  }) {
    return ThoughtTask(
      id: id,
      title: title ?? this.title,
      priority: priority ?? this.priority,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'priority': priority,
        'isComplete': isComplete,
      };

  factory ThoughtTask.fromJson(Map<String, dynamic> json) => ThoughtTask(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        priority: json['priority'] as String? ?? 'Medium',
        isComplete: json['isComplete'] as bool? ?? false,
      );
}

class ThoughtInsight {
  const ThoughtInsight({
    required this.text,
    required this.category,
    required this.priority,
    this.emotion,
  });

  final String text;
  final String category;
  final String priority;
  final String? emotion;

  Map<String, dynamic> toJson() => {
        'text': text,
        'category': category,
        'priority': priority,
        'emotion': emotion,
      };

  factory ThoughtInsight.fromJson(Map<String, dynamic> json) => ThoughtInsight(
        text: json['text'] as String? ?? '',
        category: json['category'] as String? ?? 'Thought',
        priority: json['priority'] as String? ?? 'Low',
        emotion: json['emotion'] as String?,
      );
}

class ThoughtDump {
  const ThoughtDump({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.thoughts,
    required this.tinyStep,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final List<ThoughtInsight> thoughts;
  final String tinyStep;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'thoughts': thoughts.map((thought) => thought.toJson()).toList(),
        'tinyStep': tinyStep,
      };

  factory ThoughtDump.fromJson(Map<String, dynamic> json) => ThoughtDump(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        thoughts: (json['thoughts'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ThoughtInsight.fromJson)
            .toList(),
        tinyStep: json['tinyStep'] as String? ?? '',
      );
}
