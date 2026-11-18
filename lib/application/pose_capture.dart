import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../domain/camera_framing.dart';
import '../domain/rep_analyzer.dart';
import '../domain/workout.dart';
import 'camera_frame.dart';
import 'camera_stream_watchdog.dart';
import 'framing_guidance.dart';
import 'framing_lens.dart';
import 'pose_frame.dart';
import 'pose_model.dart';
import 'pose_overlay_filter.dart';

final class PoseCapture extends ChangeNotifier {
  final _overlay = PoseOverlayFilter();
  final _watch = Stopwatch()..start();
  final _device = const MethodChannel('formcheck/device');
  Future<void> _pending = Future.value();
  PoseLandmarker? _task;
  StreamSubscription<PoseLandmarkerResult>? _results;
  CameraController? _camera;
  CameraDescription? _preferred;
  CameraDescription? _wider;
  CameraDescription? _fallbackLens;
  FramingZoom? _zoom;
  CameraFraming? _framing;
  bool _triedWider = false;
  int _settleUntil = 0;
  final _watchdog = CameraStreamWatchdog();
  int? _darkSince;
  String? _spokenFraming;
  int _lastSpokenAt = -6000;
  String _openingMessage = 'Starting camera…';
  List<CameraDescription> _available = [];
  RepAnalyzer? _analyzer;
  Exercise? _exercise;
  int _generation = 0;
  int _lastSubmitted = -1000;
  int? _inFlight;
  VisionImage? _submittedImage;
  PoseFrameGeometry? _submittedGeometry;
  PoseFrameGeometry? _frameGeometry;
  PoseFrame? _preview;
  int _measurementStarted = 0;
  int _measured = 0;
  final _displayLatency = <int>[];
  static const _measure = bool.fromEnvironment('FORMCHECK_TIMINGS');
  Timer? _cueTimer;
  bool _disposed = false;
  bool _busy = false;
  String? _error;
  bool _needsSettings = false;
  bool _recording = false;
  bool _voiceEnabled = false;
  final _reps = <RepResult>[];
  TrackingStatus _status = TrackingStatus.reposition;
  Cue? _cue;

  CameraController? get camera =>
      !_busy && _error == null && _camera?.value.isInitialized == true
      ? _camera
      : null;
  bool get busy => _busy;
  String get openingMessage => _openingMessage;
  String? get error => _error;
  bool get needsSettings => _needsSettings;
  bool get canFlip => _available
      .map((c) => c.lensDirection)
      .toSet()
      .containsAll([CameraLensDirection.front, CameraLensDirection.back]);
  bool get recording => _recording;
  bool get voiceEnabled => _voiceEnabled;
  PoseFrame? get previewFrame => _preview;
  List<RepResult> get reps => List.unmodifiable(_reps);
  TrackingStatus get status => _status;
  Cue? get cue => _cue;
  double? get previewAspect => _preview?.geometry.aspect ?? 2 / 3;

  String? get framingMessage {
    if (_zoom?.adjusting == true || _watch.elapsedMilliseconds < _settleUntil) {
      return 'Adjusting the camera view…';
    }
    final framing = _framing;
    final exercise = _exercise;
    if (_preview == null || framing == null || exercise == null) return null;
    if (_status == TrackingStatus.moving || _status == TrackingStatus.ready) {
      return null;
    }
    final since = _darkSince;
    return framingPrompt(
      framing.issue,
      exercise,
      dim: since != null && _preview!.timestampMs - since >= 600,
    );
  }

  Future<void> open(Exercise exercise) {
    _triedWider = false;
    _watchdog.resetBudget();
    return _start(exercise);
  }

  Future<void> _start(
    Exercise exercise, {
    CameraDescription? fallback,
    String message = 'Starting camera…',
  }) {
    final generation = ++_generation;
    if (_exercise != exercise) {
      _recording = false;
      _reps.clear();
      _exercise = exercise;
    }
    _analyzer = RepAnalyzer(exercise);
    _framing = CameraFraming(exercise);
    _fallbackLens = fallback;
    _wider = null;
    _openingMessage = message;
    _busy = true;
    _error = null;
    _needsSettings = false;
    _resetView();
    if (_voiceEnabled) unawaited(_quiet());
    _changed();
    return _serial(() async {
      try {
        await _release();
        if (!_current(generation)) return;
        _available = await availableCameras();
        if (!_current(generation)) return;
        if (_available.isEmpty) {
          _fail(generation, 'No camera was found on this device.');
          return;
        }
        final lens = _available.contains(_preferred)
            ? _preferred!
            : defaultLens(
                _available,
                _preferred?.lensDirection ?? CameraLensDirection.front,
              );
        _preferred = lens;
        final camera = CameraController(
          lens,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
              ? ImageFormatGroup.bgra8888
              : ImageFormatGroup.yuv420,
        );
        _camera = camera;
        await camera.initialize();
        if (!_current(generation)) return;
        final widths = _viewWidths(lens);
        final zoom = await FramingZoom.read(camera);
        final viewWidths = await widths;
        if (!_current(generation)) return;
        _zoom = zoom;
        _wider = widerLens(lens, _available, viewWidths, zoom.minimum);
        final landmarker = await PoseLandmarker.create(
          PoseLandmarkerOptions(
            model: formCheckPoseModel,
            runningMode: RunningMode.liveStream,
            delegate: Delegate.cpu,
            numPoses: 2,
          ),
        );
        _task = landmarker;
        if (!_current(generation)) return;
        _results = landmarker.results.listen(
          (result) => _accept(generation, result),
          onError: (Object _) => _recoverStream(generation),
        );
        _watchdog.start(() => _recoverStream(generation));
        await camera.startImageStream(
          (frame) => _submit(generation, frame, camera, landmarker),
        );
        if (!_current(generation)) return;
        _busy = false;
        _changed();
      } on CameraException catch (error) {
        if (!_current(generation)) return;
        _needsSettings =
            error.code == 'CameraAccessDeniedWithoutPrompt' ||
            error.code == 'CameraAccessDenied' ||
            error.code == 'CameraAccessRestricted';
        if (!_needsSettings && _restoreLens(generation)) return;
        _fail(
          generation,
          _needsSettings
              ? 'Allow camera access in settings to check your form.'
              : 'The camera could not start. Try opening it again.',
        );
      } on Object {
        if (_current(generation)) {
          if (_restoreLens(generation)) return;
          _fail(
            generation,
            'Pose tracking could not start. Try opening the camera again.',
          );
        }
      }
    });
  }

  Future<Map<String, double>> _viewWidths(CameraDescription lens) async {
    final names = _available
        .where((camera) => camera.lensDirection == lens.lensDirection)
        .map((camera) => camera.name)
        .toList();
    if (defaultTargetPlatform != TargetPlatform.android || names.length < 2) {
      return const {};
    }
    try {
      return await _device
              .invokeMapMethod<String, double>('cameraViewWidths', names)
              .timeout(const Duration(seconds: 2)) ??
          const {};
    } on Object {
      return const {};
    }
  }

  bool _restoreLens(int generation) {
    final previous = _fallbackLens;
    final exercise = _exercise;
    if (!_current(generation) || previous == null || exercise == null) {
      return false;
    }
    _preferred = previous;
    unawaited(_start(exercise, message: 'Returning to the previous lens…'));
    return true;
  }

  void _recoverStream(int generation) {
    final exercise = _exercise;
    if (!_current(generation) || exercise == null || _restoreLens(generation)) {
      return;
    }
    if (_watchdog.takeRetry()) {
      unawaited(_start(exercise, message: 'Reconnecting to the camera…'));
    } else {
      _fail(
        generation,
        'The camera stopped sending usable frames. Reopen the camera.',
      );
    }
  }

  Future<void> close() {
    ++_generation;
    _busy = false;
    _resetView();
    unawaited(_quiet());
    _changed();
    return _serial(_release);
  }

  Future<void> flip() async {
    final exercise = _exercise;
    if (!canFlip || exercise == null || _busy) return;
    final next = _preferred?.lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    _preferred = defaultLens(_available, next);
    await open(exercise);
  }

  Future<void> openSettings() async {
    await _device.invokeMethod<void>('settings');
  }

  void setVoiceEnabled(bool value) {
    _voiceEnabled = value;
    _spokenFraming = null;
    if (!value) unawaited(_quiet());
    _changed();
  }

  void begin() {
    if (_status != TrackingStatus.ready || _recording) return;
    _recording = true;
    _reps.clear();
    _cue = null;
    _changed();
  }

  List<RepResult> finish() {
    _recording = false;
    final saved = List<RepResult>.unmodifiable(_reps);
    _reps.clear();
    _resetTracking();
    unawaited(_quiet());
    _changed();
    return saved;
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _serial(Future<void> Function() operation) {
    final next = _pending.then((_) => operation());
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> _release() async {
    final camera = _camera;
    final task = _task;
    final results = _results;
    final zoom = _zoom;
    _zoom = null;
    _camera = null;
    _task = null;
    _results = null;
    try {
      try {
        await zoom?.idle;
        if (camera != null && camera.value.isStreamingImages) {
          await camera.stopImageStream().onError<CameraException>((_, _) {});
        }
      } finally {
        await camera?.dispose();
      }
    } finally {
      try {
        await results?.cancel();
      } finally {
        await task?.dispose();
      }
    }
  }

  void _resetView() {
    _watchdog.stop();
    _settleUntil = 0;
    _framing?.reset();
    _darkSince = null;
    _spokenFraming = null;
    _inFlight = null;
    _frameGeometry = null;
    _submittedImage = null;
    _submittedGeometry = null;
    _displayLatency.clear();
    _measured = 0;
    _measurementStarted = 0;
    _clearPreview();
    _resetTracking();
  }

  void _resetTracking() {
    _overlay.reset();
    _cueTimer?.cancel();
    _status = TrackingStatus.reposition;
    _cue = null;
    _analyzer?.reset();
  }

  void _fail(int generation, String message) {
    if (!_current(generation)) return;
    ++_generation;
    _busy = false;
    _error = message;
    _resetView();
    _changed();
    unawaited(_serial(_release).catchError((Object _) {}));
  }

  Future<void> _submit(
    int generation,
    CameraImage frame,
    CameraController camera,
    PoseLandmarker task,
  ) async {
    if (!_current(generation)) return;
    final now = _watch.elapsedMilliseconds;
    if (_inFlight != null || now - _lastSubmitted < 50) return;
    try {
      final geometry = PoseFrameGeometry.camera(
        width: frame.width,
        height: frame.height,
        sensorOrientation: camera.description.sensorOrientation,
        lens: camera.description.lensDirection,
        orientation:
            camera.value.previewPauseOrientation ??
            camera.value.lockedCaptureOrientation ??
            camera.value.deviceOrientation,
        platform: defaultTargetPlatform,
      );
      if (_frameGeometry != null && _frameGeometry != geometry) {
        _resetTracking();
        _framing?.reset();
        _darkSince = null;
        _clearPreview();
      }
      _frameGeometry = geometry;
      _inFlight = now;
      _lastSubmitted = now;
      final image = await compute(preparePoseImage, (frame, geometry.rotation));
      if (!_current(generation) || _inFlight != now) return;
      _submittedImage = image;
      _submittedGeometry = PoseFrameGeometry(
        width: image.width!,
        height: image.height!,
        rotation: 0,
        mirror: geometry.mirror,
      );
      task.detectAsync(image, timestampMilliseconds: now, rotationDegrees: 0);
    } on Object {
      if (_inFlight == now) _recoverStream(generation);
    }
  }

  Future<void> _accept(int generation, PoseLandmarkerResult result) async {
    final timestamp = result.timestampMilliseconds;
    final source = _submittedImage;
    final geometry = _submittedGeometry;
    if (!_current(generation) ||
        timestamp == null ||
        timestamp != _inFlight ||
        source == null ||
        geometry == null) {
      return;
    }
    try {
      final image = await decodePoseFrame(source);
      if (!_current(generation) || timestamp != _inFlight) {
        image.dispose();
        return;
      }
      _watchdog.receivedFrame();
      _fallbackLens = null;
      _inFlight = null;
      _submittedImage = null;
      _submittedGeometry = null;
      final people = [
        for (final landmarks in result.poseLandmarks)
          [
            for (final landmark in landmarks)
              Joint(
                landmark.x,
                landmark.y,
                math.min(landmark.visibility ?? 0, landmark.presence ?? 1),
              ),
          ],
      ];
      final previous = _preview;
      final sample = PoseSample(timestamp, geometry.aspect, people);
      final settling = _zoom!.adjusting || timestamp < _settleUntil;
      final display = settling
          ? const <List<Joint>>[]
          : _overlay.accept(sample);
      _preview = PoseFrame(image, geometry, display, timestamp);
      _retirePreview(previous);
      if (!settling) {
        _darkSince = people.isEmpty && isDarkCameraFrame(source)
            ? (_darkSince ?? timestamp)
            : null;
        _track(generation, sample);
      }
      if (!_current(generation)) return;
      _changed();
      if (_measure) _measureDisplay(generation, timestamp);
    } on Object {
      _fail(
        generation,
        'The camera frame could not be displayed. Reopen the camera.',
      );
    }
  }

  void _track(int generation, PoseSample sample) {
    final outcome = _analyzer!.accept(sample);
    _status = outcome.status;
    if (_recording && outcome.rep != null && _reps.length < 999) {
      _reps.add(outcome.rep!);
    }
    if (_status == TrackingStatus.reposition && _cue != null) {
      _cueTimer?.cancel();
      _cue = null;
      if (_voiceEnabled) unawaited(_quiet());
    }
    if (_recording && outcome.cue != null) {
      _cue = outcome.cue;
      _cueTimer?.cancel();
      _cueTimer = Timer(const Duration(seconds: 3), () {
        if (!_current(generation)) return;
        _cue = null;
        _changed();
      });
      if (_voiceEnabled) {
        _lastSpokenAt = sample.timestampMs;
        unawaited(_speak(outcome.cue!.message));
      }
    }
    final zoom = _zoom!;
    final framing = _framing!;
    final target = framing.update(
      sample,
      currentZoom: zoom.current,
      minZoom: zoom.minimum,
      maxZoom: zoom.maximum,
      recording: _recording,
      tracking: _status,
    );
    if (target != null) {
      _resetTracking();
      unawaited(_moveZoom(generation, zoom, target));
      return;
    }
    final wider = _wider;
    if (framing.needsWiderLens && !_triedWider && wider != null) {
      _triedWider = true;
      final previous = _preferred;
      _preferred = wider;
      unawaited(
        _start(
          _exercise!,
          fallback: previous,
          message: 'Opening a wider view…',
        ),
      );
      return;
    }
    final prompt = framingMessage;
    if (prompt == null) {
      _spokenFraming = null;
    } else if (_voiceEnabled &&
        _status == TrackingStatus.reposition &&
        prompt != _spokenFraming &&
        sample.timestampMs - _lastSpokenAt >= 6000) {
      _lastSpokenAt = sample.timestampMs;
      _spokenFraming = prompt;
      unawaited(_speak(prompt));
    }
  }

  Future<void> _moveZoom(
    int generation,
    FramingZoom zoom,
    double target,
  ) async {
    await zoom.move(target);
    if (!_current(generation)) return;
    _settleUntil = _watch.elapsedMilliseconds + 350;
    _changed();
  }

  void _clearPreview() {
    final previous = _preview;
    _preview = null;
    _retirePreview(previous);
  }

  void _retirePreview(PoseFrame? frame) {
    if (frame == null) return;
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => frame.image.dispose(),
    );
    SchedulerBinding.instance.scheduleFrame();
  }

  void _measureDisplay(int generation, int timestamp) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_current(generation)) return;
      _measurementStarted = _measurementStarted == 0
          ? timestamp
          : _measurementStarted;
      final now = _watch.elapsedMilliseconds;
      _displayLatency.add(now - timestamp);
      _measured++;
      if (now - _measurementStarted < 5000) return;
      _displayLatency.sort();
      final p95 = _displayLatency[(_displayLatency.length * .95).ceil() - 1];
      final fps = 1000 * _measured / (now - _measurementStarted);
      debugPrint(
        'FormCheck timings: fps=${fps.toStringAsFixed(1)} p95=${p95}ms',
      );
      _displayLatency.clear();
      _measured = 0;
      _measurementStarted = now;
    });
  }

  Future<void> _speak(String message) async {
    try {
      await _device.invokeMethod<void>('speak', message);
    } on Exception {
      // Text feedback stays available when the device has no offline voice.
    }
  }

  Future<void> _quiet() async {
    try {
      await _device.invokeMethod<void>('stopVoice');
    } on Exception {
      // Capture lifecycle is independent of speech.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
