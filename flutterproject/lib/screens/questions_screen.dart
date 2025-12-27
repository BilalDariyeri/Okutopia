import 'dart:async';
import 'package:flutter/material.dart';
import '../services/content_service.dart';
import '../models/mini_question_model.dart';
import '../models/activity_model.dart';
import 'question_detail_screen.dart';
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
      debugPrint('❌ Genel hata: $e');
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
              : QuestionDetailScreen(
                  activity: widget.activity,
                  questions: _questions,
                  currentQuestionIndex: 0,
                ),
    );
  }
}
