import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/mini_question_model.dart';
import '../models/activity_model.dart';
import '../config/api_config.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentQuestionIndex;
    
    // Ses çalma tamamlandığında dinle
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _getFileUrl(String? fileId) {
    if (fileId == null) return '';
    // API base URL'den /api kısmını kaldırıp dosya URL'i oluştur
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    return '$baseUrl/api/files/$fileId';
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

  void _handleAnswer(bool answer) {
    if (_hasAnswered) return;

    setState(() {
      _hasAnswered = true;
      _userAnswer = answer;
      
      final question = widget.questions[_currentIndex];
      final correctAnswer = question.correctAnswer?.toLowerCase().trim();
      
      // Cevap kontrolü (Evet/Hayır veya true/false)
      bool isCorrect = false;
      if (correctAnswer != null) {
        if (answer && (correctAnswer == 'evet' || correctAnswer == 'yes' || correctAnswer == 'true' || correctAnswer == '✓')) {
          isCorrect = true;
        } else if (!answer && (correctAnswer == 'hayır' || correctAnswer == 'no' || correctAnswer == 'false' || correctAnswer == '✗' || correctAnswer == 'x')) {
          isCorrect = true;
        }
      }
      
      if (isCorrect) {
        _score++;
      }
    });

    // 2 saniye sonra bir sonraki soruya geç
    Timer(const Duration(seconds: 2), () {
      if (_currentIndex < widget.questions.length - 1) {
        setState(() {
          _currentIndex++;
          _hasAnswered = false;
          _userAnswer = null;
        });
      } else {
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
        content: Text('Tüm soruları tamamladınız!\nPuanınız: $_score/${widget.questions.length}'),
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
      final questionText = question.data!['questionText'] ?? 
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
      final instruction = question.data!['instruction'] ?? 
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
    final questionText = _getQuestionText(question);
    final instructionText = _getInstructionText(question);
    final imageFileId = question.mediaFileId;
    final audioFileId = question.data?['audioFileId'] ?? question.mediaFileId; // Ses dosyası ID'si

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                          placeholder: (context, url) => const Center(
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF4FC3F7),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => const Center(
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
                                padding: const EdgeInsets.symmetric(vertical: 16),
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
                                    onTap: _isPlayingAudio ? null : () => _playAudio(audioFileId),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isPlayingAudio ? Icons.pause : Icons.music_note,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isPlayingAudio ? 'Çalıyor...' : 'Sesi Hisset',
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
                                GestureDetector(
                                  onTap: _hasAnswered ? null : () => _handleAnswer(true),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: _hasAnswered && _userAnswer == true
                                          ? (_userAnswer == true && question.correctAnswer?.toLowerCase().contains('evet') == true
                                              ? Colors.green
                                              : Colors.red)
                                          : Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                                
                                // Hayır Butonu (Kırmızı ✗)
                                GestureDetector(
                                  onTap: _hasAnswered ? null : () => _handleAnswer(false),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: _hasAnswered && _userAnswer == false
                                          ? (_userAnswer == false && question.correctAnswer?.toLowerCase().contains('hayır') == true
                                              ? Colors.green
                                              : Colors.red)
                                          : Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 40,
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

