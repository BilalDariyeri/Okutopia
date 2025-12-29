import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/mini_question_model.dart';
import '../models/activity_model.dart';
import '../config/api_config.dart';
import '../utils/app_logger.dart';

class LetterCDrawingScreen extends StatefulWidget {
  final Activity activity;
  final List<MiniQuestion> questions;
  final int currentQuestionIndex;

  const LetterCDrawingScreen({
    super.key,
    required this.activity,
    required this.questions,
    this.currentQuestionIndex = 0,
  });

  @override
  State<LetterCDrawingScreen> createState() => _LetterCDrawingScreenState();
}

class _LetterCDrawingScreenState extends State<LetterCDrawingScreen>
    with TickerProviderStateMixin {
  int _currentStep = 1;
  bool _isDrawing = false;
  List<Offset> _currentPathPoints = [];
  bool _showSuccess = false;
  bool _showStartOverlay = true;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _playerCompleteSubscription;

  late AnimationController _arrowAnimationController;
  final List<Offset> _arrowPositions = [];
  final List<double> _arrowRotations = [];
  
  // Gezegen animasyonları için controller'lar
  late AnimationController _planet1Controller;
  late AnimationController _planet2Controller;
  late AnimationController _planet3Controller;
  late AnimationController _planet4Controller;
  
  // Canvas için GlobalKey
  final GlobalKey _canvasKey = GlobalKey();

  // C harfi segmentleri - "C harfi nasıl yazılır" ekranıyla aynı değerler
  final Map<String, Map<String, dynamic>> _cSegments = {
    'arc': {
      'center': const Offset(160, 150),  // LetterCWritingScreen ile aynı
      'radiusX': 95.0,                    // LetterCWritingScreen ile aynı
      'radiusY': 93.0,                    // LetterCWritingScreen ile aynı
      'startAngle': 320 * math.pi / 180,  // 320 derece (LetterCWritingScreen ile aynı)
      'endAngle': 45 * math.pi / 180,     // 45 derece (LetterCWritingScreen ile aynı)
      'clockwise': true,                  // Saat yönünde
    },
    // Eski format için de destek (geriye dönük uyumluluk)
    'mainCurve': {
      'center': const Offset(160, 150),
      'radiusX': 95.0,
      'radiusY': 93.0,
      'startAngle': 320 * math.pi / 180,
      'endAngle': 45 * math.pi / 180,
      'clockwise': true,
    },
  };

  @override
  void initState() {
    super.initState();
    _arrowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    // Gezegen animasyonları için controller'lar
    _planet1Controller = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
    
    _planet2Controller = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat();
    
    _planet3Controller = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
    
    _planet4Controller = AnimationController(
      duration: const Duration(seconds: 16),
      vsync: this,
    )..repeat();
    
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      // Ses tamamlandığında
    });

    _updateArrowPositions();
  }

  @override
  void dispose() {
    _arrowAnimationController.dispose();
    _planet1Controller.dispose();
    _planet2Controller.dispose();
    _planet3Controller.dispose();
    _planet4Controller.dispose();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _updateArrowPositions() {
    _arrowPositions.clear();
    _arrowRotations.clear();

    if (_currentStep == 1) {
      // C harfi yayı için ok - "C harfi nasıl yazılır" ekranıyla aynı pozisyon
      _arrowPositions.add(const Offset(244, 80));
      _arrowRotations.add(225.0);
    }
  }


  String _getFileUrl(String? fileId) {
    if (fileId == null) return '';
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    return '$baseUrl/api/files/$fileId';
  }

  Future<void> _playAudio(String? fileId, {double volume = 1.0}) async {
    if (fileId == null) return;
    try {
      final url = _getFileUrl(fileId);
      await _audioPlayer.setVolume(volume);
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      AppLogger.error('Ses çalınamadı', e);
    }
  }

  void _startDrawing() {
    setState(() {
      _showStartOverlay = false;
    });
    
    // Başlangıç sesini çal
    final question = widget.questions[widget.currentQuestionIndex];
    final audioFileId = question.data?['audioFileId'];
    if (audioFileId != null) {
      _playAudio(audioFileId);
    }
  }

  void _resetCanvas() {
    setState(() {
      _currentStep = 1;
      _currentPathPoints = [];
      _showSuccess = false;
      _updateArrowPositions();
    });
  }

  void _startDrawingGesture(Offset position) {
    setState(() {
      _isDrawing = true;
      _currentPathPoints = [position];
    });
  }

  void _continueDrawingGesture(Offset position) {
    if (!_isDrawing) return;
    
    setState(() {
      _currentPathPoints.add(position);
    });
  }

  void _endDrawingGesture() {
    if (!_isDrawing) return;
    
    setState(() {
      _isDrawing = false;
    });
    
    // Çizim tamamlanma oranını kontrol et
    if (_currentPathPoints.length > 3) {
      final accuracy = _checkSegmentCompletion();
      AppLogger.debug('Doğruluk: $accuracy, Adım: $_currentStep');
      
      if (accuracy > 0.05) {
        // Çizimi düzgün C harfi yayına dönüştür (HTML'deki drawCleanLetter gibi)
        // "C harfi nasıl yazılır" ekranındaki gibi görünmesi için
        _drawCleanLetter();
        
        // Başarı mesajını göster
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _showSuccessMessage();
          }
        });
      } else {
        // Yeterli değilse temizle
        setState(() {
          _currentPathPoints = [];
        });
      }
    } else {
      setState(() {
        _currentPathPoints = [];
      });
    }
  }

  double _checkSegmentCompletion() {
    if (_currentStep == 1) {
      // C harfi yayı için kontrol - "C harfi nasıl yazılır" ekranıyla aynı mantık
      final seg = _cSegments['arc'] ?? _cSegments['mainCurve']!;
      final center = seg['center'] as Offset;
      final radiusX = seg['radiusX'] as double;
      final radiusY = seg['radiusY'] as double;
      final startAngle = seg['startAngle'] as double;  // 320° (radyan)
      final endAngle = seg['endAngle'] as double;      // 45° (radyan)
      
      int correctPoints = 0;
      
      for (final point in _currentPathPoints) {
        // Noktanın yaya olan mesafesini hesapla
        final pointAngle = math.atan2(point.dy - center.dy, point.dx - center.dx);
        
        // Açının başlangıç ve bitiş arasında olup olmadığını kontrol et
        // 320°'den 45°'ye saat yönünde çizim (320° > 45° olduğu için özel kontrol gerekli)
        bool angleInRange = false;
        
        // Normalize açıları 0-2π aralığına getir
        double normalizedPointAngle = pointAngle;
        if (normalizedPointAngle < 0) normalizedPointAngle += 2 * math.pi;
        
        double normalizedStartAngle = startAngle;
        if (normalizedStartAngle < 0) normalizedStartAngle += 2 * math.pi;
        
        double normalizedEndAngle = endAngle;
        if (normalizedEndAngle < 0) normalizedEndAngle += 2 * math.pi;
        
        // 320°'den 45°'ye saat yönünde çizim (320° > 45° olduğu için)
        if (normalizedStartAngle > normalizedEndAngle) {
          // 320°'den 360°'ye veya 0°'den 45°'ye
          angleInRange = normalizedPointAngle >= normalizedStartAngle || 
                        normalizedPointAngle <= normalizedEndAngle;
        } else {
          angleInRange = normalizedPointAngle >= normalizedStartAngle && 
                        normalizedPointAngle <= normalizedEndAngle;
        }
        
        if (angleInRange) {
          // Yay üzerindeki en yakın noktayı hesapla (elips yayı)
          final expectedX = center.dx + radiusX * math.cos(pointAngle);
          final expectedY = center.dy + radiusY * math.sin(pointAngle);
          
          final distance = math.sqrt(
            math.pow(point.dx - expectedX, 2) + 
            math.pow(point.dy - expectedY, 2)
          );
          
          if (distance < 120) { // 120px tolerans
            correctPoints++;
          }
        }
      }
      
      return correctPoints / math.max(_currentPathPoints.length, 1);
    }
    
    return 0;
  }

  void _drawCleanLetter() {
    setState(() {
      // Çizimi temizle ve düzgün C harfi yayını göster
      // "C harfi nasıl yazılır" ekranındaki gibi görünmesi için
      _currentPathPoints = []; // Ham çizimi temizle
      _showSuccess = true; // Düzgün C harfi yayını göster (LetterCDrawingPainter'da showCleanLetter: _showSuccess)
    });
  }

  void _showSuccessMessage() {
    setState(() {
      _showSuccess = true;
    });

    // Başarı sesini çal (eğer varsa)
    final question = widget.questions[widget.currentQuestionIndex];
    final successAudioId = question.data?['successAudioId'];
    if (successAudioId != null) {
      _playAudio(successAudioId, volume: 1.0);
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSuccess = false;
        });
      }
    });
  }

  Widget _buildBackgroundDecorations() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Stack(
      children: [
        // Yıldızlar (statik)
        ...List.generate(30, (index) {
          return Positioned(
            key: ValueKey('star_$index'),
            left: (index * 37.7) % screenWidth,
            top: (index * 23.3) % screenHeight,
            child: Container(
              width: 2 + (index % 3 == 0 ? 1 : 0),
              height: 2 + (index % 3 == 0 ? 1 : 0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                boxShadow: index % 5 == 0 ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 2,
                    spreadRadius: 0.5,
                  ),
                ] : null,
              ),
            ),
          );
        }),
        // Gezegenler
        AnimatedBuilder(
          key: const ValueKey('planet1'),
          animation: _planet1Controller,
          builder: (context, child) {
            final time = _planet1Controller.value * 2 * math.pi;
            return Positioned(
              left: -50.0 + 25.0 * math.sin(time),
              top: 50.0 + 35.0 * math.cos(time),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.deepOrange.withValues(alpha: 0.5),
                      Colors.orange.withValues(alpha: 0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          key: const ValueKey('planet2'),
          animation: _planet2Controller,
          builder: (context, child) {
            final time = _planet2Controller.value * 2 * math.pi;
            return Positioned(
              right: 30.0 + 30.0 * math.sin(time * 0.8),
              top: 100.0 + 45.0 * math.cos(time * 0.8),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.5),
                      Colors.yellow.withValues(alpha: 0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          key: const ValueKey('planet3'),
          animation: _planet3Controller,
          builder: (context, child) {
            final time = _planet3Controller.value * 2 * math.pi;
            return Positioned(
              left: 50.0 + 20.0 * math.sin(time * 0.7),
              bottom: 150.0 + 40.0 * math.cos(time * 0.7),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.blue.withValues(alpha: 0.5),
                      Colors.lightBlue.withValues(alpha: 0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          key: const ValueKey('planet4'),
          animation: _planet4Controller,
          builder: (context, child) {
            final time = _planet4Controller.value * 2 * math.pi;
            return Positioned(
              right: 50.0 + 25.0 * math.sin(time * 0.9),
              bottom: 100.0 + 35.0 * math.cos(time * 0.9),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.red.withValues(alpha: 0.5),
                      Colors.pink.withValues(alpha: 0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[widget.currentQuestionIndex];
    final imageFileId = question.mediaFileId ?? question.data?['imageFileId'];
    final currentIndex = widget.currentQuestionIndex;
    final totalQuestions = widget.questions.length;
    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex < totalQuestions - 1;

    return Scaffold(
      body: Stack(
        children: [
          // Arka plan (HTML'deki gibi açık mavi - #f0f8ff)
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF0F8FF), // #f0f8ff
            ),
            child: _buildBackgroundDecorations(),
          ),
          // Ana içerik
          SafeArea(
            child: Stack(
              children: [
                // Üst Geri butonu
                Positioned(
                  top: 16,
                  left: 16,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text(
                      'Geri',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006D77),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                // Ana içerik (ortada)
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 560),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Başlık
                        const Text(
                          'C harfi serbest çizim',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF006D77),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Kart
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Canvas Container
                              SizedBox(
                                width: 320,
                                height: 360,
                                child: Stack(
                                  children: [
                                    // Arka plan görseli
                                    Container(
                                      width: 320,
                                      height: 320,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: imageFileId != null
                                            ? CachedNetworkImage(
                                                imageUrl: _getFileUrl(imageFileId),
                                                fit: BoxFit.contain,
                                                placeholder: (context, url) =>
                                                    const SizedBox(),
                                                errorWidget: (context, url, error) =>
                                                    const SizedBox(),
                                              )
                                            : const SizedBox(),
                                      ),
                                    ),
                                    
                                    // Canvas (çizimler üstte)
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanStart: (details) {
                                        if (_showSuccess) return; // Başarılı çizimden sonra çizim yapılamaz
                                        final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                        if (box != null) {
                                          final localPosition = box.globalToLocal(details.globalPosition);
                                          if (localPosition.dx >= 0 && localPosition.dx <= 320 &&
                                              localPosition.dy >= 0 && localPosition.dy <= 320) {
                                            _startDrawingGesture(localPosition);
                                          }
                                        }
                                      },
                                      onPanUpdate: (details) {
                                        if (_isDrawing && !_showSuccess) {
                                          final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                          if (box != null) {
                                            final localPosition = box.globalToLocal(details.globalPosition);
                                            if (localPosition.dx >= 0 && localPosition.dx <= 320 &&
                                                localPosition.dy >= 0 && localPosition.dy <= 320) {
                                              _continueDrawingGesture(localPosition);
                                            }
                                          }
                                        }
                                      },
                                      onPanEnd: (details) {
                                        if (!_showSuccess) {
                                          _endDrawingGesture();
                                        }
                                      },
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.precise,
                                        child: CustomPaint(
                                          key: _canvasKey,
                                          size: const Size(320, 320),
                                          painter: LetterCDrawingPainter(
                                            currentStep: _currentStep,
                                            currentPathPoints: _currentPathPoints,
                                            cSegments: _cSegments,
                                            showCleanLetter: _showSuccess, // Başarılı çizimde düzgün C harfi göster
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Oklar
                                    ...List.generate(_arrowPositions.length, (index) {
                                      if (index < _arrowPositions.length && _currentStep == 1 && !_showSuccess) {
                                        return Positioned(
                                          left: _arrowPositions[index].dx,
                                          top: _arrowPositions[index].dy,
                                          child: Transform.rotate(
                                            angle: _arrowRotations[index] * math.pi / 180,
                                            child: Transform.translate(
                                              offset: const Offset(-10, -10),
                                              child: CustomPaint(
                                                size: const Size(56, 56),
                                                painter: ArrowPainter(),
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    }),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Talimat metni
                              const SizedBox(
                                height: 24,
                                child: Text(
                                  'Okları takip ederek C harfini çiz',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF006D77),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Reset butonu (süpürge ikonu)
                              ElevatedButton(
                                onPressed: _resetCanvas,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF006D77),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  minimumSize: const Size(44, 44),
                                ),
                                child: const Icon(
                                  Icons.cleaning_services,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              
                              // Başarı mesajı
                              if (_showSuccess)
                                Container(
                                  margin: const EdgeInsets.only(top: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    '🎊 TEBRİKLER 🎊',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Alt butonlar
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: ElevatedButton.icon(
                    onPressed: hasPrevious
                        ? () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => LetterCDrawingScreen(
                                  activity: widget.activity,
                                  questions: widget.questions,
                                  currentQuestionIndex: currentIndex - 1,
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text(
                      'Geri',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: ElevatedButton.icon(
                    onPressed: hasNext
                        ? () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => LetterCDrawingScreen(
                                  activity: widget.activity,
                                  questions: widget.questions,
                                  currentQuestionIndex: currentIndex + 1,
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    label: const Text(
                      'İleri',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                // Başlatma overlay'i
                if (_showStartOverlay)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _startDrawing,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.7),
                        child: const Center(
                          child: Text(
                            'C harfi çizimini başlatmak için tıklayın',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Canvas painter for drawing C letter
class LetterCDrawingPainter extends CustomPainter {
  final int currentStep;
  final List<Offset> currentPathPoints;
  final Map<String, Map<String, dynamic>> cSegments;
  final bool showCleanLetter;

  LetterCDrawingPainter({
    required this.currentStep,
    required this.currentPathPoints,
    required this.cSegments,
    required this.showCleanLetter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1D4ED8) // #1d4ed8
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Eğer başarı mesajı gösteriliyorsa, düzgün C harfi yayını çiz
    // "C harfi nasıl yazılır" ekranındaki gibi
    if (showCleanLetter && currentStep == 1) {
      final seg = cSegments['arc'] ?? cSegments['mainCurve']!;
      final center = seg['center'] as Offset;
      final radiusX = seg['radiusX'] as double;
      final radiusY = seg['radiusY'] as double;
      final startAngle = seg['startAngle'] as double;  // 320° (radyan)
      final endAngle = seg['endAngle'] as double;        // 45° (radyan)
      
      // Yay çiz (LetterCWritingScreen ile aynı mantık)
      final rect = Rect.fromCenter(
        center: center,
        width: radiusX * 2,
        height: radiusY * 2,
      );
      
      // C harfi yayını çiz - "C harfi nasıl yazılır" ekranıyla TAM AYNI mantık
      // LetterCWritingScreen'de: currentEndAngle - startAngle kullanılıyor
      // progress = 1.0 olduğunda: currentEndAngle = endAngle
      // Yani: currentEndAngle - startAngle = endAngle - startAngle
      // Bu negatif olabilir (-275°), Flutter bunu saat yönünün tersine çizer
      // Ama bu doğru çünkü 320°'den 45°'ye saat yönünde çizmek için saat yönünün tersine çizmek gerekiyor
      double sweepAngle = endAngle - startAngle;
      // LetterCWritingScreen ile aynı mantık - direkt kullan, değiştirme
      
      // C harfi yayını çiz (LetterCWritingScreen ile aynı)
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle, // Negatif olabilir, Flutter bunu saat yönünün tersine çizer (doğru)
        false, // useCenter = false (yay şeklinde)
        paint,
      );
    } else {
      // Kullanıcının şu anda çizdiği ham çizgiyi göster
      if (currentPathPoints.length > 1) {
        final path = Path();
        path.moveTo(currentPathPoints[0].dx, currentPathPoints[0].dy);
        for (int i = 1; i < currentPathPoints.length; i++) {
          path.lineTo(currentPathPoints[i].dx, currentPathPoints[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(LetterCDrawingPainter oldDelegate) {
    return oldDelegate.currentStep != currentStep ||
        oldDelegate.currentPathPoints.length != currentPathPoints.length ||
        oldDelegate.showCleanLetter != showCleanLetter;
  }
}

// Arrow painter
class ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Ok çizgisi
    canvas.drawLine(
      const Offset(8, 24),
      const Offset(32, 24),
      paint,
    );

    // Ok ucu
    final path = Path();
    path.moveTo(24, 16);
    path.lineTo(32, 24);
    path.lineTo(24, 32);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ArrowPainter oldDelegate) => false;
}
