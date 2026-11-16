enum Exercise {
  squat('Bodyweight squat', true),
  pushUp('Floor push-up', true),
  dumbbellRow('Dumbbell row', false),
  shoulderPress('Shoulder press', false),
  other('Other exercise', false);

  const Exercise(this.label, this.cameraSupported);
  final String label;
  final bool cameraSupported;
}

enum RepOutcome { passed, needsCorrection, unassessed }

enum Cue {
  squatDepth('Try to reach your squat depth target.'),
  pushUpDepth('Try to reach your push-up depth target.'),
  bodyLine('Keep your hips in line with your shoulders and ankles.'),
  repeat('Keep the same range on your next set.'),
  reframe('Keep your whole body in the camera frame.');

  const Cue(this.message);
  final String message;
}

enum TrackingStatus { reposition, getReady, ready, moving }

final class RepResult {
  const RepResult(this.outcome, [this.cue]);
  final RepOutcome outcome;
  final Cue? cue;
}

final class SetRecord {
  SetRecord({
    required this.id,
    required this.sessionId,
    required this.exercise,
    required this.at,
    List<RepResult> reps = const [],
    this.manualReps,
    this.weightKg,
    this.profile,
  }) : reps = List.unmodifiable(reps);

  final String id;
  final String sessionId;
  final Exercise exercise;
  final DateTime at;
  final List<RepResult> reps;
  final int? manualReps;
  final double? weightKg;
  final String? profile;
  bool get isCamera => manualReps == null;
  int get total => manualReps ?? reps.length;
  int get passed => count(RepOutcome.passed);
  int get needsCorrection => count(RepOutcome.needsCorrection);
  int get unassessed => count(RepOutcome.unassessed);
  int get assessed => passed + needsCorrection;
  int count(RepOutcome outcome) =>
      reps.where((rep) => rep.outcome == outcome).length;
}

enum CoachSource {
  onDevice('On device'),
  cloud('Cloud'),
  builtIn('Built-in cue');

  const CoachSource(this.label);
  final String label;
}

final class CoachAdvice {
  const CoachAdvice(this.cue, this.observation, this.source);
  final Cue cue;
  final String observation;
  final CoachSource source;
}
