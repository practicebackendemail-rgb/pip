import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/domain/pip_emotion_state.dart';

void main() {
  group('PipEmotionState Unit Tests', () {
    test('initializes with neutral baseline values', () {
      final emotion = PipEmotionState();
      expect(emotion.valence, inInclusiveRange(0.0, 1.0));
      expect(emotion.energy, inInclusiveRange(0.0, 1.0));
      expect(emotion.bond, inInclusiveRange(0.0, 1.0));
      expect(emotion.boredom, inInclusiveRange(0.0, 1.0));
    });

    test('positive task completed event boosts valence and energy', () {
      final emotion = PipEmotionState();
      final initialValence = emotion.valence;
      emotion.onTaskCompleted();
      expect(emotion.valence, greaterThan(initialValence));
    });

    test('overdue task accumulation lowers valence', () {
      final emotion = PipEmotionState();
      final initialValence = emotion.valence;
      emotion.onOverdueAccumulation();
      expect(emotion.valence, lessThan(initialValence));
    });
  });
}
