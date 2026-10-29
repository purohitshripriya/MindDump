import '../models.dart';

class ThoughtAnalysis {
  const ThoughtAnalysis({
    required this.thoughts,
    required this.tasks,
    required this.tinyStep,
  });

  final List<ThoughtInsight> thoughts;
  final List<ThoughtTask> tasks;
  final String tinyStep;
}

class ThoughtAnalyzer {
  static final _taskPattern = RegExp(
    r'\b(need to|have to|has to|should|must|remember to|don.t forget to|'
    r'plan to|want to|call|email|message|write|finish|complete|submit|'
    r'prepare|schedule|book|buy|pick up|send|review|clean|pay|ask|talk to)\b',
    caseSensitive: false,
  );

  static const _highPriorityWords = [
    'urgent',
    'asap',
    'today',
    'deadline',
    'overdue',
    'immediately',
  ];

  static const _positiveWords = [
    'excited',
    'happy',
    'grateful',
    'great',
    'proud',
    'hopeful',
    'love',
  ];

  static const _stressWords = [
    'stressed',
    'overwhelmed',
    'anxious',
    'worried',
    'pressure',
    'too much',
    'tired',
  ];

  static const _ideaWords = [
    'idea',
    'imagine',
    'could build',
    'what if',
    'create',
    'concept',
    'maybe we',
  ];

  static ThoughtAnalysis analyze(String input) {
    final lines = input
        .split(RegExp(r'[\n.!?]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final thoughts = <ThoughtInsight>[];
    final tasks = <ThoughtTask>[];

    for (final line in lines) {
      final lower = line.toLowerCase();
      final isTask = _taskPattern.hasMatch(line) ||
          RegExp(r'^(buy|call|email|write|finish|submit|book|send)\b',
                  caseSensitive: false)
              .hasMatch(line);
      final priority = _priorityFor(lower, isTask);
      final emotion = _containsAny(lower, _stressWords)
          ? 'Under pressure'
          : _containsAny(lower, _positiveWords)
              ? 'Feeling good'
              : null;
      final category = isTask
          ? 'Action'
          : _containsAny(lower, _ideaWords)
              ? 'Idea'
              : _containsAny(lower, ['work', 'project', 'meeting', 'client'])
                  ? 'Work'
                  : 'Thought';

      thoughts.add(ThoughtInsight(
        text: line,
        category: category,
        priority: priority,
        emotion: emotion,
      ));

      if (isTask) {
        final title = line.replaceFirst(
          RegExp(r'^(i need to|i have to|i should|i must)\s+', caseSensitive: false),
          '',
        );
        tasks.add(ThoughtTask(
          id: '${DateTime.now().microsecondsSinceEpoch}-${tasks.length}',
          title: title[0].toUpperCase() + title.substring(1),
          priority: priority,
        ));
      }
    }

    final tinyStep = tasks.isNotEmpty
        ? 'Start with: ${_firstWords(tasks.first.title, 8)}'
        : thoughts.isNotEmpty
            ? 'Take one slow breath, then choose the thought that matters most.'
            : 'Write one thing that has been taking up space in your mind.';

    return ThoughtAnalysis(thoughts: thoughts, tasks: tasks, tinyStep: tinyStep);
  }

  static String _priorityFor(String text, bool isTask) {
    if (_containsAny(text, _highPriorityWords)) return 'High';
    if (text.contains('sometime') ||
        text.contains('one day') ||
        text.contains('maybe')) {
      return 'Low';
    }
    return isTask ? 'Medium' : 'Low';
  }

  static bool _containsAny(String text, List<String> words) =>
      words.any(text.contains);

  static String _firstWords(String text, int limit) {
    final words = text.split(RegExp(r'\s+'));
    return words.length <= limit ? text : '${words.take(limit).join(' ')}…';
  }
}
