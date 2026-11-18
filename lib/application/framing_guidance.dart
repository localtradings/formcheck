import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../domain/camera_framing.dart';
import '../domain/workout.dart';

String? framingPrompt(
  FramingIssue issue,
  Exercise exercise, {
  bool dim = false,
}) {
  return switch (issue) {
    FramingIssue.clear => null,
    FramingIssue.searching when dim =>
      'The view is dark. Check the lens or turn on a light.',
    FramingIssue.searching => 'Step into view so the camera can see your body.',
    FramingIssue.multiplePeople =>
      'Two people are in view. Keep only yourself in the frame.',
    FramingIssue.tooClose =>
      'Move the phone farther back so your whole body fits.',
    FramingIssue.tooFar =>
      'Move closer to the camera so your joints are easier to see.',
    FramingIssue.offCenter => 'Move toward the middle of the camera view.',
    FramingIssue.missingLegs =>
      exercise == Exercise.squat
          ? 'Keep your hips, knees and feet in view. Move the phone back if needed.'
          : 'Keep your hips and feet in view from the side.',
    FramingIssue.missingArms =>
      'Keep your shoulder, elbow and hand visible on the same side.',
    FramingIssue.missingTorso =>
      'Turn sideways so one shoulder and hip are clearly visible.',
  };
}

bool isDarkCameraFrame(VisionImage image) {
  final pixels = image.pixels!;
  final width = image.width!, height = image.height!;
  final stride = image.bytesPerRow!;
  final red = image.format == VisionPixelFormat.bgra ? 2 : 0;
  var dark = 0;
  for (var row = 0; row < 8; row++) {
    final y = (2 * row + 1) * height ~/ 16;
    for (var col = 0; col < 8; col++) {
      final x = (2 * col + 1) * width ~/ 16;
      final offset = y * stride + x * 4;
      final luma =
          54 * pixels[offset + red] +
          183 * pixels[offset + 1] +
          19 * pixels[offset + 2 - red];
      if (luma < 40 * 256) dark++;
    }
  }
  return dark >= 58;
}
