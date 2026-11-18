import 'dart:async';

final class CameraStreamWatchdog {
  Timer? _timer;
  void Function()? _onStall;
  int _retries = 0;

  void resetBudget() => _retries = 0;

  void start(void Function() onStall) {
    stop();
    _onStall = onStall;
    _timer = Timer(const Duration(seconds: 8), onStall);
  }

  void receivedFrame() {
    final onStall = _onStall;
    if (onStall == null) return;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), onStall);
  }

  bool takeRetry() {
    if (_retries >= 2) return false;
    _retries++;
    return true;
  }

  void stop() {
    _timer?.cancel();
    _onStall = null;
  }
}
