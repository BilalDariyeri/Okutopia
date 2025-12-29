import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/mini_question_model.dart';
import '../models/activity_model.dart';
import '../config/api_config.dart';
import '../services/activity_tracker_service.dart';
import '../services/current_session_service.dart';
import '../providers/auth_provider.dart';
import '../utils/app_logger.dart';

class LetterDottedScreen extends StatefulWidget {
  final Activity activity;
  final List<MiniQuestion> questions;
  final int currentQuestionIndex;

  const LetterDottedScreen({
    super.key,
    required this.activity,
    required this.questions,
    this.currentQuestionIndex = 0,
  });

  @override
  State<LetterDottedScreen> createState() => _LetterDottedScreenState();
}

class _LetterDottedScreenState extends State<LetterDottedScreen>
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
  List<Offset> _arrowPositions = [];
  List<double> _arrowRotations = [];
  
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
      'start': const Offset(105, 200),
      'end': const Offset(215, 200),
    },
  };

  // Ok offset'leri
  final Map<String, Offset> _arrowOffsets = {
    'leftDiagonal': const Offset(-40, 0),
    'rightDiagonal': const Offset(40, 0),
    'crossBar': const Offset(20, 40),
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
    
    _updateArrowPositions();
    _startActivityTracking();
    
    // Başlangıç sesini çal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playStartAudio();
    });
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
      
      // Oturum servisine de ekle (TAMAMLANMIŞ olarak işaretle)
      _sessionService.addActivity(
        studentId: studentId,
        activityId: widget.activity.id,
        activityTitle: widget.activity.title,
        durationSeconds: duration,
        successStatus: successStatus ?? (_showSuccess ? 'Başarılı' : 'Tamamlandı'),
        isCompleted: true, // Aktivite başarıyla tamamlandı
        correctAnswerCount: 0, // Bu aktivite tipinde doğru cevap sayısı yok
      );
    }
  }

  String _getFileUrl(String? fileId) {
    if (fileId == null) return '';
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    return '$baseUrl/api/files/$fileId';
  }

  Future<void> _playAudio(String? fileId, {double volume = 1.0}) async {
    if (fileId == null || fileId.isEmpty) return;
    try {
      final url = _getFileUrl(fileId);
      await _audioPlayer.setVolume(volume);
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      AppLogger.error('Ses çalınamadı', e);
    }
  }

  void _playStartAudio() {
    final question = widget.questions[widget.currentQuestionIndex];
    // Ses dosyası ID'sini question'dan al
    final audioFileId = question.data?['audioFileId'] ?? question.mediaFileId;
    if (audioFileId != null) {
      _playAudio(audioFileId.toString());
    }
  }

  Map<String, Offset> _getShiftedSegment(String segmentKey) {
    final seg = _aSegments[segmentKey]!;
    final start = seg['start']!;
    final end = seg['end']!;
    
    // Normal vektörü hesapla
    final vx = end.dx - start.dx;
    final vy = end.dy - start.dy;
    final len = math.sqrt(vx * vx + vy * vy);
    if (len == 0) return {'start': start, 'end': end};
    
    final ux = vx / len;
    final uy = vy / len;
    final nx = -uy;
    final ny = ux;
    
    // Offset'i uygula
    int offset = 0;
    if (segmentKey == 'leftDiagonal') offset = -3;
    if (segmentKey == 'rightDiagonal') offset = 3;
    if (segmentKey == 'crossBar') offset = 0;
    
    return {
      'start': Offset(start.dx + nx * offset, start.dy + ny * offset),
      'end': Offset(end.dx + nx * offset, end.dy + ny * offset),
    };
  }

  void _updateArrowPositions() {
    final positions = <Offset>[];
    final rotations = <double>[];
    
    if (_currentStep == 1) {
      final seg = _getShiftedSegment('leftDiagonal');
      final offset = _arrowOffsets['leftDiagonal']!;
      positions.add(Offset(seg['start']!.dx + offset.dx, seg['start']!.dy + offset.dy));
      rotations.add(135.0);
    } else if (_currentStep == 2) {
      final seg = _getShiftedSegment('rightDiagonal');
      final offset = _arrowOffsets['rightDiagonal']!;
      positions.add(Offset(seg['start']!.dx + offset.dx, seg['start']!.dy + offset.dy));
      rotations.add(45.0);
    } else if (_currentStep == 3) {
      final seg = _getShiftedSegment('crossBar');
      final offset = _arrowOffsets['crossBar']!;
      positions.add(Offset(seg['start']!.dx + offset.dx, seg['start']!.dy + offset.dy));
      rotations.add(0.0);
    }
    
    setState(() {
      _arrowPositions = positions;
      _arrowRotations = rotations;
    });
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
      if (completionRatio > 0.7) { // %70'den fazla noktaya yaklaşmışsa düzelt
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
        Future.delayed(const Duration(milliseconds: 1000), () {
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
    
    // Noktaları al
    final dots = _getDotsForSegment(targetSeg);
    
    // Çizilen path'in noktalara yakınlığını kontrol et
    int dotsHit = 0;
    for (final point in _currentPathPoints) {
      for (final dot in dots) {
        final distance = math.sqrt(
          math.pow(point.dx - dot.dx, 2) + math.pow(point.dy - dot.dy, 2)
        );
        if (distance < 15) { // 15 piksel yakınlık
          dotsHit++;
          break; // Bu nokta için sadece bir kez say
        }
      }
    }
    
    // Noktaların en az %70'ine yaklaşmışsa kabul et
    if (dots.isEmpty) return 0.0;
    return dotsHit / dots.length;
  }

  List<Offset> _getDotsForSegment(Map<String, Offset> segment) {
    final dots = <Offset>[];
    final start = segment['start']!;
    final end = segment['end']!;
    
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final steps = (distance / 12).floor(); // 12 piksel aralıklarla noktalar
    
    for (int i = 0; i <= steps; i++) {
      final t = steps > 0 ? i / steps : 0.0;
      final x = start.dx + dx * t;
      final y = start.dy + dy * t;
      dots.add(Offset(x, y));
    }
    
    return dots;
  }

  void _showSuccessMessage() {
    setState(() {
      _showSuccess = true;
    });

    // Başarı sesini çal
    final question = widget.questions[widget.currentQuestionIndex];
    // Başarı sesi için successAudioFileId veya audioFileId kullanılabilir
    final successAudioFileId = question.data?['successAudioFileId'] ?? question.data?['audioFileId'];
    if (successAudioFileId != null) {
      _playAudio(successAudioFileId.toString(), volume: 1.0);
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
              left: 50.0 + 40.0 * math.cos(time * 0.6),
              bottom: 80.0 + 50.0 * math.sin(time * 0.6),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.pink.withValues(alpha: 0.4),
                      Colors.purple.withValues(alpha: 0.3),
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
              right: -30.0 + 35.0 * math.cos(time * 0.7),
              bottom: 120.0 + 40.0 * math.sin(time * 0.7),
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.cyan.withValues(alpha: 0.4),
                      Colors.blue.withValues(alpha: 0.3),
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
                          'A Harfi Noktalı Yazım',
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
                                    // Arka plan (beyaz)
                                    Container(
                                      width: 320,
                                      height: 320,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                          width: 2,
                                        ),
                                        color: Colors.white,
                                      ),
                                    ),
                                    
                                    // Canvas (noktalı A harfi + çizimler üstte)
                                    GestureDetector(
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
                                            _continueDrawing(localPosition);
                                          }
                                        }
                                      },
                                      onPanEnd: (details) {
                                        _endDrawing();
                                      },
                                      child: CustomPaint(
                                        key: _canvasKey,
                                        size: const Size(320, 320),
                                        painter: LetterDottedPainter(
                                          currentStep: _currentStep,
                                          currentPathPoints: _currentPathPoints,
                                          completedSegments: _completedSegments,
                                          aSegments: _aSegments,
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
                              SizedBox(
                                height: 24,
                                child: const Text(
                                  'Noktaları birleştirerek A harfini çiz.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF006D77),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              
                              // Kontrol butonları
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: _resetCanvas,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF006D77),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      minimumSize: const Size(44, 44),
                                    ),
                                    child: const Icon(Icons.cleaning_services, size: 24),
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
                                builder: (context) => LetterDottedScreen(
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
                                builder: (context) => LetterDottedScreen(
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

// Canvas painter for dotted letter
class LetterDottedPainter extends CustomPainter {
  final int currentStep;
  final List<Offset> currentPathPoints;
  final List<Map<String, Offset>> completedSegments;
  final Map<String, Map<String, Offset>> aSegments;

  LetterDottedPainter({
    required this.currentStep,
    required this.currentPathPoints,
    required this.completedSegments,
    required this.aSegments,
  });

  Map<String, Offset> _getShiftedSegment(String segmentKey) {
    final seg = aSegments[segmentKey]!;
    final start = seg['start']!;
    final end = seg['end']!;
    
    // Normal vektörü hesapla
    final vx = end.dx - start.dx;
    final vy = end.dy - start.dy;
    final len = math.sqrt(vx * vx + vy * vy);
    if (len == 0) return {'start': start, 'end': end};
    
    final ux = vx / len;
    final uy = vy / len;
    final nx = -uy;
    final ny = ux;
    
    // Offset'i uygula
    int offset = 0;
    if (segmentKey == 'leftDiagonal') offset = -3;
    if (segmentKey == 'rightDiagonal') offset = 3;
    if (segmentKey == 'crossBar') offset = 0;
    
    return {
      'start': Offset(start.dx + nx * offset, start.dy + ny * offset),
      'end': Offset(end.dx + nx * offset, end.dy + ny * offset),
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Noktalı A harfini çiz
    _drawDottedA(canvas, size);
    
    // Tamamlanmış segmentleri çiz (otomatik düzeltilmiş düzgün çizgiler)
    final paint = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

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

  void _drawDottedA(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFF666666)
      ..style = PaintingStyle.fill;

    // Her segment için noktaları çiz
    for (final segmentEntry in aSegments.entries) {
      final seg = _getShiftedSegment(segmentEntry.key);
      _drawDottedLine(canvas, seg['start']!, seg['end']!, dotPaint, 12);
    }
  }

  void _drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint, double spacing) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final steps = (distance / spacing).floor();
    
    for (int i = 0; i <= steps; i++) {
      final t = steps > 0 ? i / steps : 0.0;
      final x = start.dx + dx * t;
      final y = start.dy + dy * t;
      
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(LetterDottedPainter oldDelegate) {
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

