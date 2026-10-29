import 'package:flutter_test/flutter_test.dart';
import 'package:mind_dump/services/thought_analyzer.dart';

void main() {
  group('ThoughtAnalyzer', () {
    test('extracts tasks, urgency, emotion, and a tiny next step', () {
      final result = ThoughtAnalyzer.analyze(
        'I have to finish the proposal today. I feel overwhelmed by the deadline.',
      );

      expect(result.tasks, hasLength(1));
      expect(result.tasks.single.title, 'Finish the proposal today');
      expect(result.tasks.single.priority, 'High');
      expect(result.thoughts.last.emotion, 'Under pressure');
      expect(result.tinyStep, startsWith('Start with:'));
    });

    test('recognizes idea thoughts and non-task input', () {
      final result = ThoughtAnalyzer.analyze(
        'What if we create a calmer way to share ideas?',
      );

      expect(result.tasks, isEmpty);
      expect(result.thoughts.single.category, 'Idea');
      expect(result.tinyStep, contains('slow breath'));
    });
  });
}
