import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../domain/workout.dart';
import 'theme.dart';

class CameraPlacementGuide extends StatelessWidget {
  const CameraPlacementGuide({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final squat = exercise == Exercise.squat;
    final above = _DiagramTile(
      exercise: exercise,
      overhead: true,
      title: 'From above',
      caption: squat ? '90° to the way you face' : '90° to your mat’s length',
      description: squat
          ? 'One phone goes directly to your left or right. The arrow points the way you face.'
          : 'One phone goes beside your torso, on either side. The arrow points toward your head.',
    );
    final height = _DiagramTile(
      exercise: exercise,
      overhead: false,
      title: 'Through the lens',
      caption: squat ? 'At standing hip height' : 'Low, at mid-torso height',
      description: squat
          ? 'Side profile of a standing person. The level line crosses their hip.'
          : 'Side profile of a person in a plank. The level line crosses the middle of their torso.',
    );
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              squat ? 'Squat camera setup' : 'Push-up camera setup',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, bounds) {
              final labelSize = MediaQuery.textScalerOf(context).scale(13);
              if (bounds.maxWidth < 260 * labelSize / 13) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [above, const SizedBox(height: 8), height],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: above),
                  const SizedBox(width: 8),
                  Expanded(child: height),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            squat
                ? 'Place the phone on either side and keep the lens level (0° tilt). Keep your shoulder, hip, knee and ankle in frame through the whole squat.'
                : 'Place the phone on either side and keep the lens level (0° tilt). Keep the near hand, elbow and shoulder visible, with your hips and feet in frame.',
            style: const TextStyle(color: soft),
          ),
        ],
      ),
    );
  }
}

class _DiagramTile extends StatelessWidget {
  const _DiagramTile({
    required this.exercise,
    required this.overhead,
    required this.title,
    required this.caption,
    required this.description,
  });

  final Exercise exercise;
  final bool overhead;
  final String title, caption, description;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF202C26),
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: soft,
            ),
          ),
          Semantics(
            image: true,
            label: description,
            child: ExcludeSemantics(
              child: SizedBox(
                width: double.infinity,
                height: 82,
                child: CustomPaint(
                  painter: _PlacementDrawing(exercise, overhead),
                ),
              ),
            ),
          ),
          Text(caption, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

class _PlacementDrawing extends CustomPainter {
  const _PlacementDrawing(this.exercise, this.overhead);
  final Exercise exercise;
  final bool overhead;

  static const _figure = Color(0xFFE4ECE3);
  static const _far = Color(0xFF83998B);
  static const _detail = Color(0xFF657B6D);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 148, size.height / 82);
    canvas.save();
    canvas.translate(
      (size.width - scale * 148) / 2,
      (size.height - scale * 82) / 2,
    );
    canvas.scale(scale);
    if (overhead) {
      _topView(canvas);
    } else {
      _lensView(canvas);
    }
    canvas.restore();
  }

  void _topView(Canvas canvas) {
    if (exercise == Exercise.pushUp) {
      final mat = RRect.fromRectAndRadius(
        const Rect.fromLTWH(52, 14, 44, 65),
        const Radius.circular(3),
      );
      canvas.drawRRect(mat, Paint()..color = const Color(0xFF29392E));
      canvas.drawRRect(mat, _line(_detail.withValues(alpha: .7), .9));
    }
    final cone = Path()
      ..moveTo(18, 43)
      ..lineTo(74, 25)
      ..lineTo(74, 61)
      ..close();
    canvas.drawPath(cone, Paint()..color = lime.withValues(alpha: .09));
    _dash(canvas, 21, 64, 43, lime);
    _dash(canvas, 84, 126, 43, _detail);
    _stroke(
      canvas,
      const [Offset(63, 40), Offset(67, 43), Offset(63, 46)],
      lime,
      1.8,
    );
    _stroke(
      canvas,
      const [Offset(84, 40), Offset(81, 43), Offset(84, 46)],
      _far,
      1.8,
    );
    _phone(canvas, 13, lime);
    _phone(canvas, 135, _far);
    _stroke(canvas, const [Offset(74, 21), Offset(74, 8)], amber, 1.7);
    _stroke(
      canvas,
      const [Offset(70, 12), Offset(74, 7), Offset(78, 12)],
      amber,
      1.7,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(74, 43), radius: 23),
      math.pi,
      math.pi / 2,
      false,
      _line(amber, 1.5),
    );
    if (exercise == Exercise.squat) {
      _stroke(canvas, const [Offset(67, 56), Offset(67, 63)], _far, 5);
      _stroke(canvas, const [Offset(81, 56), Offset(81, 63)], _far, 5);
      _stroke(canvas, const [Offset(74, 43), Offset(74, 51)], _far, 9);
      _stroke(
        canvas,
        const [
          Offset(60, 47),
          Offset(62, 42),
          Offset(74, 40),
          Offset(86, 42),
          Offset(88, 47),
        ],
        _figure,
        5.5,
      );
      canvas.drawOval(
        const Rect.fromLTWH(68, 32, 12, 13),
        Paint()..color = lime,
      );
      _stroke(
        canvas,
        const [Offset(72, 34), Offset(74, 31), Offset(76, 34)],
        lime,
        1.8,
      );
    } else {
      _stroke(
        canvas,
        const [Offset(71, 53), Offset(70, 66), Offset(69, 73)],
        _far,
        4,
      );
      _stroke(
        canvas,
        const [Offset(77, 53), Offset(78, 66), Offset(79, 73)],
        _figure,
        4,
      );
      _stroke(canvas, const [Offset(74, 34), Offset(74, 52)], _figure, 9);
      _stroke(
        canvas,
        const [
          Offset(57, 31),
          Offset(62, 42),
          Offset(65, 35),
          Offset(83, 35),
          Offset(86, 42),
          Offset(91, 31),
        ],
        _figure,
        3.5,
      );
      canvas.drawCircle(const Offset(74, 26), 5.5, Paint()..color = lime);
      for (final x in [57.0, 91.0]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, 30), width: 5, height: 3),
          Paint()..color = _figure,
        );
      }
    }
  }

  void _phone(Canvas canvas, double center, Color edge) {
    final outline = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center, 43), width: 10, height: 20),
      const Radius.circular(2.4),
    );
    canvas.drawRRect(outline, Paint()..color = ink);
    canvas.drawRRect(outline, _line(edge, 1.7));
    canvas.drawCircle(Offset(center, 37), 1.25, Paint()..color = edge);
    _stroke(
      canvas,
      [Offset(center - 2, 49), Offset(center + 2, 49)],
      edge,
      1.1,
    );
  }

  void _lensView(Canvas canvas) {
    const corners = [
      [Offset(4, 16), Offset(4, 8), Offset(13, 8)],
      [Offset(135, 8), Offset(144, 8), Offset(144, 16)],
      [Offset(144, 67), Offset(144, 75), Offset(135, 75)],
      [Offset(13, 75), Offset(4, 75), Offset(4, 67)],
    ];
    for (final corner in corners) {
      _stroke(canvas, corner, _detail, 1.4);
    }
    final squat = exercise == Exercise.squat;
    final level = squat ? 43.0 : 53.0;
    _dash(canvas, 10, 138, level, lime);
    _stroke(
      canvas,
      [Offset(8, level - 3), Offset(12, level), Offset(8, level + 3)],
      lime,
      1.6,
    );
    _stroke(canvas, const [Offset(14, 70), Offset(135, 70)], _detail, 1.1);
    if (squat) {
      _stroke(
        canvas,
        const [Offset(76, 43), Offset(70, 55), Offset(70, 67), Offset(76, 68)],
        _far,
        3.8,
      );
      _stroke(
        canvas,
        const [
          Offset(79, 24),
          Offset(76, 43),
          Offset(79, 55),
          Offset(78, 67),
          Offset(86, 68),
        ],
        _figure,
        4.8,
      );
      _stroke(
        canvas,
        const [Offset(79, 25), Offset(84, 32), Offset(90, 33)],
        _figure,
        3,
      );
      _head(canvas, const Offset(80, 17), true);
      _joint(canvas, const Offset(76, 43), lime);
      _joint(canvas, const Offset(79, 55), amber);
      _joint(canvas, const Offset(78, 67), _figure);
    } else {
      _stroke(
        canvas,
        const [Offset(51, 42), Offset(55, 55), Offset(53, 67), Offset(48, 68)],
        _far,
        3.4,
      );
      _stroke(
        canvas,
        const [Offset(85, 53), Offset(104, 60), Offset(121, 66)],
        _far,
        3.8,
      );
      _stroke(
        canvas,
        const [
          Offset(49, 41),
          Offset(83, 52),
          Offset(104, 59),
          Offset(122, 65),
          Offset(125, 69),
        ],
        _figure,
        4.8,
      );
      _stroke(
        canvas,
        const [Offset(49, 41), Offset(47, 54), Offset(46, 67), Offset(39, 68)],
        _figure,
        3.8,
      );
      _stroke(canvas, const [Offset(49, 41), Offset(43, 39)], _figure, 3.8);
      _head(canvas, const Offset(38, 37), false);
      _joint(canvas, const Offset(49, 41), _figure);
      _joint(canvas, const Offset(47, 54), amber);
      _joint(canvas, const Offset(46, 67), _figure);
      _joint(canvas, const Offset(83, 52), lime);
    }
  }

  void _head(Canvas canvas, Offset center, bool standing) {
    canvas.drawCircle(center, 4.9, Paint()..color = _figure);
    final nose = center + (standing ? const Offset(4, 1) : const Offset(-2, 4));
    canvas.drawCircle(nose, 1.7, Paint()..color = _figure);
  }

  void _joint(Canvas canvas, Offset at, Color color) {
    canvas.drawCircle(at, 3.2, Paint()..color = ink);
    canvas.drawCircle(at, 2.05, Paint()..color = color);
  }

  void _dash(Canvas canvas, double start, double end, double y, Color color) {
    final paint = _line(color, 1.3);
    for (var x = start; x < end; x += 6) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, end), y), paint);
    }
  }

  Paint _line(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _stroke(Canvas canvas, List<Offset> points, Color color, double width) {
    canvas.drawPath(Path()..addPolygon(points, false), _line(color, width));
  }

  @override
  bool shouldRepaint(_PlacementDrawing oldDelegate) =>
      oldDelegate.exercise != exercise || oldDelegate.overhead != overhead;
}

class LiveCameraAngles extends StatelessWidget {
  const LiveCameraAngles({
    super.key,
    required this.exercise,
    required this.placementLabel,
    required this.sideAngle,
    required this.lensTilt,
    required this.jointAngle,
  });

  final Exercise exercise;
  final String placementLabel;
  final double? sideAngle, lensTilt, jointAngle;

  @override
  Widget build(BuildContext context) {
    final squat = exercise == Exercise.squat;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (placementLabel.isNotEmpty)
            Text(
              placementLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (sideAngle case final estimate? when estimate.isFinite) ...[
            const SizedBox(height: 5),
            Semantics(
              container: true,
              label:
                  'Estimated camera angle ${estimate.round()} degrees. Target 90 degrees from either side.',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Side angle ≈${estimate.round()}°',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(
                    height: 14,
                    child: CustomPaint(painter: _AngleScale(estimate)),
                  ),
                  const Row(
                    textDirection: TextDirection.ltr,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '0° end-on',
                          style: TextStyle(fontSize: 12, color: soft),
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '90° side target',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 12, color: lime),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              if (sideAngle == null || !sideAngle!.isFinite)
                _reading('Side angle', null, target: '90°'),
              _reading('Lens tilt', lensTilt, target: '0°'),
              _reading(
                squat ? 'Live knee angle' : 'Live elbow angle',
                jointAngle,
                approx: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reading(
    String name,
    double? value, {
    bool approx = false,
    String? target,
  }) {
    final degrees = value != null && value.isFinite ? value.round() : null;
    final display = degrees == null ? '—' : '${approx ? '≈' : ''}$degrees°';
    final spoken = degrees == null
        ? 'unavailable'
        : '${approx ? 'about ' : ''}$degrees degrees';
    return Semantics(
      container: true,
      label: '$name, $spoken${target == null ? '' : ', target $target'}',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          style: const TextStyle(color: soft, fontSize: 13),
          children: [
            TextSpan(text: '$name '),
            TextSpan(
              text: display,
              style: const TextStyle(
                color: Color(0xFFF4F7F1),
                fontWeight: FontWeight.w800,
              ),
            ),
            if (target != null) TextSpan(text: ' · aim for $target'),
          ],
        ),
      ),
    );
  }
}

class _AngleScale extends CustomPainter {
  const _AngleScale(this.degrees);
  final double degrees;

  @override
  void paint(Canvas canvas, Size size) {
    const start = 5.0;
    final end = size.width - 5;
    if (end <= start) return;
    final center = size.height / 2;
    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF83998B);
    canvas.drawLine(Offset(start, center), Offset(end, center), paint);
    for (final tick in [start, (start + end) / 2, end]) {
      canvas.drawLine(
        Offset(tick, center - 3),
        Offset(tick, center + 3),
        paint,
      );
    }
    final mark = start + (end - start) * degrees.clamp(0, 90) / 90;
    canvas.drawCircle(Offset(mark, center), 5.5, Paint()..color = ink);
    canvas.drawCircle(Offset(mark, center), 4, Paint()..color = lime);
  }

  @override
  bool shouldRepaint(_AngleScale oldDelegate) => oldDelegate.degrees != degrees;
}
