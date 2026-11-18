import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/pose_capture.dart';
import '../application/providers.dart';
import '../domain/rep_analyzer.dart';
import '../domain/workout.dart';
import 'camera_placement_guide.dart';
import 'pose_preview.dart';
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
  bool _guideExpanded = false;
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
      _guideExpanded = false;
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
    // A system permission prompt temporarily takes focus from the visible app.
    if (state == AppLifecycleState.inactive) return;
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
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
      final reps = _capture.reps;
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
                  MediaQuery.textScalerOf(context).scale(35) > 48
                      ? 'Form\u200BCheck'
                      : 'FormCheck',
                  semanticsLabel: 'FormCheck',
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
            if (_capture.camera != null || _capture.recording)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _Counts(reps: reps),
              ),
            if (_capture.recording && reps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: RepCheckDetails(exercise: widget.exercise, reps: reps),
              ),
            if (_capture.camera != null)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _guideExpanded = !_guideExpanded),
                    icon: Icon(
                      _guideExpanded
                          ? Icons.expand_less
                          : Icons.explore_outlined,
                    ),
                    label: Text(
                      _guideExpanded
                          ? 'Hide camera guide'
                          : 'Show camera guide',
                    ),
                  ),
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
            if (_guideExpanded && _capture.camera != null)
              Panel(
                padding: EdgeInsets.zero,
                child: CameraPlacementGuide(exercise: widget.exercise),
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
      TrackingStatus.reposition =>
        exercise == Exercise.squat
            ? 'Turn sideways so one hip, knee and ankle are clearly visible.'
            : 'Turn sideways so one shoulder, elbow and wrist are clearly visible.',
      TrackingStatus.getReady =>
        exercise == Exercise.squat
            ? 'Stand tall to get ready'
            : 'Hold the top of a push-up',
      TrackingStatus.ready =>
        capture.recording ? 'Ready for the next rep' : 'Ready to start',
      TrackingStatus.moving => 'Tracking this rep',
    };
    final aspect = capture.previewAspect;
    final angle = capture.jointAngleDegrees;
    final side = capture.measuredSide;
    final measuredJoint = angle != null && angle.isFinite && side != null
        ? (exercise: exercise, side: side)
        : null;
    final cue = capture.cue;
    final message =
        capture.error ??
        (capture.busy
            ? capture.openingMessage
            : capture.framingMessage ?? cue?.message ?? status);
    return Semantics(
      container: true,
      explicitChildNodes: true,
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
                  final maxHeight = math.min(
                    420.0,
                    MediaQuery.sizeOf(context).height * .48,
                  );
                  final height = math.min(
                    constraints.maxWidth / aspect,
                    maxHeight,
                  );
                  return SizedBox(
                    height: height,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: aspect,
                        child: switch (capture.previewFrame) {
                          final frame? => PosePreview(
                            frame: frame,
                            measuredJoint: measuredJoint,
                          ),
                          null => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        },
                      ),
                    ),
                  );
                },
              )
            else
              CameraPlacementGuide(exercise: exercise),
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
                    message,
                    style: TextStyle(
                      color: cue != null ? amber : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (camera != null)
              LiveCameraAngles(
                exercise: exercise,
                placementLabel: message == capture.placementLabel
                    ? ''
                    : capture.placementLabel,
                sideAngle: capture.estimatedSideAngle,
                lensTilt: capture.phoneTiltDegrees,
                jointAngle: angle,
              ),
          ],
        ),
      ),
    );
  }
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
      if (record.reps.isNotEmpty) ...[
        const SizedBox(height: 8),
        RepCheckDetails(
          key: ValueKey(record.id),
          exercise: record.exercise,
          reps: record.reps,
          review: true,
          showTarget:
              record.profile == FormProfile.forExercise(record.exercise).id,
        ),
      ],
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

class RepCheckDetails extends StatefulWidget {
  const RepCheckDetails({
    super.key,
    required this.exercise,
    required this.reps,
    this.review = false,
    this.showTarget = true,
  });

  final Exercise exercise;
  final List<RepResult> reps;
  final bool review;
  final bool showTarget;

  @override
  State<RepCheckDetails> createState() => _RepCheckDetailsState();
}

class _RepCheckDetailsState extends State<RepCheckDetails> {
  int _fromLast = 0;

  @override
  Widget build(BuildContext context) {
    final reps = widget.reps;
    if (reps.isEmpty) return const SizedBox.shrink();
    final index = (reps.length - 1 - _fromLast).clamp(0, reps.length - 1);
    final result = reps[index];
    final squat = widget.exercise == Exercise.squat;
    final (label, icon, color) = switch (result.outcome) {
      RepOutcome.passed => (
        'Passed form checks',
        Icons.check_circle_outline_rounded,
        lime,
      ),
      RepOutcome.needsCorrection => (
        'Needs correction',
        Icons.adjust_rounded,
        amber,
      ),
      RepOutcome.unassessed => (
        'Couldn’t assess',
        Icons.visibility_off_outlined,
        soft,
      ),
    };
    final explanation = switch ((result.outcome, result.cue)) {
      (RepOutcome.passed, _) =>
        squat ? 'You reached the squat depth check and returned to standing.' : 'You reached the elbow depth check and kept your shoulders, hips and ankles in line.',
      (RepOutcome.needsCorrection, Cue.squatDepth) =>
        'Your knee stayed more open than the squat depth target.',
      (RepOutcome.needsCorrection, Cue.pushUpDepth) =>
        'Your elbow stayed more open than the push-up depth target.',
      (RepOutcome.needsCorrection, Cue.bodyLine) =>
        'Your hips moved out of line with your shoulders and ankles.',
      (RepOutcome.needsCorrection, _) =>
        result.cue?.message ?? 'This rep missed a form check.',
      (RepOutcome.unassessed, Cue.depthUnclear) =>
        'The camera couldn’t confirm the depth at the bottom of this rep.',
      (RepOutcome.unassessed, Cue.alignmentUnclear) => 'The camera couldn’t confirm your shoulder-to-ankle line through the rep.',
      (RepOutcome.unassessed, _) =>
        'The camera needed a clearer view to grade this rep.',
    };
    final joint = squat ? 'knee' : 'elbow';
    final target = FormProfile.forExercise(widget.exercise).depth.round();
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: !widget.review,
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Rep ${index + 1} · $label',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(explanation),
          if (result.bottomAngleDegrees case final angle?) ...[
            const SizedBox(height: 4),
            Text(
              'Bottom $joint angle ≈$angle°${widget.showTarget ? ' · depth target $target°' : ''}',
              style: const TextStyle(color: soft),
            ),
          ],
          if (widget.review && reps.length > 1)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous rep',
                  onPressed: index == 0
                      ? null
                      : () => setState(() => _fromLast++),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${index + 1} of ${reps.length}'),
                IconButton(
                  tooltip: 'Next rep',
                  onPressed: index == reps.length - 1
                      ? null
                      : () => setState(() => _fromLast--),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
