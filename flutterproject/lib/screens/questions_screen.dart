import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/content_service.dart';
import '../services/current_session_service.dart';
import '../providers/auth_provider.dart';
import '../models/mini_question_model.dart';
import '../models/activity_model.dart';
import 'question_detail_screen.dart';
import '../widgets/activity_timer.dart';
import 'letter_find_screen.dart';
import 'letter_writing_screen.dart';
import 'letter_c_writing_screen.dart';
import 'letter_drawing_screen.dart';
import 'letter_c_drawing_screen.dart';
import 'letter_dotted_screen.dart';
import 'letter_c_dotted_screen.dart';
import 'letter_writing_board_screen.dart';

class QuestionsScreen extends StatefulWidget {
  final Activity activity;

  const QuestionsScreen({super.key, required this.activity});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  final ContentService _contentService = ContentService();
  final CurrentSessionService _sessionService = CurrentSessionService();
  final ScrollController _scrollController = ScrollController();
  List<MiniQuestion> _questions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<MiniQuestion> allQuestions = [];

      // Önce activity bazlı soruları getir
      try {
        final activityResponse = await _contentService.getQuestionsForActivity(
          activityId: widget.activity.id,
        );
        if (activityResponse.questions.isNotEmpty) {
          allQuestions.addAll(activityResponse.questions);
        }
      } catch (e) {
        // Activity bazlı sorular yoksa devam et (404 normal bir durum)
        final errorStr = e.toString();
        if (!errorStr.contains('404') && !errorStr.contains('bulunamadı')) {
         
        }
      }

      // Sonra lesson bazlı soruları getir
      try {
        final lessonResponse = await _contentService.getQuestionsForLesson(
          lessonId: widget.activity.lessonId,
        );
        if (lessonResponse.questions.isNotEmpty) {
          allQuestions.addAll(lessonResponse.questions);
        }
      } catch (e) {
        // Lesson bazlı sorular yoksa devam et (404 normal bir durum)
        final errorStr = e.toString();
        if (!errorStr.contains('404') && !errorStr.contains('bulunamadı')) {
      
        }
      }

      if (!mounted) return;

      setState(() {
        _questions = allQuestions;
        _isLoading = false;
        if (allQuestions.isEmpty) {
          _errorMessage = 'Bu etkinlik veya ders için henüz soru eklenmemiş.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg.contains('500') || errorMsg.contains('Sunucu hatası')) {
          errorMsg = 'Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyin.';
        } else if (errorMsg.contains('401') || errorMsg.contains('Token')) {
          errorMsg = 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.';
        } else if (errorMsg.contains('403')) {
          errorMsg = 'Bu işlem için yetkiniz bulunmamaktadır.';
        } else if (errorMsg.contains('404')) {
          errorMsg = 'Sorular bulunamadı.';
        }
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  bool _isWritingBoardQuestion(MiniQuestion question) {
    final questionType = (question.questionType ?? '').toString().toUpperCase();
    final questionFormat = (question.questionFormat ?? '').toString().toUpperCase();
    final adminNote = (question.data?['adminNote'] ?? '').toString().toUpperCase();
    final activityTitle = (widget.activity.title ?? '').toString().toUpperCase();
    final questionText = (question.data?['questionText'] ?? '').toString().toUpperCase();
    
    return questionFormat == 'YAZI_TAHTASI' ||
        questionType == 'YAZI_TAHTASI' ||
        questionFormat.contains('YAZI_TAHTASI') ||
        questionType.contains('YAZI_TAHTASI') ||
        questionFormat.contains('WRITING_BOARD') ||
        questionType.contains('WRITING_BOARD') ||
        questionText.contains('YAZI TAHTASI') ||
        questionText.contains('YAZI TAHTA') ||
        adminNote.contains('YAZI TAHTASI') ||
        adminNote.contains('YAZI TAHTA') ||
        activityTitle.contains('YAZI TAHTASI') ||
        activityTitle.contains('YAZI TAHTA');
  }

  bool _isLetterCDottedQuestion(MiniQuestion question) {
    final questionText = question.data?['questionText'] ?? question.data?['text'] ?? '';
    final questionTextUpper = questionText.toString().toUpperCase();
    final activityTitle = (widget.activity.title ?? '').toString().toUpperCase();
    
    // "C harfi noktalı çizim" sorusunu tespit et
    return questionTextUpper.contains('C HARFİ NOKTALI ÇİZİM') ||
           questionTextUpper.contains('C HARFI NOKTALI ÇİZİM') ||
           questionTextUpper.contains('C HARFİ NOKTALI ÇİZ') ||
           questionTextUpper.contains('C HARFI NOKTALI ÇİZ') ||
           questionTextUpper.contains('C HARFİ NOKTALI') ||
           questionTextUpper.contains('C HARFI NOKTALI') ||
           questionTextUpper.contains('C NOKTALI ÇİZİM') ||
           questionTextUpper.contains('C NOKTALI ÇIZIM') ||
           (activityTitle.contains('C') && questionTextUpper.contains('NOKTALI ÇİZİM')) ||
           (activityTitle.contains('C') && questionTextUpper.contains('NOKTALI ÇIZIM')) ||
           (activityTitle.contains('C C') && questionTextUpper.contains('NOKTALI'));
  }

  bool _isLetterDottedQuestion(MiniQuestion question) {
    // Önce C harfi noktalı çizim kontrolü yap
    if (_isLetterCDottedQuestion(question)) {
      return false;
    }
    
    final questionType = (question.questionType ?? '').toString().toUpperCase();
    final questionFormat = (question.questionFormat ?? '').toString().toUpperCase();
    final adminNote = (question.data?['adminNote'] ?? '').toString().toUpperCase();
    final activityTitle = (widget.activity.title ?? '').toString().toUpperCase();
    final questionText = (question.data?['questionText'] ?? '').toString().toUpperCase();
    
    return questionFormat == 'NOKTALI_YAZIM' ||
        questionType == 'NOKTALI_YAZIM' ||
        questionFormat.contains('NOKTALI_YAZIM') ||
        questionType.contains('NOKTALI_YAZIM') ||
        questionFormat.contains('DOTTED') ||
        questionType.contains('DOTTED') ||
        questionText.contains('NOKTALI YAZIM') ||
        questionText.contains('NOKTALI YAZ') ||
        questionText.contains('NOKTALI') ||
        adminNote.contains('NOKTALI YAZIM') ||
        adminNote.contains('NOKTALI YAZ') ||
        adminNote.contains('NOKTALI') ||
        activityTitle.contains('NOKTALI YAZIM') ||
        activityTitle.contains('NOKTALI YAZ') ||
        activityTitle.contains('NOKTALI');
  }

  bool _isLetterDrawingQuestion(MiniQuestion question) {
    // Önce C harfi serbest çizim kontrolü yapılıyor mu kontrol et
    // Eğer C harfi serbest çizim ise, bu fonksiyon false döndürmeli
    if (_isLetterCDrawingQuestion(question)) {
      return false;
    }
    
    final questionType = (question.questionType ?? '').toString().toUpperCase();
    final questionFormat = (question.questionFormat ?? '').toString().toUpperCase();
    final adminNote = (question.data?['adminNote'] ?? '').toString().toUpperCase();
    final activityTitle = (widget.activity.title ?? '').toString().toUpperCase();
    
    // Soru metnini al
    final questionText = question.data?['questionText'] ?? question.data?['text'] ?? '';
    final questionTextUpper = questionText.toString().toUpperCase();
    
    return questionFormat == 'SERBEST_CIZIM' ||
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
  }

  bool _isLetterCDrawingQuestion(MiniQuestion question) {
    final questionText = question.data?['questionText'] ?? question.data?['text'] ?? '';
    final questionTextUpper = questionText.toString().toUpperCase();
    final activityTitle = (widget.activity.title ?? '').toString().toUpperCase();
    
    // Debug: Soru metnini yazdır
    print('🔍 C Harfi Serbest Çizim Kontrolü:');
    print('   Soru Metni: $questionText');
    print('   Aktivite Başlığı: ${widget.activity.title}');
    
    // "C harfi serbest çizim" sorusunu tespit et
    // Hem soru metninde hem de aktivite başlığında kontrol et
    final isCDrawing = questionTextUpper.contains('C HARFİ SERBEST ÇİZİM') ||
           questionTextUpper.contains('C HARFI SERBEST ÇİZİM') ||
           questionTextUpper.contains('C HARFİ SERBEST ÇİZ') ||
           questionTextUpper.contains('C HARFI SERBEST ÇİZ') ||
           questionTextUpper.contains('C HARFİ SERBEST') ||
           questionTextUpper.contains('C HARFI SERBEST') ||
           questionTextUpper.contains('C SERBEST ÇİZİM') ||
           questionTextUpper.contains('C SERBEST ÇIZIM') ||
           (activityTitle.contains('C') && questionTextUpper.contains('SERBEST ÇİZİM')) ||
           (activityTitle.contains('C') && questionTextUpper.contains('SERBEST ÇIZIM')) ||
           (activityTitle.contains('C C') && questionTextUpper.contains('SERBEST'));
    
    print('   Sonuç: $isCDrawing');
    
    return isCDrawing;
  }

  bool _isLetterWritingQuestion(MiniQuestion question) {
    final questionType = (question.questionType ?? '').toString().toUpperCase();
    final questionFormat = (question.questionFormat ?? '').toString().toUpperCase();
    final adminNote = (question.data?['adminNote'] ?? '').toString().toUpperCase();
    final activityTitle = (widget.activity.title ?? '').toString().toUpperCase();
    
    // Soru metnini al
    final questionText = question.data?['questionText'] ?? question.data?['text'] ?? '';
    final questionTextUpper = questionText.toString().toUpperCase();
    
    return questionFormat == 'HARF_YAZIMI' ||
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
        activityTitle.contains('YAZIM') ||
        activityTitle.contains('YAZILIR') ||
        activityTitle.contains('HARF YAZIMI') ||
        activityTitle.contains('HARF_YAZIMI') ||
        (activityTitle.contains('HARF') && (activityTitle.contains('YAZIM') || activityTitle.contains('YAZILIR') || activityTitle.contains('YAZ')));
  }

  bool _isLetterCWritingQuestion(MiniQuestion question) {
    final questionText = question.data?['questionText'] ?? question.data?['text'] ?? '';
    final questionTextUpper = questionText.toString().toUpperCase();
    
    // "C harfi nasıl yazılır" sorusunu tespit et
    return questionTextUpper.contains('C HARFİ NASIL YAZILIR') ||
           questionTextUpper.contains('C HARFI NASIL YAZILIR') ||
           questionTextUpper.contains('C HARFİ NASIL YAZ') ||
           questionTextUpper.contains('C HARFI NASIL YAZ');
  }

  bool _isLetterFindQuestion(MiniQuestion question) {
    final questionType = (question.questionType ?? '').toString().toUpperCase();
    final questionFormat = (question.questionFormat ?? '').toString().toUpperCase();
    final adminNote = (question.data?['adminNote'] ?? '').toString().toUpperCase();
    final activityTitle = (widget.activity.title ?? '').toString().toUpperCase();
    
    // contentObject'te words array'i var mı kontrol et
    final contentObject = question.data?['contentObject'];
    final hasWordsArray = contentObject != null && 
        contentObject is Map && 
        contentObject['words'] != null &&
        contentObject['words'] is List &&
        (contentObject['words'] as List).isNotEmpty;
    
    return questionFormat == 'KELIMEDE_HARF_BULMA' ||
        questionType == 'KELIMEDE_HARF_BULMA' || 
        questionFormat.contains('KELIMEDE_HARF_BULMA') || 
        questionType.contains('KELIMEDE_HARF_BULMA') ||
        (adminNote.isNotEmpty && (adminNote.contains('KELIMEDE') || adminNote.contains('BULMA'))) ||
        (activityTitle.isNotEmpty && (activityTitle.contains('KELIMEDE') || activityTitle.contains('BULMA'))) ||
        hasWordsArray;
  }

  String _getQuestionTitle(MiniQuestion question) {
    // Kelimede Harf Bulma soruları için özel format
    if (_isLetterFindQuestion(question)) {
      // Correct answer varsa onu kullan
      if (question.correctAnswer != null && question.correctAnswer!.isNotEmpty) {
        return '${question.correctAnswer!.toUpperCase()} Harfi Kelimede Bul';
      }
      
      // contentObject'te targetLetter varsa onu kullan
      final contentObject = question.data?['contentObject'];
      if (contentObject != null && contentObject is Map) {
        final targetLetter = contentObject['targetLetter'];
        if (targetLetter != null && targetLetter.toString().isNotEmpty) {
          return '${targetLetter.toString().toUpperCase()} Harfi Kelimede Bul';
        }
      }
    }
    
    // Admin note varsa onu kullan
    if (question.data?['adminNote'] != null && question.data!['adminNote'].toString().isNotEmpty) {
      return question.data!['adminNote'].toString();
    }
    
    // Question text varsa onu kullan
    if (question.data?['questionText'] != null && question.data!['questionText'].toString().isNotEmpty) {
      return question.data!['questionText'].toString();
    }
    
    // Varsayılan
    return 'Soru ${question.id.length > 8 ? question.id.substring(0, 8) : question.id}';
  }

  Widget _buildQuestionsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final question = _questions[index];
        final isWritingBoard = _isWritingBoardQuestion(question);
        final isLetterCDotted = _isLetterCDottedQuestion(question);
        final isLetterDotted = _isLetterDottedQuestion(question);
        final isLetterDrawing = _isLetterDrawingQuestion(question);
        final isLetterCDrawing = _isLetterCDrawingQuestion(question);
        final isLetterWriting = _isLetterWritingQuestion(question);
        final isLetterCWriting = _isLetterCWritingQuestion(question);
        final isLetterFind = _isLetterFindQuestion(question);
        final questionTitle = _getQuestionTitle(question);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            leading: Icon(
              isWritingBoard
                  ? Icons.dashboard
                  : (isLetterDotted
                      ? Icons.pattern
                      : (isLetterDrawing 
                          ? Icons.edit 
                          : (isLetterWriting 
                              ? Icons.draw 
                              : (isLetterFind 
                                  ? Icons.text_fields 
                                  : Icons.help_outline)))),
              color: isWritingBoard
                  ? const Color(0xFF006D77)
                  : (isLetterDotted
                      ? const Color(0xFF006D77)
                      : (isLetterDrawing 
                          ? const Color(0xFF006D77)
                          : (isLetterWriting 
                              ? const Color(0xFF006D77)
                              : (isLetterFind 
                                  ? const Color(0xFF667EEA)
                                  : Colors.grey)))),
              size: 28,
            ),
            title: Text(
              questionTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            subtitle: isWritingBoard
                ? const Text(
                    'Yazı Tahtası',
                    style: TextStyle(
                      color: Color(0xFF006D77),
                      fontSize: 14,
                    ),
                  )
                : isLetterDotted
                    ? const Text(
                        'Harf Noktalı Yazım',
                        style: TextStyle(
                          color: Color(0xFF006D77),
                          fontSize: 14,
                        ),
                      )
                    : isLetterDrawing
                        ? const Text(
                            'Harf Serbest Çizim',
                            style: TextStyle(
                              color: Color(0xFF006D77),
                              fontSize: 14,
                            ),
                          )
                        : isLetterWriting
                            ? const Text(
                                'Harf Yazımı',
                            style: TextStyle(
                              color: Color(0xFF006D77),
                              fontSize: 14,
                            ),
                          )
                        : isLetterFind
                            ? const Text(
                                'Kelimede Harf Bulma',
                                style: TextStyle(
                                  color: Color(0xFF667EEA),
                                  fontSize: 14,
                                ),
                              )
                            : null,
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.grey,
            ),
            onTap: () {
              if (isWritingBoard) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LetterWritingBoardScreen(
                      activity: widget.activity,
                      questions: _questions,
                      currentQuestionIndex: index,
                    ),
                  ),
                );
              } else if (isLetterDotted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LetterDottedScreen(
                      activity: widget.activity,
                      questions: _questions,
                      currentQuestionIndex: index,
                    ),
                  ),
                );
              } else if (isLetterCDrawing) {
                // LetterCDrawingScreen'e git (C harfi için özel ekran)
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LetterCDrawingScreen(
                      activity: widget.activity,
                      questions: _questions,
                      currentQuestionIndex: index,
                    ),
                  ),
                );
              } else if (isLetterDrawing) {
                // LetterDrawingScreen'e git
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LetterDrawingScreen(
                      activity: widget.activity,
                      questions: _questions,
                      currentQuestionIndex: index,
                    ),
                  ),
                );
              } else if (isLetterCWriting) {
                // LetterCWritingScreen'e git (C harfi için özel ekran)
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LetterCWritingScreen(
                      activity: widget.activity,
                      questions: _questions,
                      currentQuestionIndex: index,
                    ),
                  ),
                );
              } else if (isLetterWriting) {
                // LetterWritingScreen'e git
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LetterWritingScreen(
                      activity: widget.activity,
                      questions: _questions,
                      currentQuestionIndex: index,
                    ),
                  ),
                );
              } else if (isLetterFind) {
                // LetterFindScreen'e git
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LetterFindScreen(
                      activity: widget.activity,
                      questions: _questions,
                      currentQuestionIndex: index,
                    ),
                  ),
                );
              } else {
                // Normal QuestionDetailScreen'e git
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => QuestionDetailScreen(
                      activity: widget.activity,
                      questions: _questions,
                      currentQuestionIndex: index,
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C5CE7),
      appBar: AppBar(
        title: Text(widget.activity.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Aktivite Süre Sayacı (Üst kısımda, her zaman görünür)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ActivityTimer(
              onTimerUpdate: (duration, isRunning) {
                // Timer süresini CurrentSessionService'e kaydet
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final selectedStudent = authProvider.selectedStudent;
                if (selectedStudent != null) {
                  _sessionService.updateSessionTotalDuration(selectedStudent.id, duration);
                }
              },
            ),
          ),
          
          // Ana içerik
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _loadQuestions,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF4834D4),
                              ),
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
                      )
                    : _questions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.help_outline,
                                  size: 64,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage ??
                                      'Bu etkinlik veya ders için henüz soru eklenmemiş',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : _buildQuestionsList(),
          ),
        ],
      ),
    );
  }
}
