import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
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

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  int _currentIndex = 0;
  int _score = 0;
  bool _hasAnswered = false;
  bool? _userAnswer; // true = evet, false = hayır
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  StreamSubscription? _playerCompleteSubscription;
  final ActivityTrackerService _activityTracker = ActivityTrackerService();
  final CurrentSessionService _sessionService = CurrentSessionService();
  DateTime? _activityStartTime;
  String? _studentId; // dispose() içinde context kullanmamak için saklanıyor

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentQuestionIndex;
    _startActivityTracking();

    // Ses çalma tamamlandığında dinle
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });

    // Tüm soruların resimlerini önceden yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadAllQuestionImages();
    });
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _endActivityTracking();
    super.dispose();
  }

  Future<void> _startActivityTracking() async {
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
        successStatus: successStatus,
      );
      
      // Oturum servisine de ekle
      _sessionService.addActivity(
        studentId: studentId,
        activityId: widget.activity.id,
        activityTitle: widget.activity.title,
        durationSeconds: duration,
        successStatus: successStatus,
      );
    }
  }

  String _getFileUrl(String? fileId) {
    if (fileId == null) return '';
    // API base URL'den /api kısmını kaldırıp dosya URL'i oluştur
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    return '$baseUrl/api/files/$fileId';
  }

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
    if (fileId == null) return;

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

  void _selectAnswer(bool answer) {
    if (_hasAnswered) return;

    setState(() {
      _userAnswer = answer;
    });
    
    // Direkt kaydet
    _saveAnswer();
  }

  void _saveAnswer() {
    if (_hasAnswered || _userAnswer == null) return;

    setState(() {
      _hasAnswered = true;

      final question = widget.questions[_currentIndex];
      final correctAnswer = question.correctAnswer?.toLowerCase().trim();

      // Cevap kontrolü (Evet/Hayır veya true/false)
      bool isCorrect = false;
      if (correctAnswer != null) {
        if (_userAnswer == true &&
            (correctAnswer == 'evet' ||
                correctAnswer == 'yes' ||
                correctAnswer == 'true' ||
                correctAnswer == '✓')) {
          isCorrect = true;
        } else if (_userAnswer == false &&
            (correctAnswer == 'hayır' ||
                correctAnswer == 'no' ||
                correctAnswer == 'false' ||
                correctAnswer == '✗' ||
                correctAnswer == 'x')) {
          isCorrect = true;
        }
      }

      if (isCorrect) {
        _score++;
      }
    });

    // 2 saniye sonra bir sonraki soruya geç
    Timer(const Duration(seconds: 2), () {
      if (mounted && _currentIndex < widget.questions.length - 1) {
        setState(() {
          _currentIndex++;
          _hasAnswered = false;
          _userAnswer = null;
        });
        
        // Bir sonraki sorunun resmini preload et
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preloadNextQuestionImage();
        });
      } else if (mounted) {
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
      builder: (context) => AlertDialog(
        title: const Text('Tebrikler!'),
        content: Text(
          'Tüm soruları tamamladınız!\nPuanınız: $_score/${widget.questions.length}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dialog'u kapat
              Navigator.of(context).pop(); // Soru ekranından çık
            },
            child: const Text('Tamam'),
          ),
        ],
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
      body: Container(
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
        child: SafeArea(
          child: Column(
            children: [
              // Üst Header (Pembe-mor gradient)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE91E63), // Pembe
                      const Color(0xFF9C27B0), // Mor
                    ],
                  ),
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
                      ),
                    ),
                    Text(
                      'Puan: $_score/${widget.questions.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Soru Numarası
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Soru ${_currentIndex + 1}/${widget.questions.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Ana İçerik
              Expanded(
                child: Row(
                  children: [
                    // Sol Taraf: Resim Kartı
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Resim Kartı
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF4FC3F7),
                                    width: 3,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
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
                                          errorWidget: (context, url, error) =>
                                              const Center(
                                                child: Icon(
                                                  Icons.image_not_supported,
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
                            const SizedBox(height: 16),

                            // "Sesi Hisset" Butonu
                            if (audioFileId != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF4FC3F7),
                                      const Color(0xFF29B6F6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isPlayingAudio
                                        ? null
                                        : () => _playAudio(audioFileId),
                                    borderRadius: BorderRadius.circular(12),
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
                                              : 'Sesi Hisset',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
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
                    ),

                    // Sağ Taraf: Soru ve Butonlar
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Soru Metni
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                questionText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Cevap Butonları
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Evet Butonu (Yeşil ✓)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _hasAnswered
                                        ? null
                                        : () => _selectAnswer(true),
                                    borderRadius: BorderRadius.circular(40),
                                    child: Opacity(
                                      opacity:
                                          _hasAnswered && _userAnswer != true
                                          ? 0.5
                                          : 1.0,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color:
                                              _hasAnswered &&
                                                  _userAnswer == true
                                              ? (_userAnswer == true &&
                                                        question.correctAnswer
                                                                ?.toLowerCase()
                                                                .contains(
                                                                  'evet',
                                                                ) ==
                                                            true
                                                    ? Colors.green
                                                    : Colors.red)
                                              : (_userAnswer == true
                                                    ? Colors.green.shade700
                                                    : Colors.green),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _userAnswer == true
                                                ? Colors.yellow
                                                : Colors.white,
                                            width: _userAnswer == true ? 4 : 3,
                                          ),
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
                                    onTap: _hasAnswered
                                        ? null
                                        : () => _selectAnswer(false),
                                    borderRadius: BorderRadius.circular(40),
                                    child: Opacity(
                                      opacity:
                                          _hasAnswered && _userAnswer != false
                                          ? 0.5
                                          : 1.0,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color:
                                              _hasAnswered &&
                                                  _userAnswer == false
                                              ? (_userAnswer == false &&
                                                        question.correctAnswer
                                                                ?.toLowerCase()
                                                                .contains(
                                                                  'hayır',
                                                                ) ==
                                                            true
                                                    ? Colors.green
                                                    : Colors.red)
                                              : (_userAnswer == false
                                                    ? Colors.red.shade700
                                                    : Colors.red),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _userAnswer == false
                                                ? Colors.yellow
                                                : Colors.white,
                                            width: _userAnswer == false ? 4 : 3,
                                          ),
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
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                instructionText,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
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
            ],
          ),
        ),
      ),
    );
  }
}
