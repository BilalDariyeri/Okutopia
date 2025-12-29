import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/mini_question_model.dart';
import '../models/activity_model.dart';
import '../config/api_config.dart';
import '../services/activity_tracker_service.dart';
import '../services/current_session_service.dart';
import '../providers/auth_provider.dart';
import '../utils/app_logger.dart';

class LetterFindScreen extends StatefulWidget {
  final Activity activity;
  final List<MiniQuestion> questions;
  final int currentQuestionIndex;

  const LetterFindScreen({
    super.key,
    required this.activity,
    required this.questions,
    this.currentQuestionIndex = 0,
  });

  @override
  State<LetterFindScreen> createState() => _LetterFindScreenState();
}

class _LetterFindScreenState extends State<LetterFindScreen>
    with TickerProviderStateMixin {
  int _currentWordIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  StreamSubscription? _playerCompleteSubscription;
  Set<int> _selectedLetters = <int>{};
  bool _showCompletion = false;
  bool _showStartScreen = true;
  final List<AnimationController> _confettiControllers = [];
  bool _hasAnswered = false;
  int _score = 0;
  final ActivityTrackerService _activityTracker = ActivityTrackerService();
  final CurrentSessionService _sessionService = CurrentSessionService();
  DateTime? _activityStartTime;
  String? _studentId; // dispose() içinde context kullanmamak için saklanıyor

  @override
  void initState() {
    super.initState();
    _currentWordIndex = widget.currentQuestionIndex;
    _selectedLetters = <int>{};
    _hasAnswered = false;
    _score = 0;
    
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });
    _startActivityTracking();
    
    // İlk kelime gösterilirken ikinci kelimenin resmini önceden yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadNextWordImage(_currentWordIndex);
    });
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    for (var controller in _confettiControllers) {
      controller.dispose();
    }
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
        successStatus: successStatus ?? (_hasAnswered && _score > 0 ? 'Başarılı' : 'Tamamlandı'),
      );
      
      // Oturum servisine de ekle (TAMAMLANMIŞ olarak işaretle)
      _sessionService.addActivity(
        studentId: studentId,
        activityId: widget.activity.id,
        activityTitle: widget.activity.title,
        durationSeconds: duration,
        successStatus: successStatus ?? (_hasAnswered && _score > 0 ? 'Başarılı' : 'Tamamlandı'),
        isCompleted: true, // Aktivite başarıyla tamamlandı
        correctAnswerCount: _score, // Doğru cevap sayısı
      );
    }
  }

  List<Map<String, dynamic>> _getWords() {
    final question = widget.questions[widget.currentQuestionIndex];
    AppLogger.debug('LetterFindScreen - Question ID: ${question.id}');
    AppLogger.debug('Question Type: ${question.questionType}');
    AppLogger.debug('Question Format: ${question.questionFormat}');
    AppLogger.debug('Question Data: ${question.data}');
    
    final contentObject = question.data?['contentObject'];
    AppLogger.debug('Content Object: $contentObject');
    
    if (contentObject != null) {
      if (contentObject is Map) {
        if (contentObject['words'] != null) {
          final words = contentObject['words'];
          AppLogger.debug('Words found: ${words is List ? words.length : 'not a list'}');
          if (words is List) {
            return words.map((w) => Map<String, dynamic>.from(w)).toList();
          }
        }
      }
    }
    
    AppLogger.warning('No words found, returning empty list');
    return [];
  }

  String _getTargetLetter() {
    final question = widget.questions[widget.currentQuestionIndex];
    return question.correctAnswer?.toLowerCase().trim() ?? 
           question.data?['contentObject']?['targetLetter']?.toLowerCase().trim() ?? 
           'a';
  }

  String _getFileUrl(String? fileId) {
    if (fileId == null) return '';
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    return '$baseUrl/api/files/$fileId';
  }

  Future<void> _playAudio(String? fileId) async {
    if (fileId == null) return;
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
      await _audioPlayer.stop();
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

  void _selectLetter(int letterIndex, String letter) {
    final words = _getWords();
    if (_currentWordIndex >= words.length) return;
    
    final targetLetter = _getTargetLetter();
    if (letter.toLowerCase() == targetLetter.toLowerCase()) {
      setState(() {
        _selectedLetters.add(letterIndex);
      });
      _createSmallConfetti(letterIndex);
      _updateButtonState();
    }
  }

  void _createSmallConfetti(int letterIndex) {
    // Konfeti animasyonu için controller oluştur
    final controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _confettiControllers.add(controller);
    controller.forward().then((_) {
      if (mounted && _confettiControllers.contains(controller)) {
        controller.dispose();
        _confettiControllers.remove(controller);
      }
    });
  }

  bool _areAllTargetLettersSelected() {
    final words = _getWords();
    if (_currentWordIndex >= words.length) return false;
    
    final word = words[_currentWordIndex];
    final letters = List<String>.from(word['letters'] ?? []);
    final targetLetter = _getTargetLetter();
    
    int targetCount = 0;
    int selectedCount = 0;
    
    for (int i = 0; i < letters.length; i++) {
      if (letters[i].toLowerCase() == targetLetter.toLowerCase()) {
        targetCount++;
        if (_selectedLetters.contains(i)) {
          selectedCount++;
        }
      }
    }
    
    return targetCount > 0 && targetCount == selectedCount;
  }

  void _updateButtonState() {
    setState(() {
      // Buton durumu güncellenir
    });
    
    // Tüm hedef harfler seçildiyse, bir sonraki kelimenin resmini önceden yükle
    if (_areAllTargetLettersSelected()) {
      _preloadNextWordImage(_currentWordIndex);
    }
  }

  void _changeItem(int direction) {
    final words = _getWords();
    final newIndex = _currentWordIndex + direction;
    
    if (newIndex >= 0 && newIndex < words.length) {
      setState(() {
        _currentWordIndex = newIndex;
        _selectedLetters = <int>{}; // Yeni kelime için seçimleri sıfırla
        _hasAnswered = false;
      });
      
      // Bir sonraki kelimenin resmini önceden yükle (kullanıcı beklemez)
      _preloadNextWordImage(_currentWordIndex);
    } else if (direction == 1 && newIndex >= words.length) {
      // Tüm kelimeler tamamlandı
      _showCompletionMessage();
    }
  }
  
  /// Bir sonraki kelimenin resmini önceden yükle (preload)
  void _preloadNextWordImage(int currentWordIndex) {
    if (!mounted) return;
    
    final words = _getWords();
    final nextWordIndex = currentWordIndex + 1;
    
    // Bir sonraki kelime var mı kontrol et
    if (nextWordIndex >= words.length) return;
    
    final nextWord = words[nextWordIndex];
    
    // Bir sonraki kelimenin resmini al
    String? imageFileId = nextWord['image'];
    if (imageFileId == null) {
      final question = widget.questions[widget.currentQuestionIndex];
      imageFileId = question.mediaFileId;
    }
    
    if (imageFileId != null && imageFileId.isNotEmpty) {
      final imageUrl = _getFileUrl(imageFileId);
      
      if (imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
        // Resmi arka planda önceden yükle (kullanıcı beklemez)
        Future.delayed(const Duration(milliseconds: 300), () async {
          if (!mounted) return;
          
          try {
            final imageProvider = CachedNetworkImageProvider(
              imageUrl,
              maxWidth: 400, // Görüntü kodlama hatası için maxWidth ekle
              maxHeight: 400,
            );
            await precacheImage(
              imageProvider,
              context,
            ).timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                // Timeout durumunda sessizce devam et
                debugPrint('⚠️ Image preload timeout: $imageUrl');
              },
            );
          } catch (e) {
            // Görüntü kodlama hatası dahil tüm hataları yakala
            debugPrint('⚠️ Image preload error: $imageUrl - $e');
          }
        });
      }
    }
  }

  void _showCompletionMessage() {
    setState(() {
      _showCompletion = true;
    });
    _createConfetti();
  }

  void _createConfetti() {
    // Konfeti animasyonu için çoklu controller'lar
    for (int i = 0; i < 40; i++) {
      Future.delayed(Duration(milliseconds: i * 120), () {
        if (mounted) {
          final controller = AnimationController(
            duration: const Duration(seconds: 4),
            vsync: this,
          );
          _confettiControllers.add(controller);
          controller.forward().then((_) {
            if (mounted && _confettiControllers.contains(controller)) {
              controller.dispose();
              _confettiControllers.remove(controller);
            }
          });
        }
      });
    }
  }

  void _restartActivity() {
    setState(() {
      _currentWordIndex = 0;
      _selectedLetters = <int>{};
      _showCompletion = false;
      _hasAnswered = false;
      _score = 0;
    });
  }

  /// Etkinlik tamamlandığında mail gönder
  /// Etkinlik tamamlandığında dialog'u kapat (aktivite zaten oturum servisine kaydedildi)
  void _onCompleted() {
    // Aktivite zaten oturum servisine kaydedildi (_showCompletionMessage çağrılmadan önce)
    // Sadece dialog'u kapat ve geri git
    Navigator.of(context).pop();
  }

  void _startGame() {
    final question = widget.questions[widget.currentQuestionIndex];
    final audioFileId = question.data?['audioFileId'];
    
    if (audioFileId != null) {
      _playAudio(audioFileId);
    }
    
    setState(() {
      _showStartScreen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Başlangıç ekranı
    if (_showStartScreen) {
      return Scaffold(
        body: GestureDetector(
          onTap: _startGame,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF667EEA),
                  Color(0xFF764BA2),
                ],
              ),
            ),
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Text(
                  '${_getTargetLetter().toUpperCase()} Harfi Kelimede Bulma',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black87,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Tamamlama ekranı
    if (_showCompletion) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF667EEA),
                Color(0xFF764BA2),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '🎉 Tebrikler! 🎉',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B6B),
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 4,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Etkinliği bitirdin',
                    style: TextStyle(
                      fontSize: 24,
                      color: Color(0xFFFF6B6B),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tamamlandı Butonu (Sadece kaydet, mail gönderme)
                      ElevatedButton(
                        onPressed: _onCompleted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Tamamlandı',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Tekrar Başla Butonu
                      ElevatedButton(
                        onPressed: _restartActivity,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B6B),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Tekrar Başla',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final words = _getWords();
    AppLogger.debug('Current word index: $_currentWordIndex, Total words: ${words.length}');
    
    if (words.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF667EEA),
                Color(0xFF764BA2),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Kelimeler yüklenemedi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Soru verisi eksik veya hatalı.\nLütfen admin panelinden kontrol edin.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    if (_currentWordIndex >= words.length) {
      return Scaffold(
        body: Center(
          child: Text(
            'Tüm kelimeler tamamlandı!',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    final word = words[_currentWordIndex];
    final letters = List<String>.from(word['letters'] ?? []);
    // Resim dosyası ID'sini al - önce word'dan, sonra question'dan
    String? imageFileId = word['image'];
    if (imageFileId == null) {
      final question = widget.questions[widget.currentQuestionIndex];
      imageFileId = question.mediaFileId;
    }
    final targetLetter = _getTargetLetter();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 600),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Resim Bölümü - Üstte
                    Center(
                      child: Container(
                        width: 200,
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: imageFileId != null
                              ? CachedNetworkImage(
                                  imageUrl: _getFileUrl(imageFileId),
                                  fit: BoxFit.contain,
                                  maxWidthDiskCache: 400, // Görüntü kodlama hatası için ekle
                                  maxHeightDiskCache: 400,
                                  memCacheWidth: 400,
                                  memCacheHeight: 400,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) {
                                    // Görüntü kodlama hatasını yakala
                                    debugPrint('❌ Image error: $url - $error');
                                    return const Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
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
                    
                    const SizedBox(height: 30),
                    
                    // Kelime Bölümü - Harfler tıklanabilir
                    Center(
                      child: Text.rich(
                        TextSpan(
                          children: List.generate(letters.length, (index) {
                            final letter = letters[index];
                            final isSelected = _selectedLetters.contains(index);
                            final isTarget = letter.toLowerCase() == targetLetter.toLowerCase();
                            
                            return WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: () => _selectLetter(index, letter),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  padding: EdgeInsets.zero,
                                  margin: EdgeInsets.zero,
                                  transform: Matrix4.identity()..scale(isSelected && isTarget ? 1.1 : 1.0),
                                  decoration: BoxDecoration(
                                    color: isSelected && isTarget
                                        ? const Color(0xFFFFE6E6)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    letter,
                                    style: TextStyle(
                                      fontSize: 80,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0,
                                      color: isSelected && isTarget
                                          ? Colors.red
                                          : const Color(0xFF333333),
                                      shadows: isSelected && isTarget
                                          ? [
                                              Shadow(
                                                color: Colors.red.withValues(alpha: 0.3),
                                                blurRadius: 15,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Talimat metni - Kelimenin hemen altında
                    Text(
                      '"$targetLetter" harfine dokunun',
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Navigasyon butonları
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _currentWordIndex > 0 ? () => _changeItem(-1) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667EEA),
                            disabledBackgroundColor: const Color(0xFFCCCCCC),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '← Önceki',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: _areAllTargetLettersSelected()
                              ? () => _changeItem(1)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _areAllTargetLettersSelected()
                                ? const Color(0xFF667EEA)
                                : const Color(0xFFCCCCCC),
                            disabledBackgroundColor: const Color(0xFFCCCCCC),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Sonraki →',
                            style: TextStyle(
                              fontSize: 18,
                              color: _areAllTargetLettersSelected()
                                  ? Colors.white
                                  : const Color(0xFF666666),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Sayaç
                    Text(
                      '${_currentWordIndex + 1} / ${words.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF999999),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
