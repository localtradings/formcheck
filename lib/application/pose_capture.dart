import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../domain/rep_analyzer.dart';
import '../domain/workout.dart';
import 'camera_frame.dart';
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
  Timer? _watchdog;
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
      _camera?.value.isInitialized == true ? _camera : null;
  bool get busy => _busy;
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

  Future<void> open(Exercise exercise) {
    final generation = ++_generation;
    if (_exercise != exercise) {
      _recording = false;
      _reps.clear();
      _exercise = exercise;
    }
    _analyzer = RepAnalyzer(exercise);
    _busy = true;
    _error = null;
    _needsSettings = false;
    _resetView();
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
        final lens =
            _preferred ??
            _available.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.front,
              orElse: () => _available.first,
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
          onError: (Object _) =>
              _fail(generation, 'Pose tracking stopped. Reopen the camera.'),
        );
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
        _fail(
          generation,
          _needsSettings
              ? 'Allow camera access in settings to check your form.'
              : 'The camera could not start. Try opening it again.',
        );
      } on Object {
        if (_current(generation)) {
          _fail(
            generation,
            'Pose tracking could not start. Try opening the camera again.',
          );
        }
      }
    });
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
    _preferred = _available.firstWhere(
      (camera) => camera.lensDirection == next,
    );
    await open(exercise);
  }

  Future<void> openSettings() async {
    await _device.invokeMethod<void>('settings');
  }

  void setVoiceEnabled(bool value) {
    _voiceEnabled = value;
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
    _resetView();
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
    _camera = null;
    _task = null;
    _results = null;
    try {
      await camera?.dispose();
    } finally {
      await results?.cancel();
      await task?.dispose();
    }
  }

  void _resetView() {
    _overlay.reset();
    _watchdog?.cancel();
    _cueTimer?.cancel();
    _inFlight = null;
    _frameGeometry = null;
    _submittedImage = null;
    _submittedGeometry = null;
    _displayLatency.clear();
    _measured = 0;
    _measurementStarted = 0;
    _clearPreview();
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
        _analyzer?.reset();
        _overlay.reset();
        _clearPreview();
      }
      _frameGeometry = geometry;
      _inFlight = now;
      _lastSubmitted = now;
      _watchdog?.cancel();
      _watchdog = Timer(const Duration(seconds: 3), () {
        _fail(
          generation,
          'Pose tracking stopped responding. Reopen the camera.',
        );
      });
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
      _fail(
        generation,
        'The camera frame could not be analyzed. Reopen the camera.',
      );
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
      _watchdog?.cancel();
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
      final sample = PoseSample(timestamp, geometry.aspect, [
        for (final person in people)
          [for (final joint in person) geometry.upright(joint)],
      ]);
      final display = _overlay.accept(
        PoseSample(timestamp, geometry.width / geometry.height, people),
      );
      _preview = PoseFrame(image, geometry, display, timestamp);
      final outcome = _analyzer!.accept(sample);
      _status = outcome.status;
      if (_recording && outcome.rep != null && _reps.length < 999) {
        _reps.add(outcome.rep!);
      }
      if (_recording && outcome.cue != null) {
        _cue = outcome.cue;
        _cueTimer?.cancel();
        _cueTimer = Timer(const Duration(seconds: 3), () {
          if (!_current(generation)) return;
          _cue = null;
          _changed();
        });
        if (_voiceEnabled) unawaited(_speak(outcome.cue!));
      }
      _changed();
      _retirePreview(previous);
      if (_measure) _measureDisplay(generation, timestamp);
    } on Object {
      _fail(
        generation,
        'The camera frame could not be displayed. Reopen the camera.',
      );
    }
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

  Future<void> _speak(Cue cue) async {
    try {
      await _device.invokeMethod<void>('speak', cue.message);
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
