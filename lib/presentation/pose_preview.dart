import 'package:flutter/widgets.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../application/pose_frame.dart';
import '../application/pose_overlay_filter.dart';
import 'theme.dart';

/// The image and skeleton share a frame and a contain-fit transform.
class PosePreview extends StatelessWidget {
  const PosePreview({super.key, required this.frame});
  final PoseFrame frame;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: PosePainter(frame), size: Size.infinite);
}

class PosePainter extends CustomPainter {
  const PosePainter(this.frame);
  final PoseFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    frame.geometry.paintImage(canvas, size, frame.image);
    if (frame.people.length == 1) {
      final joints = frame.people.single;
      for (final (start, end) in PoseLandmarksConnections.all) {
        if (end >= joints.length || start >= joints.length) continue;
        if (!PoseOverlayFilter.canDraw(joints[start]) ||
            !PoseOverlayFilter.canDraw(joints[end])) {
          continue;
        }
        final a = frame.geometry.project(joints[start], size);
        final b = frame.geometry.project(joints[end], size);
        final uncertain =
            joints[start].visibility < .65 || joints[end].visibility < .65;
        _bone(canvas, a, b, uncertain);
      }
      // Draw every supported landmark, including the nose, fingers and heels.
      for (var i = 0; i < joints.length; i++) {
        final point = joints[i];
        if (!PoseOverlayFilter.canDraw(point)) continue;
        final at = frame.geometry.project(point, size);
        final radius = i < 11 ? 1.7 : 2.6;
        canvas.drawCircle(
          at,
          radius + 1.2,
          Paint()..color = const Color(0xFF132019),
        );
        canvas.drawCircle(
          at,
          radius,
          Paint()
            ..color = lime.withValues(alpha: point.visibility < .65 ? .7 : 1),
        );
      }
    }
    canvas.restore();
  }

  void _bone(Canvas canvas, Offset a, Offset b, bool uncertain) {
    final outline = Paint()
      ..color = const Color(0xFF132019)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = lime.withValues(alpha: uncertain ? .7 : 1)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    if (!uncertain) {
      canvas.drawLine(a, b, outline);
      canvas.drawLine(a, b, line);
      return;
    }
    final delta = b - a;
    final length = delta.distance;
    if (length == 0) return;
    for (var from = 0.0; from < length; from += 9) {
      final to = (from + 5).clamp(0.0, length);
      final start = a + delta * (from / length);
      final end = a + delta * (to / length);
      canvas.drawLine(start, end, outline);
      canvas.drawLine(start, end, line);
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) =>
      oldDelegate.frame != frame;
}
