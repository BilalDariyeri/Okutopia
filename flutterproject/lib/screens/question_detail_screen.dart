import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/mini_question_model.dart';
import '../models/activity_model.dart';
import '../config/api_config.dart';
import '../services/activity_tracker_service.dart';
import '../services/current_session_service.dart';
import '../providers/auth_provider.dart';
import '../utils/app_logger.dart';
import 'letter_find_screen.dart';
import 'letter_writing_screen.dart';
import 'letter_drawing_screen.dart';
import 'letter_dotted_screen.dart';
import 'letter_writing_board_screen.dart';

class QuestionDetailScreen extends StatefulWidget {
  final Activity activity;
  final List<MiniQuestion> questions;
  final int currentQuestionIndex;

  const QuestionDetailScreen({
    super.key,
    required this.activity,
    required this.questions,
    this.currentQuestionIndex = 0,
  });

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _score = 0;
  int _wrongAnswers = 0;
  bool _hasAnswered = false;
  bool? _userAnswer; // true = evet, false = hayır
  bool _audioPlayed = false; // Sesi hissetme butonuna tıklanıp tıklanmadığını takip eder
  bool _gameStarted = false;
  bool _showOverlay = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _introAudioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  bool _introAudioPlaying = false;
  StreamSubscription? _playerCompleteSubscription;
  
  // Animasyon controller'ları
  late AnimationController _starController;
  late AnimationController _planet1Controller;
  late AnimationController _planet2Controller;
  late AnimationController _planet3Controller;
  late AnimationController _planet4Controller;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentQuestionIndex;

    // Animasyon controller'ları
    _starController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _planet1Controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _planet2Controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    _planet3Controller = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
    
    _planet4Controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
    
    // Ses çalma tamamlandığında dinle
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });
    
    // Intro audio tamamlandığında dinle
    _introAudioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _introAudioPlaying = false;
          _gameStarted = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _introAudioPlayer.dispose();
    _starController.dispose();
    _planet1Controller.dispose();
    _planet2Controller.dispose();
    _planet3Controller.dispose();
    _planet4Controller.dispose();
    super.dispose();
  }

  String _getFileUrl(String? fileId) {
    if (fileId == null) return '';
    // API base URL'den /api kısmını kaldırıp dosya URL'i oluştur
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    return '$baseUrl/api/files/$fileId';
  }

<<<<<<< HEAD
  /// Tüm soruların resimlerini önceden yükle (preload)
  void _preloadAllQuestionImages() {
    if (!mounted) return;
    
    // Tüm soruların resimlerini sırayla preload et
    for (int i = 0; i < widget.questions.length; i++) {
      final question = widget.questions[i];
      final imageFileId = question.mediaFileId;
      
      if (imageFileId != null && imageFileId.isNotEmpty) {
        final imageUrl = _getFileUrl(imageFileId);
        
        // URL geçerliliğini kontrol et
        if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
          continue;
        }
        
        // Resmi önceden cache'e yükle (hata durumunda sessizce devam et)
        Future.delayed(Duration(milliseconds: i * 100), () async {
          if (!mounted) return;
          
          try {
            await precacheImage(
              CachedNetworkImageProvider(imageUrl),
              context,
            ).timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                AppLogger.debug('Preload timeout (soru ${i + 1})');
              },
            );
          } catch (e) {
            // Hata durumunda sessizce devam et (resim bozuk veya erişilemez olabilir)
            // Bu normal bir durum olabilir, bu yüzden sadece debug modda loglayalım
            AppLogger.debug('Preload hatası (soru ${i + 1}): $e');
          }
        });
      }
    }
  }

  /// Bir sonraki sorunun resmini önceden yükle (preload)
  void _preloadNextQuestionImage() {
    if (!mounted) return;
    
    if (_currentIndex + 1 < widget.questions.length) {
      final nextQuestion = widget.questions[_currentIndex + 1];
      final nextImageFileId = nextQuestion.mediaFileId;
      
      if (nextImageFileId != null && nextImageFileId.isNotEmpty) {
        final imageUrl = _getFileUrl(nextImageFileId);
        
        // URL geçerliliğini kontrol et
        if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
          return;
        }
        
        // Resmi önceden cache'e yükle (hata durumunda sessizce devam et)
        precacheImage(
          CachedNetworkImageProvider(imageUrl),
          context,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            AppLogger.debug('Preload timeout (sonraki soru)');
          },
        ).catchError((error) {
          // Hata durumunda sessizce devam et (resim bozuk veya erişilemez olabilir)
          AppLogger.debug('Preload hatası: $error');
        });
      }
    }
  }

  Future<void> _playAudio(String? fileId) async {
    if (fileId == null || !_gameStarted || _introAudioPlaying) return;
    
    // Eğer zaten çalıyorsa, durdur
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingAudio = false;
      });
      return;
    }
    
    setState(() {
      _isPlayingAudio = true;
    });

    try {
      final url = _getFileUrl(fileId);
      
      // Önce mevcut sesi durdur
      await _audioPlayer.stop();
      
      // Yeni sesi çal
      await _audioPlayer.play(UrlSource(url));
      
      setState(() {
        _audioPlayed = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ses çalınamadı: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startGame() {
    setState(() {
      _showOverlay = false;
      _introAudioPlaying = true;
    });
    
    // Giriş sesini çal (varsa)
    final question = widget.questions[_currentIndex];
    final introAudioFileId = question.data?['introAudioFileId'];
    
    if (introAudioFileId != null) {
      try {
        final url = _getFileUrl(introAudioFileId);
        _introAudioPlayer.play(UrlSource(url));
      } catch (e) {
        // Ses yoksa da oyunu başlat
        setState(() {
          _introAudioPlaying = false;
          _gameStarted = true;
        });
      }
    } else {
      // Giriş sesi yoksa direkt oyunu başlat
      setState(() {
        _introAudioPlaying = false;
        _gameStarted = true;
      });
    }
  }

  void _checkAnswer(bool answer) {
    if (_hasAnswered || !_gameStarted || !_audioPlayed || _introAudioPlaying) return;
      
      final question = widget.questions[_currentIndex];
      final correctAnswer = question.correctAnswer?.toLowerCase().trim();
      
      // Cevap kontrolü (Evet/Hayır veya true/false)
      bool isCorrect = false;
      if (correctAnswer != null) {
      if (answer &&
          (correctAnswer == 'evet' ||
              correctAnswer == 'yes' ||
              correctAnswer == 'true' ||
              correctAnswer == '✓')) {
          isCorrect = true;
      } else if (!answer &&
          (correctAnswer == 'hayır' ||
              correctAnswer == 'no' ||
              correctAnswer == 'false' ||
              correctAnswer == '✗' ||
              correctAnswer == 'x')) {
          isCorrect = true;
        }
      }
      
    setState(() {
      _hasAnswered = true;
      _userAnswer = answer;
      if (isCorrect) {
        _score++;
      } else {
        _wrongAnswers++;
      }
    });

    // 3 saniye sonra bir sonraki soruya geç (HTML'deki gibi)
    Timer(const Duration(seconds: 3), () {
      if (mounted && _currentIndex < widget.questions.length - 1) {
        setState(() {
          _currentIndex++;
          _hasAnswered = false;
          _userAnswer = null;
          _audioPlayed = false;
        });
      } else if (mounted) {
<<<<<<< HEAD
        // Tüm sorular bitti - aktiviteyi oturum servisine ekle
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final selectedStudent = authProvider.selectedStudent;
        
        if (selectedStudent != null && _activityStartTime != null) {
          final duration = DateTime.now().difference(_activityStartTime!).inSeconds;
          final successRate = (_score / widget.questions.length * 100).round();
          final successStatus = '$_score/${widget.questions.length} soru doğru (%$successRate)';
          
          _sessionService.addActivity(
            studentId: selectedStudent.id,
            activityId: widget.activity.id,
            activityTitle: widget.activity.title,
            durationSeconds: duration,
            successStatus: successStatus,
          );
        }
        
        // Tüm sorular bitti
        _showCompletionDialog();
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎉 Tebrikler!',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Etkinliği tamamladın!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Toplam Puan: $_score/${widget.questions.length}',
                      style: const TextStyle(
                        color: Color(0xFF87CEEB),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Doğru Cevap: $_score',
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Yanlış: $_wrongAnswers',
                          style: const TextStyle(
                            color: Color(0xFFF44336),
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dialog'u kapat
              Navigator.of(context).pop(); // Soru ekranından çık
            },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Yeniden Başla',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  String _getQuestionText(MiniQuestion question) {
    // data objesinden soru metnini al
    if (question.data != null) {
      final questionText =
          question.data!['questionText'] ??
                          question.data!['text'] ?? 
                          question.data!['soru'];
      if (questionText != null) {
        return questionText.toString();
      }
    }
    
    // Varsayılan soru metni
    return 'Resme bak! Kelime içinde "a" harfi var mı?';
  }

  String _getInstructionText(MiniQuestion question) {
    // data objesinden açıklama metnini al
    if (question.data != null) {
      final instruction =
          question.data!['instruction'] ??
                         question.data!['aciklama'] ??
                         question.data!['description'];
      if (instruction != null) {
        return instruction.toString();
      }
    }
    
    // Varsayılan açıklama
    return 'Önce "Sesi Hisset" butonuna tıkla, sonra kelime içinde "a" harfi varsa tik (✓), yoksa çarpı (✗) butonuna tıkla!';
  }

  Widget _buildSpaceBackground() {
    return Stack(
      children: [
        // Star field
        AnimatedBuilder(
          animation: _starController,
          builder: (context, child) {
            return CustomPaint(
              painter: StarFieldPainter(_starController.value),
              size: Size.infinite,
            );
          },
        ),
        // Planets
        AnimatedBuilder(
          animation: _planet1Controller,
          builder: (context, child) {
            final time = _planet1Controller.value * 2 * math.pi;
            return Positioned(
              left: 50.0 + 25.0 * math.sin(time),
              top: 100.0 + 35.0 * math.cos(time),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF39C12).withValues(alpha: 0.5),
                      const Color(0xFFE67E22).withValues(alpha: 0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _planet2Controller,
          builder: (context, child) {
            final time = _planet2Controller.value * 2 * math.pi;
            return Positioned(
              right: 50.0 + 30.0 * math.sin(time * 0.8),
              top: 150.0 + 45.0 * math.cos(time * 0.8),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE67E22).withValues(alpha: 0.5),
                      const Color(0xFFD35400).withValues(alpha: 0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _planet3Controller,
          builder: (context, child) {
            final time = _planet3Controller.value * 2 * math.pi;
            return Positioned(
              left: 100.0 + 20.0 * math.sin(time),
              bottom: 150.0 + 30.0 * math.cos(time),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3498DB).withValues(alpha: 0.5),
                      const Color(0xFF2980B9).withValues(alpha: 0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _planet4Controller,
          builder: (context, child) {
            final time = _planet4Controller.value * 2 * math.pi;
            return Positioned(
              right: 80.0 + 25.0 * math.sin(time),
              bottom: 200.0 + 40.0 * math.cos(time),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE74C3C).withValues(alpha: 0.5),
                      const Color(0xFFC0392B).withValues(alpha: 0.3),
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
    if (_currentIndex >= widget.questions.length) {
      return Scaffold(
        body: Center(
          child: Text(
            'Tüm sorular tamamlandı!',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    final question = widget.questions[_currentIndex];
<<<<<<< HEAD
    
    
    // Debug: Soru tipini kontrol et
    AppLogger.debug('QuestionDetailScreen - Question Type: ${question.questionType}');
    AppLogger.debug('QuestionDetailScreen - Question Format: ${question.questionFormat}');
    AppLogger.debug('QuestionDetailScreen - Question Data: ${question.data}');
    AppLogger.debug('QuestionDetailScreen - Activity Title: ${widget.activity.title}');
    
    // Kelimede harf bulma soru tipi için özel ekran
    final questionType = question.questionType.toString().toUpperCase();
    final questionFormat = (question.questionFormat ?? question.questionType).toString().toUpperCase() ?? '';
    final adminNote = question.data?['adminNote']?.toString().toUpperCase() ?? '';
    final activityTitle = widget.activity.title?.toString().toUpperCase() ?? '';
    
    // contentObject'te words array'i var mı kontrol et
    final contentObject = question.data?['contentObject'];
    final hasWordsArray = contentObject != null && 
        contentObject is Map && 
        contentObject['words'] != null &&
        contentObject['words'] is List &&
        (contentObject['words'] as List).isNotEmpty;
    
    AppLogger.debug('Has words array: $hasWordsArray');
    AppLogger.debug('ContentObject: $contentObject');
    
    // Harf yazımı kontrolü (önce harf yazımını kontrol et) - ÇOK AGRESİF
    final questionTextForCheck = _getQuestionText(question);
    final questionTextUpper = questionTextForCheck.toUpperCase();
    
    // Yazı tahtası kontrolü (en spesifik - önce kontrol et)
    final isWritingBoard = 
        questionFormat == 'YAZI_TAHTASI' ||
        questionType == 'YAZI_TAHTASI' ||
        questionFormat.contains('YAZI_TAHTASI') ||
        questionType.contains('YAZI_TAHTASI') ||
        questionFormat.contains('WRITING_BOARD') ||
        questionType.contains('WRITING_BOARD') ||
        questionTextUpper.contains('YAZI TAHTASI') ||
        questionTextUpper.contains('YAZI TAHTA') ||
        adminNote.contains('YAZI TAHTASI') ||
        adminNote.contains('YAZI TAHTA') ||
        activityTitle.contains('YAZI TAHTASI') ||
        activityTitle.contains('YAZI TAHTA');
    
    // Harf noktalı yazım kontrolü (önce noktalı yazımı kontrol et - en spesifik)
    final isLetterDotted = 
        questionFormat == 'NOKTALI_YAZIM' ||
        questionType == 'NOKTALI_YAZIM' ||
        questionFormat.contains('NOKTALI_YAZIM') ||
        questionType.contains('NOKTALI_YAZIM') ||
        questionFormat.contains('DOTTED') ||
        questionType.contains('DOTTED') ||
        questionTextUpper.contains('NOKTALI YAZIM') ||
        questionTextUpper.contains('NOKTALI YAZ') ||
        questionTextUpper.contains('NOKTALI') ||
        adminNote.contains('NOKTALI YAZIM') ||
        adminNote.contains('NOKTALI YAZ') ||
        adminNote.contains('NOKTALI') ||
        activityTitle.contains('NOKTALI YAZIM') ||
        activityTitle.contains('NOKTALI YAZ') ||
        activityTitle.contains('NOKTALI');
    
    // Harf serbest çizim kontrolü (önce serbest çizimi kontrol et)
    final isLetterDrawing = 
        questionFormat == 'SERBEST_CIZIM' ||
        questionType == 'SERBEST_CIZIM' ||
        questionFormat.contains('SERBEST_CIZIM') ||
        questionType.contains('SERBEST_CIZIM') ||
        questionFormat.contains('LETTER_DRAWING') ||
        questionType.contains('LETTER_DRAWING') ||
        questionFormat.contains('FREE_DRAWING') ||
        questionType.contains('FREE_DRAWING') ||
        questionTextUpper.contains('SERBEST ÇİZİM') ||
        questionTextUpper.contains('SERBEST ÇIZIM') ||
        questionTextUpper.contains('SERBEST') ||
        adminNote.contains('SERBEST ÇİZİM') ||
        adminNote.contains('SERBEST ÇIZIM') ||
        adminNote.contains('SERBEST') ||
        activityTitle.contains('SERBEST ÇİZİM') ||
        activityTitle.contains('SERBEST ÇIZIM') ||
        activityTitle.contains('SERBEST');
    
    // Harf yazımı kontrolü - ÇOK AGRESİF (her şekilde tespit et)
    final isLetterWriting = 
        questionFormat == 'HARF_YAZIMI' ||
        questionType == 'HARF_YAZIMI' ||
        questionFormat.contains('HARF_YAZIMI') ||
        questionType.contains('HARF_YAZIMI') ||
        questionFormat.contains('LETTER_WRITING') ||
        questionType.contains('LETTER_WRITING') ||
        questionTextUpper.contains('NASIL YAZILIR') ||
        questionTextUpper.contains('YAZILIR') ||
        questionTextUpper.contains('YAZIM') ||
        adminNote.contains('NASIL YAZILIR') ||
        adminNote.contains('YAZILIR') ||
        adminNote.contains('YAZIM') ||
        adminNote.contains('HARF YAZIMI') ||
        adminNote.contains('HARF_YAZIMI') ||
        activityTitle.contains('YAZIM') ||
        activityTitle.contains('YAZILIR') ||
        activityTitle.contains('HARF YAZIMI') ||
        activityTitle.contains('HARF_YAZIMI') ||
        activityTitle.contains('HARF YAZ') ||
        // Eğer activity title'da "harf" ve ("yazım" veya "nasıl") geçiyorsa
        (activityTitle.contains('HARF') && (activityTitle.contains('YAZIM') || activityTitle.contains('YAZILIR') || activityTitle.contains('YAZ')));
    
    // Kelimede harf bulma kontrolü - ÇOK AGRESİF
    // ÖNCE: questionFormat veya questionType'a bak
    final isLetterFind = 
        questionFormat == 'KELIMEDE_HARF_BULMA' ||
        questionType == 'KELIMEDE_HARF_BULMA' || 
        questionFormat.contains('KELIMEDE_HARF_BULMA') || 
        questionType.contains('KELIMEDE_HARF_BULMA') ||
        questionFormat.contains('LETTER_FIND') ||
        questionType.contains('LETTER_FIND') ||
        // Admin note veya activity title'da "kelimede" geçiyorsa
        (adminNote.isNotEmpty && (adminNote.contains('KELIMEDE') || adminNote.contains('BULMA'))) ||
        (activityTitle.isNotEmpty && (activityTitle.contains('KELIMEDE') || activityTitle.contains('BULMA'))) ||
        // contentObject'te words array'i varsa
        hasWordsArray;
    
    AppLogger.debug('Is Writing Board: $isWritingBoard');
    AppLogger.debug('Is Letter Dotted: $isLetterDotted');
    AppLogger.debug('Is Letter Drawing: $isLetterDrawing');
    AppLogger.debug('Is Letter Writing: $isLetterWriting');
    AppLogger.debug('Is Letter Find: $isLetterFind');
    AppLogger.debug('Question Type: "$questionType"');
    AppLogger.debug('Question Format: "$questionFormat"');
    AppLogger.debug('Admin Note: "$adminNote"');
    AppLogger.debug('Activity Title: "$activityTitle"');
    AppLogger.debug('Has Words Array: $hasWordsArray');
    AppLogger.debug('ContentObject Type: ${contentObject.runtimeType}');
    
    if (isWritingBoard) {
      AppLogger.info('LetterWritingBoardScreen\'e yönlendiriliyor...');
      return LetterWritingBoardScreen(
        activity: widget.activity,
        questions: widget.questions,
        currentQuestionIndex: _currentIndex,
      );
    }
    
    if (isLetterDotted) {
      AppLogger.info('LetterDottedScreen\'e yönlendiriliyor...');
      return LetterDottedScreen(
        activity: widget.activity,
        questions: widget.questions,
        currentQuestionIndex: _currentIndex,
      );
    }
    
    if (isLetterDrawing) {
      AppLogger.info('LetterDrawingScreen\'e yönlendiriliyor...');
      return LetterDrawingScreen(
        activity: widget.activity,
        questions: widget.questions,
        currentQuestionIndex: _currentIndex,
      );
    }
    
    if (isLetterWriting) {
      AppLogger.info('LetterWritingScreen\'e yönlendiriliyor...');
      return LetterWritingScreen(
        activity: widget.activity,
        questions: widget.questions,
        currentQuestionIndex: _currentIndex,
      );
    }
    
    if (isLetterFind) {
      AppLogger.info('LetterFindScreen\'e yönlendiriliyor...');
      return LetterFindScreen(
        activity: widget.activity,
        questions: widget.questions,
        currentQuestionIndex: _currentIndex,
      );
    }
    
    AppLogger.warning('Normal soru ekranı gösteriliyor - QuestionType: $questionType, Format: $questionFormat');
    
    final questionText = questionTextForCheck;
    final instructionText = _getInstructionText(question);
    final imageFileId = question.mediaFileId;
    final audioFileId =
        question.data?['audioFileId'] ??
        question.mediaFileId; // Ses dosyası ID'si

    return Scaffold(
      body: Stack(
        children: [
          // Space Background
          Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
            colors: [
                  Color(0xFF0C0C0C),
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
            ],
          ),
        ),
            child: _buildSpaceBackground(),
          ),
          // Ana İçerik
          SafeArea(
          child: Column(
            children: [
              // Üst Header (Pembe-mor gradient)
              Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                    colors: [
                        Color(0xFFE91E63), // Pembe
                        Color(0xFF9C27B0), // Mor
                    ],
                  ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE91E63).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Icon(Icons.music_note, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.activity.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                    ),
                        child: Text(
                      'Puan: $_score/${widget.questions.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Soru Numarası
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Soru ${_currentIndex + 1}/${widget.questions.length}',
                  style: const TextStyle(
                      color: Color(0xFFFFC107),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // Ana İçerik
              Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Sol Taraf: Resim Kartı
                    Expanded(
                      flex: 3,
                        child: Column(
                          children: [
                            // Resim Kartı
                            Expanded(
                              child: Container(
                                  width: 300,
                                  height: 300,
                                  margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                      color: const Color(0xFF2196F3),
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2196F3)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 25,
                                        offset: const Offset(0, 8),
                                  ),
                                    ],
                                ),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                  child: imageFileId != null
                                      ? CachedNetworkImage(
                                          imageUrl: _getFileUrl(imageFileId),
                                          fit: BoxFit.contain,
                                            placeholder: (context, url) =>
                                                const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                              color: Color(0xFF4FC3F7),
                                            ),
                                          ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Center(
                                            child: Icon(
                                                        Icons
                                                            .image_not_supported,
                                              size: 64,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.image,
                                            size: 64,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            
                            // "Sesi Hisset" Butonu
                              if (audioFileId != null && _gameStarted)
                              Container(
                                width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                    colors: [
                                        Color(0xFF2196F3),
                                        Color(0xFF21CBF3),
                                    ],
                                  ),
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2196F3)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                      onTap: _isPlayingAudio
                                          ? null
                                          : () => _playAudio(audioFileId),
                                      borderRadius: BorderRadius.circular(25),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                            _isPlayingAudio
                                                ? Icons.pause
                                                : Icons.music_note,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                            _isPlayingAudio
                                                ? 'Çalıyor...'
                                                : '🎵 Sesi Hisset',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                      ),
                    ),
                    
                    // Sağ Taraf: Soru ve Butonlar
                    Expanded(
                      flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.grey[900]!.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Soru Metni
                            Container(
                                  padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                              ),
                              child: Text(
                                questionText,
                                style: const TextStyle(
                                  color: Colors.white,
                                      fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                    textAlign: TextAlign.center,
                              ),
                            ),
                            
                            const SizedBox(height: 24),

                                // Sonuç Mesajı
                                if (_hasAnswered)
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          _userAnswer == true &&
                                                  question.correctAnswer
                                                          ?.toLowerCase()
                                                          .contains('evet') ==
                                                      true ||
                                                  _userAnswer == false &&
                                                      question.correctAnswer
                                                              ?.toLowerCase()
                                                              .contains('hayır') ==
                                                          true
                                              ? 'Yaşasın! Doğru cevap!'
                                              : 'Tekrar dene!',
                                          style: TextStyle(
                                            color: _userAnswer == true &&
                                                    question.correctAnswer
                                                            ?.toLowerCase()
                                                            .contains('evet') ==
                                                        true ||
                                                    _userAnswer == false &&
                                                        question.correctAnswer
                                                                ?.toLowerCase()
                                                                .contains('hayır') ==
                                                            true
                                                ? const Color(0xFF4CAF50)
                                                : const Color(0xFFFF9800),
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          _userAnswer == true &&
                                                  question.correctAnswer
                                                          ?.toLowerCase()
                                                          .contains('evet') ==
                                                      true ||
                                                  _userAnswer == false &&
                                                      question.correctAnswer
                                                              ?.toLowerCase()
                                                              .contains('hayır') ==
                                                          true
                                              ? 'Harika! Çok iyi gidiyorsun!'
                                              : 'Sorun değil! Tekrar dene!',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.8),
                                            fontSize: 16,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                if (_hasAnswered) const SizedBox(height: 24),
                            
                            // Cevap Butonları
                            Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                              children: [
                                // Evet Butonu (Yeşil ✓)
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _hasAnswered || !_gameStarted || !_audioPlayed
                                            ? null
                                            : () => _checkAnswer(true),
                                        borderRadius: BorderRadius.circular(40),
                                        child: Opacity(
                                          opacity: _hasAnswered &&
                                                  _userAnswer != true
                                              ? 0.5
                                              : 1.0,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                              color: _hasAnswered &&
                                                      _userAnswer == true
                                                  ? (question.correctAnswer
                                                              ?.toLowerCase()
                                                              .contains('evet') ==
                                                          true
                                              ? Colors.green
                                              : Colors.red)
                                          : Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 40,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                                
                                // Hayır Butonu (Kırmızı ✗)
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _hasAnswered || !_gameStarted || !_audioPlayed
                                            ? null
                                            : () => _checkAnswer(false),
                                        borderRadius: BorderRadius.circular(40),
                                        child: Opacity(
                                          opacity: _hasAnswered &&
                                                  _userAnswer != false
                                              ? 0.5
                                              : 1.0,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                              color: _hasAnswered &&
                                                      _userAnswer == false
                                                  ? (question.correctAnswer
                                                              ?.toLowerCase()
                                                              .contains('hayır') ==
                                                          true
                                              ? Colors.green
                                              : Colors.red)
                                          : Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 40,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Açıklama Metni
                            Container(
                                  padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                    color: const Color(0xFF2196F3)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: const Color(0xFF2196F3)
                                          .withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                              ),
                              child: Text(
                                instructionText,
                                    style: const TextStyle(
                                      color: Color(0xFF87CEEB),
                                  fontSize: 14,
                                ),
                                    textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                    ),
                ),
              ),
            ],
          ),
        ),
          
          // Overlay Screen (Başlangıç)
          if (_showOverlay)
            GestureDetector(
              onTap: _startGame,
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '🎵 B Harfi Sesi Hissetme',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'B harfi sesi hissetme için tıklayın',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Star Field Painter
class StarFieldPainter extends CustomPainter {
  final double opacity;

  StarFieldPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3 + (opacity * 0.7))
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    for (int i = 0; i < 100; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height);
      final radius = 1 + (random.nextDouble() * 2);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(StarFieldPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}
