import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/pose_capture.dart';
import '../application/providers.dart';
import '../domain/workout.dart';
import 'theme.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({
    super.key,
    required this.active,
    required this.exercise,
    required this.onExercise,
  });

  final bool active;
  final Exercise exercise;
  final ValueChanged<Exercise> onExercise;

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver {
  late final PoseCapture _capture;
  String _sessionId = newWorkoutId();
  String? _setId;
  bool _requested = false;
  bool _foreground = true;
  List<RepResult>? _pendingReps;
  Exercise? _pendingExercise;
  SetRecord? _review;
  CoachAdvice? _advice;
  bool _saving = false;
  bool _coaching = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _capture = ref.read(cameraProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant CameraPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exercise != oldWidget.exercise &&
        !_capture.recording &&
        _pendingReps == null) {
      _review = null;
      _advice = null;
      _sessionId = newWorkoutId();
    }
    if (widget.active != oldWidget.active ||
        widget.exercise != oldWidget.exercise) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncCapture();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncCapture();
  }

  void _syncCapture() {
    if (_foreground &&
        widget.active &&
        _requested &&
        _review == null &&
        _pendingReps == null) {
      unawaited(_capture.open(widget.exercise));
    } else {
      unawaited(_capture.close().catchError((Object _) {}));
    }
  }

  void _open() {
    setState(() => _requested = true);
    _syncCapture();
  }

  void _start() {
    _setId = newWorkoutId();
    _capture.begin();
  }

  Future<void> _finish() async {
    if (_saving) return;
    if (_pendingReps == null) {
      final reps = _capture.finish();
      if (reps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complete a rep to save your set.')),
        );
        return;
      }
      _pendingReps = reps;
      _pendingExercise = widget.exercise;
      unawaited(_capture.close().catchError((Object _) {}));
    }
    final store = ref.read(workoutStoreProvider);
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final saved = await store.saveCamera(
        _setId!,
        _sessionId,
        _pendingExercise!,
        _pendingReps!,
      );
      if (!mounted) return;
      setState(() {
        _pendingReps = null;
        _pendingExercise = null;
        _review = saved;
        _advice = null;
      });
    } on Object {
      if (mounted) {
        setState(
          () =>
              _saveError = 'Couldn’t save this set. Your reps are still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _coach() async {
    final record = _review;
    if (record == null || _coaching) return;
    final coach = ref.read(coachProvider);
    setState(() => _coaching = true);
    final advice = await coach.review(record);
    if (!mounted) return;
    setState(() {
      _coaching = false;
      if (_review?.id == record.id) _advice = advice;
    });
  }

  void _retry() {
    setState(() {
      _review = null;
      _advice = null;
    });
    _open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_capture.close().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _capture,
    builder: (context, _) {
      final record = _review;
      return PageBody(
        children: [
          Row(
            children: [
              const Icon(
                Icons.center_focus_strong_rounded,
                color: lime,
                size: 26,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'FormCheck',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (record != null)
            _Review(
              record: record,
              advice: _advice,
              coaching: _coaching,
              onCoach: _coach,
              onRetry: _retry,
            )
          else if (_pendingReps != null)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Set results'),
                  const SizedBox(height: 10),
                  _Counts(reps: _pendingReps!),
                  const SizedBox(height: 12),
                  if (_saveError != null)
                    Semantics(liveRegion: true, child: Text(_saveError!)),
                  const SizedBox(height: 12),
                  RaisedAction(
                    label: _saving ? 'Saving…' : 'Retry save',
                    onPressed: _saving ? null : _finish,
                  ),
                ],
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final exercise in [Exercise.squat, Exercise.pushUp])
                  ChoiceChip(
                    label: Text(
                      exercise == Exercise.squat ? 'Squat' : 'Push-up',
                    ),
                    selected: exercise == widget.exercise,
                    onSelected: _capture.recording
                        ? null
                        : (_) => widget.onExercise(exercise),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _Stage(capture: _capture, exercise: widget.exercise),
            const SizedBox(height: 10),
            if (_capture.camera != null || _capture.recording)
              _Counts(reps: _capture.reps),
            if (_capture.camera != null)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _capture.canFlip && !_capture.busy
                        ? _capture.flip
                        : null,
                    icon: const Icon(Icons.flip_camera_android_outlined),
                    label: const Text('Flip camera'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _capture.setVoiceEnabled(!_capture.voiceEnabled),
                    icon: Icon(
                      _capture.voiceEnabled
                          ? Icons.volume_up_outlined
                          : Icons.volume_off_outlined,
                    ),
                    label: Text(
                      _capture.voiceEnabled ? 'Voice on' : 'Voice off',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            if (_capture.camera == null)
              RaisedAction(
                label: _capture.busy ? 'Opening camera…' : 'Open camera',
                icon: Icons.videocam_outlined,
                onPressed: _capture.busy ? null : _open,
              )
            else if (_capture.recording)
              RaisedAction(
                label: 'Finish set',
                icon: Icons.stop_rounded,
                onPressed: _finish,
              )
            else
              RaisedAction(
                label: 'Start set',
                icon: Icons.play_arrow_rounded,
                onPressed: _capture.status == TrackingStatus.ready
                    ? _start
                    : null,
              ),
            if (_capture.recording && _capture.camera == null)
              TextButton(
                onPressed: _finish,
                child: const Text('Finish with saved reps'),
              ),
            if (_capture.needsSettings)
              TextButton(
                onPressed: _capture.openSettings,
                child: const Text('Open camera settings'),
              ),
          ],
        ],
      );
    },
  );
}

class _Stage extends StatelessWidget {
  const _Stage({required this.capture, required this.exercise});
  final PoseCapture capture;
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final camera = capture.camera;
    final status = switch (capture.status) {
      TrackingStatus.reposition => 'Move into a clear side view',
      TrackingStatus.getReady =>
        exercise == Exercise.squat
            ? 'Stand tall to get ready'
            : 'Hold the top of a push-up',
      TrackingStatus.ready =>
        capture.recording ? 'Ready for the next rep' : 'Ready to start',
      TrackingStatus.moving => 'Tracking this rep',
    };
    final aspect = capture.previewAspect;
    final cue = capture.cue;
    return Semantics(
      container: true,
      label: 'Camera form check',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF18201E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (camera != null && aspect != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final height = math.min(constraints.maxWidth / aspect, 420.0);
                  return SizedBox(
                    height: height,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: aspect,
                        child: CameraPreview(
                          camera,
                          child: CustomPaint(
                            painter: _Skeleton(capture.points),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 32,
                ),
                child: Column(
                  children: [
                    Icon(
                      exercise == Exercise.squat
                          ? Icons.accessibility_new_rounded
                          : Icons.fitness_center_rounded,
                      size: 42,
                      color: lime,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      exercise.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      exercise == Exercise.squat
                          ? 'Set the phone at your side. Keep your shoulders, hips and feet visible.'
                          : 'Set the phone low and at your side. Keep your shoulders, hands and feet visible.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: soft),
                    ),
                  ],
                ),
              ),
            if (camera != null || capture.error != null || capture.busy)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
                color: const Color(0xFF27312D),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    capture.error ??
                        (capture.busy
                            ? 'Starting camera…'
                            : cue?.message ?? status),
                    style: TextStyle(
                      color: cue != null ? amber : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends CustomPainter {
  const _Skeleton(this.points);
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    final limbs = Paint()
      ..color = lime
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    bool visible(int index) => index < points.length && points[index].dx >= 0;
    Offset at(int index) =>
        Offset(points[index].dx * size.width, points[index].dy * size.height);
    for (final (start, end) in poseConnections) {
      if (!visible(start) || !visible(end)) continue;
      canvas.drawLine(at(start), at(end), limbs);
      canvas.drawCircle(at(end), 2.8, limbs);
    }
  }

  @override
  bool shouldRepaint(covariant _Skeleton oldDelegate) =>
      oldDelegate.points != points;
}

class _Counts extends StatelessWidget {
  const _Counts({required this.reps});
  final List<RepResult> reps;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const outcomes = [
        (RepOutcome.passed, 'Passed', Icons.check_circle_outline_rounded, lime),
        (
          RepOutcome.needsCorrection,
          'Needs correction',
          Icons.adjust_rounded,
          amber,
        ),
        (
          RepOutcome.unassessed,
          'Unassessed',
          Icons.visibility_off_outlined,
          soft,
        ),
      ];
      final tileWidth = constraints.maxWidth >= 360
          ? (constraints.maxWidth - 16) / 3
          : constraints.maxWidth;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (outcome, label, icon, color) in outcomes)
            SizedBox(
              width: tileWidth,
              child: Panel(
                padding: const EdgeInsets.all(11),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(label, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${reps.where((rep) => rep.outcome == outcome).length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _Review extends StatelessWidget {
  const _Review({
    required this.record,
    required this.advice,
    required this.coaching,
    required this.onCoach,
    required this.onRetry,
  });
  final SetRecord record;
  final CoachAdvice? advice;
  final bool coaching;
  final VoidCallback onCoach;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionTitle('Set saved'),
      const SizedBox(height: 5),
      Text('${record.exercise.label} · ${record.total} reps'),
      const SizedBox(height: 14),
      _Counts(reps: record.reps),
      const SizedBox(height: 16),
      if (advice case final value?)
        Panel(
          child: Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.source.label,
                  style: const TextStyle(
                    color: lime,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value.cue.message,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(value.observation),
              ],
            ),
          ),
        )
      else ...[
        const Text(
          'The coach uses your rep summary. On supported phones it runs on device. Otherwise it may send the summary to Firebase.',
          style: TextStyle(color: soft),
        ),
        const SizedBox(height: 9),
        RaisedAction(
          label: coaching ? 'Reviewing set…' : 'Coach my next set',
          icon: Icons.auto_awesome_outlined,
          onPressed: coaching ? null : onCoach,
        ),
      ],
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: coaching ? null : onRetry,
        icon: const Icon(Icons.replay_rounded),
        label: const Text('Start another set'),
      ),
    ],
  );
}
