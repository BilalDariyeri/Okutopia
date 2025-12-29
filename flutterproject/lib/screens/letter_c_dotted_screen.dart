import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/mini_question_model.dart';
import '../models/activity_model.dart';
import '../config/api_config.dart';
import '../utils/app_logger.dart';

class LetterCDottedScreen extends StatefulWidget {
  final Activity activity;
  final List<MiniQuestion> questions;
  final int currentQuestionIndex;

  const LetterCDottedScreen({
    super.key,
    required this.activity,
    required this.questions,
    this.currentQuestionIndex = 0,
  });

  @override
  State<LetterCDottedScreen> createState() => _LetterCDottedScreenState();
}

class _LetterCDottedScreenState extends State<LetterCDottedScreen>
    with TickerProviderStateMixin {
  int _currentStep = 1;
  bool _isDrawing = false;
  List<Offset> _currentPathPoints = [];
  bool _showSuccess = false;
  bool _showStartOverlay = true;
  bool _showCleanLetter = false;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _playerCompleteSubscription;

  late AnimationController _arrowAnimationController;
  final List<Offset> _arrowPositions = [];
  final List<double> _arrowRotations = [];
  
  // Canvas için GlobalKey
  final GlobalKey _canvasKey = GlobalKey();

  // C harfi segmentleri - HTML'deki gibi (tam değerler)
  // C harfi segmentleri - HTML'deki drawCleanLetter fonksiyonundaki değerler
  // HTML: ctx.arc(160, 155, 95, Math.atan2(84 - 155, 226 - 160), Math.atan2(224 - 155, 226 - 160), true)
  final Map<String, Map<String, dynamic>> _cSegments = {
    'curve': {
      'center': const Offset(160, 155), // HTML: 160, 155
      'radius': 95.0,                    // HTML: 95
      'startAngle': math.atan2(84 - 155, 226 - 160),  // HTML: Math.atan2(84 - 155, 226 - 160)
      'endAngle': math.atan2(224 - 155, 226 - 160),    // HTML: Math.atan2(224 - 155, 226 - 160)
    },
  };

  @override
  void initState() {
    super.initState();
    _arrowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      // Ses tamamlandığında
    });

    _updateArrowPositions();
  }

  @override
  void dispose() {
    _arrowAnimationController.dispose();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _updateArrowPositions() {
    _arrowPositions.clear();
    _arrowRotations.clear();

    if (_currentStep == 1) {
      // C harfi için ok - HTML'deki gibi (207, 107), 220° rotasyon
      _arrowPositions.add(const Offset(207, 107));
      _arrowRotations.add(220.0);
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
      await _audioPlayer.play(UrlSource(url));
      _audioPlayer.setVolume(volume);
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
    final startAudioId = question.data?['audioFileId'];
    if (startAudioId != null) {
      _playAudio(startAudioId, volume: 1.0);
    }
  }

  void _startDrawingEvent(DragStartDetails details) {
    if (_showStartOverlay) return;
    
    setState(() {
      _isDrawing = true;
      _currentPathPoints = [];
      
      final RenderBox renderBox = _canvasKey.currentContext!.findRenderObject() as RenderBox;
      final localPosition = renderBox.globalToLocal(details.globalPosition);
      _currentPathPoints.add(localPosition);
    });
  }

  void _continueDrawing(DragUpdateDetails details) {
    if (!_isDrawing || _showStartOverlay) return;
    
    setState(() {
      final RenderBox renderBox = _canvasKey.currentContext!.findRenderObject() as RenderBox;
      final localPosition = renderBox.globalToLocal(details.globalPosition);
      _currentPathPoints.add(localPosition);
    });
  }

  void _endDrawing(DragEndDetails details) {
    if (!_isDrawing) return;
    
    setState(() {
      _isDrawing = false;
    });
    
    // Çizim tamamlanma kontrolü
    if (_currentPathPoints.length > 15) {
      final accuracy = _checkAccuracy();
      AppLogger.debug('Doğruluk: $accuracy, Adım: $_currentStep');
      
      if (accuracy > 0.1) {
        // Düzgün C harfi yayını göster
        _drawCleanLetter();
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

  double _checkAccuracy() {
    // Basit doğruluk kontrolü - HTML'deki gibi
    if (_currentPathPoints.length < 10) return 0;
    if (_currentPathPoints.length < 20) return 0.3;
    if (_currentPathPoints.length < 30) return 0.6;
    return 0.8;
  }

  void _drawCleanLetter() {
    setState(() {
      // Çizimi temizle ve düzgün C harfi yayını göster
      _currentPathPoints = [];
      _showCleanLetter = true;
    });
    
    // Başarı mesajını göster
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _showSuccessMessage();
      }
    });
  }

  void _showSuccessMessage() {
    setState(() {
      _showSuccess = true;
    });

    // Başarı sesini çal
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

  void _resetCanvas() {
    setState(() {
      _currentPathPoints = [];
      _showSuccess = false;
      _showCleanLetter = false;
      _currentStep = 1;
    });
    _updateArrowPositions();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[widget.currentQuestionIndex];
    final imageFileId = question.data?['imageFileId'] ?? question.mediaFileId;
    final imageUrl = imageFileId != null ? _getFileUrl(imageFileId) : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF), // HTML'deki bg: #f0f8ff
      body: SafeArea(
        child: Stack(
          children: [
            // Ana içerik
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Başlık
                    Text(
                      'C harfi noktalı çizim',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF006D77), // HTML'deki primary: #006d77
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
                                // Arka plan resmi
                                if (imageUrl.isNotEmpty)
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    child: Container(
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
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.contain,
                                          width: 320,
                                          height: 320,
                                          placeholder: (context, url) => Container(
                                            color: Colors.white,
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.white,
                                            child: const Icon(Icons.error),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                
                                // Canvas (çizim katmanı)
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onPanStart: _startDrawingEvent,
                                    onPanUpdate: _continueDrawing,
                                    onPanEnd: _endDrawing,
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.precise,
                                      child: CustomPaint(
                                        key: _canvasKey,
                                        size: const Size(320, 320),
                                        painter: LetterCDottedPainter(
                                          currentStep: _currentStep,
                                          currentPathPoints: _currentPathPoints,
                                          cSegments: _cSegments,
                                          showCleanLetter: _showCleanLetter,
                                          backgroundImageUrl: imageUrl,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Oklar
                                ...List.generate(_arrowPositions.length, (index) {
                                  if (index < _arrowPositions.length && _currentStep == 1 && !_showCleanLetter) {
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
                          SizedBox(
                            height: 24,
                            child: Text(
                              'Noktaları birleştirerek C harfini çiz',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF006D77),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Kontroller
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Reset butonu
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
                                  size: 20,
                                ),
                              ),
                            ],
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
                                '🎊 BAŞARDIN 🎊',
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
            
            // Başlatma overlay'i
            if (_showStartOverlay)
              GestureDetector(
                onTap: _startDrawing,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: Center(
                    child: Text(
                      'C harfi noktalı yazımı başlatmak için tıklayın',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
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

// Canvas painter for drawing C letter dotted
class LetterCDottedPainter extends CustomPainter {
  final int currentStep;
  final List<Offset> currentPathPoints;
  final Map<String, Map<String, dynamic>> cSegments;
  final bool showCleanLetter;
  final String backgroundImageUrl;

  LetterCDottedPainter({
    required this.currentStep,
    required this.currentPathPoints,
    required this.cSegments,
    required this.showCleanLetter,
    required this.backgroundImageUrl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1D4ED8) // #1d4ed8
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Eğer başarı mesajı gösteriliyorsa, düzgün C harfi yayını çiz
    if (showCleanLetter && currentStep == 1) {
      final seg = cSegments['curve']!;
      final center = seg['center'] as Offset;
      final radius = seg['radius'] as double;
      final startAngle = seg['startAngle'] as double;
      final endAngle = seg['endAngle'] as double;
      
      // Yay çiz (HTML'deki gibi)
      final rect = Rect.fromCircle(
        center: center,
        radius: radius,
      );
      
      // C harfi yayını çiz - HTML'deki gibi
      // HTML: ctx.arc(160, 155, 95, Math.atan2(84 - 155, 226 - 160), Math.atan2(224 - 155, 226 - 160), true)
      // true = saat yönünün tersine, Flutter'da negatif açı = saat yönünün tersine
      double sweepAngle = endAngle - startAngle;
      // HTML'de true (saat yönünün tersine) olduğu için negatif açı kullanıyoruz
      // Eğer pozitifse, negatif yap (saat yönünün tersine çizmek için)
      if (sweepAngle > 0) {
        sweepAngle = sweepAngle - 2 * math.pi;
      }
      
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
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
  bool shouldRepaint(LetterCDottedPainter oldDelegate) {
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

