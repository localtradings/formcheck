import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../domain/rep_analyzer.dart';
import '../domain/workout.dart';
import 'camera_frame.dart';

const poseConnections = <(int, int)>[
  (11, 12),
  (11, 13),
  (13, 15),
  (12, 14),
  (14, 16),
  (11, 23),
  (12, 24),
  (23, 24),
  (23, 25),
  (25, 27),
  (24, 26),
  (26, 28),
  (27, 31),
  (28, 32),
];

final class PoseCapture extends ChangeNotifier {
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
  int _rotation = 0;
  (int, int, int)? _frameGeometry;
  int _measurementStarted = 0;
  int _measured = 0;
  final _displayLatency = <int>[];
  static const _measure = bool.fromEnvironment('FORMCHECK_TIMINGS');
  double _aspect = 1;
  bool _mirror = false;
  Timer? _watchdog;
  Timer? _cueTimer;
  bool _disposed = false;
  bool _busy = false;
  String? _error;
  bool _needsSettings = false;
  bool _recording = false;
  bool _voiceEnabled = false;
  List<Offset> _points = const [];
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
  List<Offset> get points => _points;
  List<RepResult> get reps => List.unmodifiable(_reps);
  TrackingStatus get status => _status;
  Cue? get cue => _cue;
  double? get previewAspect {
    final value = camera?.value;
    if (value == null) return null;
    return _isPortrait(value.deviceOrientation)
        ? 1 / value.aspectRatio
        : value.aspectRatio;
  }

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
            model: VisionModels.poseLandmarker,
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
    _watchdog?.cancel();
    _cueTimer?.cancel();
    _inFlight = null;
    _frameGeometry = null;
    _displayLatency.clear();
    _measured = 0;
    _measurementStarted = 0;
    _points = const [];
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

  void _submit(
    int generation,
    CameraImage frame,
    CameraController camera,
    PoseLandmarker task,
  ) {
    if (!_current(generation)) return;
    final now = _watch.elapsedMilliseconds;
    if (_inFlight != null || now - _lastSubmitted < 50) return;
    try {
      final orientation = camera.value.deviceOrientation;
      final front =
          camera.description.lensDirection == CameraLensDirection.front;
      _rotation = _uprightRotation(
        frame,
        camera.description.sensorOrientation,
        front,
        orientation,
      );
      final geometry = (frame.width, frame.height, _rotation);
      if (_frameGeometry != null && _frameGeometry != geometry) {
        _analyzer?.reset();
        _points = const [];
      }
      _frameGeometry = geometry;
      final swapped = _rotation == 90 || _rotation == 270;
      _aspect = swapped
          ? frame.height / frame.width
          : frame.width / frame.height;
      // iOS flips the delivered front-camera frame and preview together.
      _mirror = defaultTargetPlatform == TargetPlatform.android && front;
      _inFlight = now;
      _lastSubmitted = now;
      _watchdog?.cancel();
      _watchdog = Timer(const Duration(seconds: 3), () {
        _fail(
          generation,
          'Pose tracking stopped responding. Reopen the camera.',
        );
      });
      task.detectAsync(
        visionImageFromCamera(frame),
        timestampMilliseconds: now,
        rotationDegrees: _rotation,
      );
    } on Object {
      _fail(
        generation,
        'The camera frame could not be analyzed. Reopen the camera.',
      );
    }
  }

  void _accept(int generation, PoseLandmarkerResult result) {
    final timestamp = result.timestampMilliseconds;
    if (!_current(generation) || timestamp == null || timestamp != _inFlight) {
      return;
    }
    _watchdog?.cancel();
    _inFlight = null;
    final people = [
      for (final landmarks in result.poseLandmarks)
        [
          for (final landmark in landmarks)
            _upright(landmark.x, landmark.y, landmark.visibility ?? 0),
        ],
    ];
    _points = people.length == 1
        ? List.unmodifiable(
            people.single.map(
              (p) => p.visible
                  ? Offset(_mirror ? 1 - p.x : p.x, p.y)
                  : const Offset(-1, -1),
            ),
          )
        : const [];
    final outcome = _analyzer!.accept(PoseSample(timestamp, _aspect, people));
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
    if (_measure) _measureDisplay(generation, timestamp);
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

  Joint _upright(double x, double y, double visibility) => switch (_rotation) {
    90 => Joint(1 - y, x, visibility),
    180 => Joint(1 - x, 1 - y, visibility),
    270 => Joint(y, 1 - x, visibility),
    _ => Joint(x, y, visibility),
  };

  static bool _isPortrait(DeviceOrientation orientation) =>
      orientation == DeviceOrientation.portraitUp ||
      orientation == DeviceOrientation.portraitDown;

  // Adapted from the official Flutter MediaPipe sample camera_geometry.dart.
  static int _uprightRotation(
    CameraImage frame,
    int sensor,
    bool front,
    DeviceOrientation orientation,
  ) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _isPortrait(orientation) &&
              frame.width > frame.height &&
              (sensor == 90 || sensor == 270)
          ? sensor
          : 0;
    }
    final rotation = switch (orientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    return (sensor + (front ? rotation : -rotation) + 360) % 360;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
