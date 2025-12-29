import 'dart:async';
import 'package:flutter/material.dart';
import '../services/content_service.dart';
import '../models/mini_question_model.dart';
import '../models/activity_model.dart';
import 'question_detail_screen.dart';
import 'letter_find_screen.dart';
import 'letter_writing_screen.dart';
import 'letter_c_writing_screen.dart';
import 'letter_drawing_screen.dart';
import 'letter_c_drawing_screen.dart';
import 'letter_dotted_screen.dart';
import 'letter_c_dotted_screen.dart';
import 'letter_writing_board_screen.dart';
import 'letter_visual_finding_screen.dart';

class QuestionsScreen extends StatefulWidget {
  final Activity activity;

  const QuestionsScreen({super.key, required this.activity});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  final ContentService _contentService = ContentService();
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

      debugPrint('🔍 Sorular yükleniyor...');
      debugPrint('📋 Activity ID: ${widget.activity.id}');
      debugPrint('📋 Lesson ID: ${widget.activity.lessonId}');

      // Önce activity bazlı soruları getir
      try {
        debugPrint('🔍 Activity bazlı sorular getiriliyor...');
        final activityResponse = await _contentService.getQuestionsForActivity(
          activityId: widget.activity.id,
        );
        debugPrint('✅ Activity response: ${activityResponse.questions.length} soru');
        if (activityResponse.questions.isNotEmpty) {
          allQuestions.addAll(activityResponse.questions);
          debugPrint(
            '✅ Activity bazlı ${activityResponse.questions.length} soru eklendi',
          );
          for (var q in activityResponse.questions) {
            debugPrint(
              '  - Soru ID: ${q.id}, Type: ${q.questionType}, Activity: ${q.activityId}, Lesson: ${q.lessonId}',
            );
          }
        } else {
          debugPrint('⚠️ Activity bazlı soru bulunamadı');
        }
      } catch (e) {
        // Activity bazlı sorular yoksa devam et (404 normal bir durum)
        final errorStr = e.toString();
        debugPrint('❌ Activity bazlı sorular getirilirken hata: $e');
        if (!errorStr.contains('404') && !errorStr.contains('bulunamadı')) {
          debugPrint('⚠️ Activity bazlı sorular getirilirken hata: $e');
        }
      }

      // Sonra lesson bazlı soruları getir
      try {
        debugPrint('🔍 Lesson bazlı sorular getiriliyor...');
        final lessonResponse = await _contentService.getQuestionsForLesson(
          lessonId: widget.activity.lessonId,
        );
        debugPrint('✅ Lesson response: ${lessonResponse.questions.length} soru');
        if (lessonResponse.questions.isNotEmpty) {
          allQuestions.addAll(lessonResponse.questions);
          debugPrint(
            '✅ Lesson bazlı ${lessonResponse.questions.length} soru eklendi',
          );
          for (var q in lessonResponse.questions) {
            debugPrint(
              '  - Soru ID: ${q.id}, Type: ${q.questionType}, Activity: ${q.activityId}, Lesson: ${q.lessonId}',
            );
          }
        } else {
          debugPrint('⚠️ Lesson bazlı soru bulunamadı');
        }
      } catch (e) {
        // Lesson bazlı sorular yoksa devam et (404 normal bir durum)
        final errorStr = e.toString();
        debugPrint('❌ Lesson bazlı sorular getirilirken hata: $e');
        if (!errorStr.contains('404') && !errorStr.contains('bulunamadı')) {
          debugPrint('⚠️ Lesson bazlı sorular getirilirken hata: $e');
        }
      }

      debugPrint('📊 Toplam ${allQuestions.length} soru bulundu');

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
      debugPrint('Questions loading error: $e');
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
    final questionType = question.questionType.toUpperCase();
    final questionFormat = (question.questionFormat ?? '').toString().toUpperCase();
    final adminNote = (question.data?['adminNote'] ?? '').toString().toUpperCase();
    final activityTitle = widget.activity.title.toUpperCase();
    final questionText = (question.data?['questionText'] ?? '').toString().toUpperCase();
    
    final patterns = ['YAZI_TAHTASI', 'WRITING_BOARD', 'YAZI TAHTASI', 'YAZI TAHTA'];
    final fields = [questionFormat, questionType, questionText, adminNote, activityTitle];
    
    return fields.any((field) => patterns.any((pattern) => field.contains(pattern)));
  }

  bool _isLetterCDottedQuestion(MiniQuestion question) {
    final questionText = question.data?['questionText'] ?? question.data?['text'] ?? '';
    final questionTextUpper = questionText.toString().toUpperCase();
    final activityTitle = widget.activity.title.toUpperCase();
    
    final patterns = [
      'C HARFİ NOKTALI ÇİZİM',
      'C HARFI NOKTALI ÇİZİM',
      'C HARFİ NOKTALI ÇİZ',
      'C HARFI NOKTALI ÇİZ',
      'C HARFİ NOKTALI',
      'C HARFI NOKTALI',
      'C NOKTALI ÇİZİM',
      'C NOKTALI ÇIZIM',
    ];
    
    if (patterns.any((pattern) => questionTextUpper.contains(pattern))) {
      return true;
    }
    
    if (activityTitle.contains('C')) {
      return questionTextUpper.contains('NOKTALI ÇİZİM') ||
             questionTextUpper.contains('NOKTALI ÇIZIM') ||
             (activityTitle.contains('C C') && questionTextUpper.contains('NOKTALI'));
    }
    
    return false;
  }

  bool _isLetterDottedQuestion(MiniQuestion question) {
    if (_isLetterCDottedQuestion(question)) {
      return false;
    }
    
    final questionType = question.questionType.toUpperCase();
    final questionFormat = (question.questionFormat ?? '').toString().toUpperCase();
    final adminNote = (question.data?['adminNote'] ?? '').toString().toUpperCase();
    final activityTitle = widget.activity.title.toUpperCase();
    final questionText = (question.data?['questionText'] ?? '').toString().toUpperCase();
    
    final patterns = ['NOKTALI_YAZIM', 'DOTTED', 'NOKTALI YAZIM', 'NOKTALI YAZ', 'NOKTALI'];
    final fields = [questionFormat, questionType, questionText, adminNote, activityTitle];
    
    return fields.any((field) => patterns.any((pattern) => field.contains(pattern)));
  }

  bool _isLetterDrawingQuestion(MiniQuestion question) {
    if (_isLetterCDrawingQuestion(question)) {
      return false;
    }
    
    final questionType = question.questionType.toUpperCase();
    final questionFormat = (question.questionFormat ?? '').toString().toUpperCase();
    final adminNote = (question.data?['adminNote'] ?? '').toString().toUpperCase();
    final activityTitle = widget.activity.title.toUpperCase();
    final questionText = (question.data?['questionText'] ?? question.data?['text'] ?? '').toString().toUpperCase();
    
    final patterns = ['SERBEST_CIZIM', 'LETTER_DRAWING', 'FREE_DRAWING', 'SERBEST ÇİZİM', 'SERBEST ÇIZIM', 'SERBEST'];
    final fields = [questionFormat, questionType, questionText, adminNote, activityTitle];
    
    return fields.any((field) => patterns.any((pattern) => field.contains(pattern)));
  }

  bool _isLetterCDrawingQuestion(MiniQuestion question) {
    final questionText = question.data?['questionText'] ?? question.data?['text'] ?? '';
    final questionTextUpper = questionText.toString().toUpperCase();
    final activityTitle = widget.activity.title.toUpperCase();
    
    final patterns = [
      'C HARFİ SERBEST ÇİZİM',
      'C HARFI SERBEST ÇİZİM',
      'C HARFİ SERBEST ÇİZ',
      'C HARFI SERBEST ÇİZ',
      'C HARFİ SERBEST',
      'C HARFI SERBEST',
      'C SERBEST ÇİZİM',
      'C SERBEST ÇIZIM',
    ];
    
    if (patterns.any((pattern) => questionTextUpper.contains(pattern))) {
      return true;
    }
    
    if (activityTitle.contains('C')) {
      return questionTextUpper.contains('SERBEST ÇİZİM') ||
             questionTextUpper.contains('SERBEST ÇIZIM') ||
             (activityTitle.contains('C C') && questionTextUpper.contains('SERBEST'));
    }
    
    return false;
  }

  bool _isLetterWritingQuestion(MiniQuestion question) {
    final questionType = question.questionType.toUpperCase();
    final questionFormat = (question.questionFormat ?? '').toString().toUpperCase();
    final adminNote = (question.data?['adminNote'] ?? '').toString().toUpperCase();
    final activityTitle = widget.activity.title.toUpperCase();
    final questionText = (question.data?['questionText'] ?? question.data?['text'] ?? '').toString().toUpperCase();
    
    final patterns = ['HARF_YAZIMI', 'LETTER_WRITING', 'NASIL YAZILIR', 'YAZILIR', 'YAZIM', 'HARF YAZIMI'];
    final fields = [questionFormat, questionType, questionText, adminNote];
    
    if (fields.any((field) => patterns.any((pattern) => field.contains(pattern)))) {
      return true;
    }
    
    final activityPatterns = ['YAZIM', 'YAZILIR', 'HARF YAZIMI', 'HARF_YAZIMI'];
    if (activityPatterns.any((pattern) => activityTitle.contains(pattern))) {
      return true;
    }
    
    return activityTitle.contains('HARF') && 
           ['YAZIM', 'YAZILIR', 'YAZ'].any((pattern) => activityTitle.contains(pattern));
  }

  bool _isLetterCWritingQuestion(MiniQuestion question) {
    final questionText = question.data?['questionText'] ?? question.data?['text'] ?? '';
    final questionTextUpper = questionText.toString().toUpperCase();
    
    final patterns = [
      'C HARFİ NASIL YAZILIR',
      'C HARFI NASIL YAZILIR',
      'C HARFİ NASIL YAZ',
      'C HARFI NASIL YAZ',
    ];
    
    return patterns.any((pattern) => questionTextUpper.contains(pattern));
  }

  bool _isLetterFindQuestion(MiniQuestion question) {
    final questionType = question.questionType.toUpperCase();
    final questionFormat = (question.questionFormat ?? '').toString().toUpperCase();
    final adminNote = (question.data?['adminNote'] ?? '').toString().toUpperCase();
    final activityTitle = widget.activity.title.toUpperCase();
    
    final contentObject = question.data?['contentObject'];
    final hasWordsArray = contentObject != null && 
        contentObject is Map && 
        contentObject['words'] != null &&
        contentObject['words'] is List &&
        (contentObject['words'] as List).isNotEmpty;
    
    if (hasWordsArray) {
      return true;
    }
    
    final patterns = ['KELIMEDE_HARF_BULMA', 'KELIMEDE', 'BULMA'];
    if ([questionFormat, questionType].any((field) => patterns.any((pattern) => field.contains(pattern)))) {
      return true;
    }
    
    final notePatterns = ['KELIMEDE', 'BULMA'];
    if (adminNote.isNotEmpty && notePatterns.any((pattern) => adminNote.contains(pattern))) {
      return true;
    }
    
    final titlePatterns = ['KELIMEDE', 'BULMA'];
    return activityTitle.isNotEmpty && titlePatterns.any((pattern) => activityTitle.contains(pattern));
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
              } else if (isLetterCDotted) {
                // LetterCDottedScreen'e git (C harfi için özel ekran)
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LetterCDottedScreen(
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

  bool _shouldShowLetterVisualFinding() {
    // Activity title'ında "GÖRSEL BULMA", "Görsel Bulma", "HARFİ GÖRSEL" varsa LetterVisualFindingScreen göster
    // A, B, C gibi herhangi bir harf için çalışır
    final title = widget.activity.title.toUpperCase();
    return title.contains('GÖRSEL BULMA') || 
           title.contains('GÖRSELDEN BULMA') ||
           title.contains('HARFİ GÖRSEL') ||
           title.contains('A HARFİ') ||
           title.contains('B HARFİ') ||
           title.contains('C HARFİ');
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
      body: _isLoading
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
          : _shouldShowLetterVisualFinding()
              ? LetterVisualFindingScreen(
                  activity: widget.activity,
                  questions: _questions,
                )
              : _buildQuestionsList(),
    );
  }
}
