import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/mini_question_model.dart';
import '../models/activity_model.dart';
import '../config/api_config.dart';
import '../services/activity_tracker_service.dart';
import '../services/current_session_service.dart';
import '../providers/auth_provider.dart';

class LetterDrawingScreen extends StatefulWidget {
  final Activity activity;
  final List<MiniQuestion> questions;
  final int currentQuestionIndex;

  const LetterDrawingScreen({
    super.key,
    required this.activity,
    required this.questions,
    this.currentQuestionIndex = 0,
  });

  @override
  State<LetterDrawingScreen> createState() => _LetterDrawingScreenState();
}

class _LetterDrawingScreenState extends State<LetterDrawingScreen>
    with TickerProviderStateMixin {
  int _currentStep = 1;
  bool _isDrawing = false;
  List<Offset> _currentPathPoints = [];
  List<Map<String, Offset>> _completedSegments = []; // Düzgün segmentleri sakla (otomatik düzeltme sonrası)
  
  bool _showSuccess = false;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _playerCompleteSubscription;
  final ActivityTrackerService _activityTracker = ActivityTrackerService();
  final CurrentSessionService _sessionService = CurrentSessionService();
  DateTime? _activityStartTime;
  String? _studentId; // dispose() içinde context kullanmamak için saklanıyor

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

  // A harfi segmentleri
  final Map<String, Map<String, Offset>> _aSegments = {
    'leftDiagonal': {
      'start': const Offset(160, 46),
      'end': const Offset(75, 262),
    },
    'rightDiagonal': {
      'start': const Offset(160, 46),
      'end': const Offset(245, 262),
    },
    'crossBar': {
      'start': const Offset(115, 200),
      'end': const Offset(225, 200),
    },
  };

  // Ok offset'leri
  final Map<String, Offset> _arrowOffsets = {
    'leftDiagonal': const Offset(-65, 0),
    'rightDiagonal': const Offset(55, -3),
    'crossBar': const Offset(25, 55),
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
    _startActivityTracking();
    
    // Başlangıç sesini çal
    final question = widget.questions[widget.currentQuestionIndex];
    final audioFileId = question.data?['audioFileId'];
    if (audioFileId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playAudio(audioFileId);
      });
    }
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
    _endActivityTracking();
    super.dispose();
  }

  Future<void> _startActivityTracking() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final selectedStudent = authProvider.selectedStudent;
    
    if (selectedStudent != null) {
      _studentId = selectedStudent.id; // dispose() için sakla
      _activityStartTime = DateTime.now();
      await _activityTracker.startActivity(
        studentId: selectedStudent.id,
        activityId: widget.activity.id,
        activityTitle: widget.activity.title,
      );
    }
  }

  Future<void> _endActivityTracking({String? successStatus}) async {
    // dispose() içinde çağrıldığında context kullanılamaz, bu yüzden _studentId kullanıyoruz
    final studentId = _studentId ?? (mounted ? Provider.of<AuthProvider>(context, listen: false).selectedStudent?.id : null);
    
    if (studentId != null && _activityStartTime != null) {
      final duration = DateTime.now().difference(_activityStartTime!).inSeconds;
      
      await _activityTracker.endActivity(
        studentId: studentId,
        activityId: widget.activity.id,
        successStatus: successStatus ?? (_showSuccess ? 'Başarılı' : 'Tamamlandı'),
      );
      
      // Oturum servisine de ekle
      _sessionService.addActivity(
        studentId: studentId,
        activityId: widget.activity.id,
        activityTitle: widget.activity.title,
        durationSeconds: duration,
        successStatus: successStatus ?? (_showSuccess ? 'Başarılı' : 'Tamamlandı'),
      );
    }
  }

  void _updateArrowPositions() {
    _arrowPositions.clear();
    _arrowRotations.clear();

    if (_currentStep == 1) {
      final seg = _getShiftedSegment('leftDiagonal');
      final offset = _arrowOffsets['leftDiagonal']!;
      _arrowPositions.add(seg['start']! + offset);
      _arrowRotations.add(135.0);
    } else if (_currentStep == 2) {
      final seg = _getShiftedSegment('rightDiagonal');
      final offset = _arrowOffsets['rightDiagonal']!;
      _arrowPositions.add(seg['start']! + offset);
      _arrowRotations.add(45.0);
    } else if (_currentStep == 3) {
      final seg = _getShiftedSegment('crossBar');
      final offset = _arrowOffsets['crossBar']!;
      _arrowPositions.add(seg['start']! + offset);
      _arrowRotations.add(0.0);
    }
  }

  Map<String, Offset> _getShiftedSegment(String segmentKey) {
    final seg = _aSegments[segmentKey]!;
    final start = seg['start']!;
    final end = seg['end']!;
    
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    
    if (len == 0) {
      return {'start': start, 'end': end};
    }
    
    final ux = dx / len;
    final uy = dy / len;
    final nx = -uy;
    final ny = ux;
    
    final offset = segmentKey == 'leftDiagonal' ? -3.0 : 
                   segmentKey == 'rightDiagonal' ? 3.0 : 0.0;
    
    return {
      'start': Offset(start.dx + nx * offset, start.dy + ny * offset),
      'end': Offset(end.dx + nx * offset, end.dy + ny * offset),
    };
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
      print('Ses çalınamadı: $e');
    }
  }

  void _resetCanvas() {
    setState(() {
      _currentStep = 1;
      _currentPathPoints = [];
      _completedSegments = [];
      _showSuccess = false;
      _updateArrowPositions();
    });
  }

  void _startDrawing(Offset position) {
    setState(() {
      _isDrawing = true;
      _currentPathPoints = [position];
    });
  }

  void _continueDrawing(Offset position) {
    if (!_isDrawing) return;
    
    setState(() {
      _currentPathPoints.add(position);
    });
  }

  void _endDrawing() {
    if (!_isDrawing) return;
    
    setState(() {
      _isDrawing = false;
    });
    
    // Çizim tamamlanma oranını kontrol et
    if (_currentPathPoints.length > 10) {
      final completionRatio = _checkSegmentCompletion();
      if (completionRatio > 0.6) {
        // Kullanıcının çizdiği yamuk yumuk çizgiyi otomatik olarak düzgün çizgiye dönüştür
        String segmentKey = '';
        if (_currentStep == 1) segmentKey = 'leftDiagonal';
        if (_currentStep == 2) segmentKey = 'rightDiagonal';
        if (_currentStep == 3) segmentKey = 'crossBar';
        
        final cleanSegment = _getShiftedSegment(segmentKey);
        
        setState(() {
          _completedSegments.add(cleanSegment); // Düzgün segmenti ekle (otomatik düzeltme)
          _currentPathPoints = []; // Ham çizimi temizle
        });
        
        // Bir sonraki adıma geç
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            if (_currentStep < 3) {
              setState(() {
                _currentStep += 1;
                _updateArrowPositions();
              });
            } else {
              _showSuccessMessage();
            }
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
    String segmentKey = '';
    if (_currentStep == 1) segmentKey = 'leftDiagonal';
    if (_currentStep == 2) segmentKey = 'rightDiagonal';
    if (_currentStep == 3) segmentKey = 'crossBar';
    
    final targetSeg = _getShiftedSegment(segmentKey);
    
    // Çizim yolunun toplam uzunluğunu hesapla
    double drawnLength = 0;
    for (int i = 1; i < _currentPathPoints.length; i++) {
      final dx = _currentPathPoints[i].dx - _currentPathPoints[i-1].dx;
      final dy = _currentPathPoints[i].dy - _currentPathPoints[i-1].dy;
      drawnLength += math.sqrt(dx * dx + dy * dy);
    }
    
    // Hedef segment uzunluğu
    final targetLength = math.sqrt(
      math.pow(targetSeg['end']!.dx - targetSeg['start']!.dx, 2) + 
      math.pow(targetSeg['end']!.dy - targetSeg['start']!.dy, 2)
    );
    
    return drawnLength / targetLength;
  }


  void _showSuccessMessage() {
    setState(() {
      _showSuccess = true;
    });

    // Başarı sesini çal
    // final question = widget.questions[widget.currentQuestionIndex];
    // _playAudio(successAudioId, volume: 1.0);

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
          // Arka plan (uzay teması)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF6C5CE7), // Açık mor
                  Color(0xFF4834D4), // Orta mor
                  Color(0xFF2D1B69), // Koyu mor
                ],
              ),
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
                          'A Harfi Serbest Çizim',
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
                                        final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                        if (box != null) {
                                          final localPosition = box.globalToLocal(details.globalPosition);
                                          if (localPosition.dx >= 0 && localPosition.dx <= 320 &&
                                              localPosition.dy >= 0 && localPosition.dy <= 320) {
                                            _startDrawing(localPosition);
                                          }
                                        }
                                      },
                                      onPanUpdate: (details) {
                                        if (_isDrawing) {
                                          final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                          if (box != null) {
                                            final localPosition = box.globalToLocal(details.globalPosition);
                                            if (localPosition.dx >= 0 && localPosition.dx <= 320 &&
                                                localPosition.dy >= 0 && localPosition.dy <= 320) {
                                              _continueDrawing(localPosition);
                                            }
                                          }
                                        }
                                      },
                                      onPanEnd: (details) {
                                        _endDrawing();
                                      },
                                      child: CustomPaint(
                                        key: _canvasKey,
                                        size: const Size(320, 320),
                                        painter: LetterDrawingPainter(
                                          currentStep: _currentStep,
                                          currentPathPoints: _currentPathPoints,
                                          completedSegments: _completedSegments,
                                        ),
                                      ),
                                    ),
                                    
                                    // Oklar
                                    ...List.generate(_arrowPositions.length, (index) {
                                      if (index < _arrowPositions.length) {
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
                                  'Okları takip ederek A harfini çiz',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF006D77),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Reset butonu
                              ElevatedButton(
                                onPressed: _resetCanvas,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF006D77),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.all(12),
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
                                builder: (context) => LetterDrawingScreen(
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
                                builder: (context) => LetterDrawingScreen(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Canvas painter for drawing letter
class LetterDrawingPainter extends CustomPainter {
  final int currentStep;
  final List<Offset> currentPathPoints;
  final List<Map<String, Offset>> completedSegments; // Otomatik düzeltilmiş düzgün segmentler

  LetterDrawingPainter({
    required this.currentStep,
    required this.currentPathPoints,
    required this.completedSegments,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Tamamlanmış segmentleri çiz (otomatik düzeltilmiş düzgün çizgiler)
    for (final seg in completedSegments) {
      canvas.drawLine(seg['start']!, seg['end']!, paint);
    }

    // Kullanıcının şu anda çizdiği ham çizgiyi göster (yamuk yumuk, henüz düzeltilmemiş)
    if (currentPathPoints.length > 1) {
      final path = Path();
      path.moveTo(currentPathPoints[0].dx, currentPathPoints[0].dy);
      for (int i = 1; i < currentPathPoints.length; i++) {
        path.lineTo(currentPathPoints[i].dx, currentPathPoints[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(LetterDrawingPainter oldDelegate) {
    return oldDelegate.currentStep != currentStep ||
        oldDelegate.currentPathPoints.length != currentPathPoints.length ||
        oldDelegate.completedSegments.length != completedSegments.length;
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

