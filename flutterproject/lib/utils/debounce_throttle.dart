import 'dart:async';

/// Debounce utility - Son çağrıdan belirli bir süre sonra fonksiyonu çalıştırır
/// Kullanım: Butona çok hızlı basılmasını önler
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void call(void Function() callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Throttle utility - Belirli bir süre içinde sadece bir kez fonksiyonu çalıştırır
/// Kullanım: API çağrılarını sınırlar
class Throttler {
  final Duration delay;
  DateTime? _lastCall;
  Timer? _pendingTimer;
  void Function()? _pendingCallback;

  Throttler({this.delay = const Duration(seconds: 1)});

  void call(void Function() callback) {
    final now = DateTime.now();
    
    if (_lastCall == null || now.difference(_lastCall!) >= delay) {
      // İlk çağrı veya yeterli süre geçti, direkt çalıştır
      _lastCall = now;
      callback();
    } else {
      // Çok yakın zamanda çağrıldı, beklet
      _pendingCallback = callback;
      _pendingTimer?.cancel();
      final remainingTime = delay - now.difference(_lastCall!);
      _pendingTimer = Timer(remainingTime, () {
        if (_pendingCallback != null) {
          _lastCall = DateTime.now();
          _pendingCallback!();
          _pendingCallback = null;
        }
      });
    }
  }

  void dispose() {
    _pendingTimer?.cancel();
    _pendingCallback = null;
  }
}

