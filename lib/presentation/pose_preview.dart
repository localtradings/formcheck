import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../application/pose_frame.dart';
import '../application/pose_overlay_filter.dart';
import '../domain/rep_analyzer.dart';
import '../domain/workout.dart';
import 'theme.dart';

typedef MeasuredJoint = ({Exercise exercise, int side});

/// The image and skeleton share a frame and a contain-fit transform.
class PosePreview extends StatelessWidget {
  const PosePreview({super.key, required this.frame, this.measuredJoint});
  final PoseFrame frame;
  final MeasuredJoint? measuredJoint;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: PosePainter(frame, measuredJoint: measuredJoint),
    size: Size.infinite,
  );
}

class PosePainter extends CustomPainter {
  const PosePainter(this.frame, {this.measuredJoint});
  final PoseFrame frame;
  final MeasuredJoint? measuredJoint;

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
      if (measuredJoint case final measured?) {
        _highlightBend(canvas, size, joints, measured);
      }
    }
    canvas.restore();
  }

  void _highlightBend(
    Canvas canvas,
    Size size,
    List<Joint> joints,
    MeasuredJoint measured,
  ) {
    if (!measured.exercise.cameraSupported ||
        (measured.side != 0 && measured.side != 1)) {
      return;
    }
    // MediaPipe's left and right landmarks alternate along each limb.
    final first =
        (measured.exercise == Exercise.squat ? 23 : 11) + measured.side;
    if (first + 4 >= joints.length) return;
    final upper = joints[first],
        bend = joints[first + 2],
        lower = joints[first + 4];
    if (!upper.visible || !bend.visible || !lower.visible) return;
    final center = frame.geometry.project(bend, size);
    final a = frame.geometry.project(upper, size) - center;
    final b = frame.geometry.project(lower, size) - center;
    final radius = math.min(16.0, math.min(a.distance, b.distance) * .35);
    if (radius < 5) return;
    final sweep = math.atan2(
      a.dx * b.dy - a.dy * b.dx,
      a.dx * b.dx + a.dy * b.dy,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final arc = Rect.fromCircle(center: center, radius: radius);
    // A straight limb has no distinct inside. Keep the joint ring steady there.
    final showArc = sweep.abs() < math.pi * .95;
    for (final (color, width) in [(ink, 4.5), (amber, 2.0)]) {
      paint
        ..color = color
        ..strokeWidth = width;
      canvas.drawCircle(center, 4.6, paint);
      if (showArc) canvas.drawArc(arc, a.direction, sweep, false, paint);
    }
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
      oldDelegate.frame != frame || oldDelegate.measuredJoint != measuredJoint;
}
