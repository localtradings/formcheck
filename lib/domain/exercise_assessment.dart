import 'camera_placement.dart';
import 'phone_level.dart';
import 'rep_analyzer.dart';
import 'workout.dart';

/// Keeps placement and form evidence tied to the same camera frame.
final class ExerciseAssessment {
  ExerciseAssessment(Exercise exercise)
    : _placement = CameraPlacement(exercise),
      _reps = RepAnalyzer(exercise);

  final CameraPlacement _placement;
  final RepAnalyzer _reps;
  PlacementReading placement = const PlacementReading.unknown();
  PhoneLevel? level;
  double? get jointAngleDegrees => _reps.jointAngleDegrees;
  int? get measuredSide => _reps.measuredSide;
  Cue? get setupCue => _reps.setupCue;

  String get placementLabel => switch (placement.view) {
    PlacementView.side => 'Side view looks good',
    PlacementView.moveToSide => 'Move the phone to either side of your body',
    PlacementView.unknown => 'Checking your side view',
  };

  String? get adjustment {
    if (level?.pitchDegrees == null && level != null) {
      return 'Let the phone settle on a steady surface.';
    }
    if (level?.tilted == true) return 'Aim the lens straight ahead and level.';
    if (level?.rolled == true) return 'Straighten the phone in its stand.';
    if (placement.view == PlacementView.moveToSide) return placementLabel;
    return null;
  }

  Analysis accept(
    PoseSample sample,
    List<WorldJoint> world,
    PhoneLevel? atFrame,
  ) {
    level = atFrame;
    placement = _placement.update(sample, world);
    if (placement.blockAssessment || atFrame?.blocksAssessment == true) {
      _reps.reset();
      return (status: TrackingStatus.reposition, rep: null, cue: null);
    }
    return _reps.accept(sample);
  }

  void reset() {
    _placement.reset();
    _reps.reset();
    placement = const PlacementReading.unknown();
    level = null;
  }
}
