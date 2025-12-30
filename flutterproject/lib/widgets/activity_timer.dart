import 'dart:async';
import 'package:flutter/material.dart';

/// Çocuklar için görsel olarak çekici ve işlevsel Aktivite Süre Sayacı bileşeni
/// 
/// Özellikler:
/// - Otomatik başlar
/// - App Lifecycle durumlarını dinler (paused/resumed)
/// - Manuel play/pause kontrolü
/// - Çocuklar için renkli ve büyük fontlar
class ActivityTimer extends StatefulWidget {
  /// Timer'ın başlangıç süresi (opsiyonel, varsayılan: 0)
  final Duration? initialDuration;
  
  /// Timer durumu değiştiğinde çağrılacak callback
  final void Function(Duration duration, bool isRunning)? onTimerUpdate;

  const ActivityTimer({
    super.key,
    this.initialDuration,
    this.onTimerUpdate,
  });

  @override
  State<ActivityTimer> createState() => _ActivityTimerState();
}

class _ActivityTimerState extends State<ActivityTimer>
    with WidgetsBindingObserver {
  Timer? _timer;
  Duration _elapsedDuration = Duration.zero;
  bool _isRunning = true;
  bool _isPaused = false;
  Duration _pausedDuration = Duration.zero;
  DateTime? _lastResumeTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Başlangıç süresi varsa ayarla
    if (widget.initialDuration != null) {
      _elapsedDuration = widget.initialDuration!;
    }
    
    // Timer'ı otomatik başlat
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Uygulama arka plana gittiğinde timer'ı durdur
        if (_isRunning && !_isPaused) {
          _pauseTimer();
        }
        break;
      case AppLifecycleState.resumed:
        // Uygulama ön plana geldiğinde timer'ı devam ettir
        if (!_isRunning && !_isPaused) {
          _resumeTimer();
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _startTimer() {
    _isRunning = true;
    _isPaused = false;
    _lastResumeTime = DateTime.now();
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_isRunning && !_isPaused) {
        setState(() {
          // Son resume zamanından itibaren geçen süreyi hesapla
          if (_lastResumeTime != null) {
            final now = DateTime.now();
            final sessionDuration = now.difference(_lastResumeTime!);
            _elapsedDuration = _pausedDuration + sessionDuration;
          }
        });
        
        // Callback'i çağır
        widget.onTimerUpdate?.call(_elapsedDuration, _isRunning);
      }
    });
  }

  void _pauseTimer() {
    if (!_isRunning || _isPaused) return;
    
    setState(() {
      _isPaused = true;
      
      // Şu ana kadar geçen süreyi kaydet
      if (_lastResumeTime != null) {
        final now = DateTime.now();
        final sessionDuration = now.difference(_lastResumeTime!);
        _pausedDuration = _pausedDuration + sessionDuration;
      }
    });
    
    widget.onTimerUpdate?.call(_elapsedDuration, false);
  }

  void _resumeTimer() {
    if (_isRunning && !_isPaused) return;
    
    setState(() {
      _isPaused = false;
      _lastResumeTime = DateTime.now();
    });
    
    widget.onTimerUpdate?.call(_elapsedDuration, true);
  }

  void _toggleTimer() {
    if (_isPaused) {
      _resumeTimer();
    } else {
      _pauseTimer();
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    
    // Saat varsa HH:MM:SS, yoksa MM:SS formatında göster
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isPaused
              ? [
                  // Duraklatıldığında daha soluk renkler
                  const Color(0xFF95A5A6),
                  const Color(0xFF7F8C8D),
                ]
              : [
                  // Çalışırken canlı ve çekici renkler (çocuklar için)
                  const Color(0xFF4ECDC4),
                  const Color(0xFF44A08D),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_isPaused ? Colors.grey : const Color(0xFF4ECDC4))
                .withValues(alpha: 0.5),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Süre Gösterimi (Büyük ve Okunaklı - Çocuklar için)
          Text(
            _formatDuration(_elapsedDuration),
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFeatures: [
                const FontFeature.tabularFigures(),
              ],
              letterSpacing: 2,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          // Play/Pause Butonu (Büyük ve Çekici)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleTimer,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _isPaused
                      ? const Color(0xFF2ECC71) // Yeşil (Devam)
                      : const Color(0xFFE74C3C), // Kırmızı (Durdur)
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isPaused
                              ? const Color(0xFF2ECC71)
                              : const Color(0xFFE74C3C))
                          .withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  _isPaused ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

