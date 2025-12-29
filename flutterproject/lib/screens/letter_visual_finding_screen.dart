import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/mini_question_model.dart';
import '../models/activity_model.dart';
import '../config/api_config.dart';
import '../services/current_session_service.dart';
import '../providers/auth_provider.dart';

// Gruplanmış soru modeli (her sayfa için 3 resim)
class GroupedQuestion {
  final List<String> imageFileIds;
  final int correctIndex;
  final String? instruction;
  
  GroupedQuestion({
    required this.imageFileIds,
    required this.correctIndex,
    this.instruction,
  });
}

class LetterVisualFindingScreen extends StatefulWidget {
  final Activity activity;
  final List<MiniQuestion> questions;

  const LetterVisualFindingScreen({
    super.key,
    required this.activity,
    required this.questions,
  });

  @override
  State<LetterVisualFindingScreen> createState() => _LetterVisualFindingScreenState();
}

class _LetterVisualFindingScreenState extends State<LetterVisualFindingScreen> with TickerProviderStateMixin {
  int _currentPage = 0;
  bool _pageCompleted = false;
  int? _selectedIndex;
  bool _showCongratulations = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final CurrentSessionService _sessionService = CurrentSessionService();
  DateTime? _activityStartTime;
  
  // Gruplanmış sorular (her sayfa için 3 resim)
  List<GroupedQuestion>? _groupedQuestions;
  
  // Animasyon controller'ları
  late AnimationController _starController;
  late AnimationController _planet1Controller;
  late AnimationController _planet2Controller;
  late AnimationController _planet3Controller;
  late AnimationController _planet4Controller;

  @override
  void initState() {
    super.initState();
    _activityStartTime = DateTime.now();
    
    // Soruları grupla (her sayfa için 3 resim)
    _groupQuestions();
    
    // Animasyon controller'ları
    _starController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
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
    
    // İlk sayfa gösterilirken ikinci sayfanın resimlerini önceden yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadNextPageImages(_currentPage);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _starController.dispose();
    _planet1Controller.dispose();
    _planet2Controller.dispose();
    _planet3Controller.dispose();
    _planet4Controller.dispose();
    super.dispose();
  }

  void _groupQuestions() {
    final grouped = <GroupedQuestion>[];
    
    debugPrint('═══════════════════════════════════════');
    debugPrint('📦 SORULARI GRUPLAMA BAŞLIYOR...');
    debugPrint('   Toplam soru sayısı: ${widget.questions.length}');
    debugPrint('═══════════════════════════════════════');
    
    // Her soru bir sayfa olacak şekilde grupla
    // Her soruda 3 resim olmalı (admin panelinden eklenen format)
    // MAKSİMUM 5 SAYFA (15 soru/resim)
    const maxPages = 5;
    
    for (int i = 0; i < widget.questions.length && grouped.length < maxPages; i++) {
      final question = widget.questions[i];
      final imageIds = _getImageFileIds(question);
      
      debugPrint('📄 Soru ${i + 1}:');
      debugPrint('   Resim sayısı: ${imageIds.length}');
      debugPrint('   Resim ID\'leri: $imageIds');
      
      // Doğru/yanlış haritasını al ve göster
      final correctMap = _getImageCorrectMap(question);
      debugPrint('   Doğru/yanlış haritası: $correctMap');
      for (var entry in correctMap.entries) {
        debugPrint('      ${entry.key}: ${entry.value ? "✅ DOĞRU" : "❌ YANLIŞ"}');
      }
      
      // Eğer bir soruda 3 resim varsa, direkt kullan (ideal durum)
      if (imageIds.length >= 3) {
        final pageImages = imageIds.take(3).toList();
        final correctIndex = _getCorrectAnswerIndexForPage(question, pageImages);
        grouped.add(GroupedQuestion(
          imageFileIds: pageImages,
          correctIndex: correctIndex,
          instruction: question.data?['instruction']?.toString(),
        ));
        debugPrint('   ✅ Sayfa ${grouped.length} oluşturuldu');
        debugPrint('      Resimler: $pageImages');
        debugPrint('      Doğru cevap index: $correctIndex');
        debugPrint('      Doğru resim ID: ${pageImages[correctIndex]}');
      } else if (imageIds.isNotEmpty) {
        // Eğer tek veya iki resim varsa, uyarı ver
        debugPrint('   ⚠️ UYARI: Soru ${i + 1} için sadece ${imageIds.length} resim bulundu! 3 resim gerekli.');
      } else {
        debugPrint('   ❌ HATA: Soru ${i + 1} için hiç resim bulunamadı!');
      }
    }
    
    if (grouped.length >= maxPages) {
      debugPrint('   ⚠️ UYARI: Maksimum $maxPages sayfa oluşturuldu. Kalan sorular göz ardı edildi.');
    }
    
    // Eğer hiç gruplanmış soru yoksa, tüm resimleri topla ve 3'er 3'er grupla (fallback)
    if (grouped.isEmpty) {
      debugPrint('⚠️ Hiç soru gruplanamadı, tüm resimleri topluyorum...');
      final allIds = <String>[];
      
      for (int i = 0; i < widget.questions.length; i++) {
        final question = widget.questions[i];
        final imageIds = _getImageFileIds(question);
        allIds.addAll(imageIds);
        debugPrint('   Soru ${i + 1}: ${imageIds.length} resim eklendi');
      }
      
      debugPrint('   Toplam resim: ${allIds.length}');
      
      if (allIds.length >= 3) {
        const maxPages = 5;
        for (int i = 0; i < allIds.length && grouped.length < maxPages; i += 3) {
          if (i + 3 <= allIds.length) {
            final pageImages = allIds.sublist(i, i + 3);
            // Bu sayfadaki resimlerin hangi soruya ait olduğunu bul
            final questionIndex = (i ~/ 3);
            final question = questionIndex < widget.questions.length 
                ? widget.questions[questionIndex] 
                : widget.questions[0];
            final correctIndex = _getCorrectAnswerIndexForPage(question, pageImages);
            
            grouped.add(GroupedQuestion(
              imageFileIds: pageImages,
              correctIndex: correctIndex,
              instruction: question.data?['instruction']?.toString(),
            ));
            debugPrint('   ✅ Sayfa ${grouped.length} oluşturuldu');
            debugPrint('      Resimler: $pageImages');
            debugPrint('      Doğru cevap index: $correctIndex (${pageImages[correctIndex]})');
          }
        }
        if (grouped.length >= maxPages) {
          debugPrint('   ⚠️ UYARI: Maksimum $maxPages sayfa oluşturuldu. Kalan resimler göz ardı edildi.');
        }
      }
    }
    
    _groupedQuestions = grouped;
    debugPrint('═══════════════════════════════════════');
    debugPrint('📦 GRUPLAMA TAMAMLANDI');
    debugPrint('   Toplam sayfa sayısı: ${grouped.length} (MAKSİMUM: 5)');
    if (grouped.length > 5) {
      debugPrint('   ❌❌❌ HATA: ${grouped.length} sayfa oluşturuldu ama maksimum 5 olmalı! ❌❌❌');
    }
    for (int i = 0; i < grouped.length; i++) {
      debugPrint('   Sayfa ${i + 1}: ${grouped[i].imageFileIds.length} resim - Doğru cevap index: ${grouped[i].correctIndex}');
    }
    debugPrint('═══════════════════════════════════════');
  }

  String _getFileUrl(String? fileId) {
    if (fileId == null) return '';
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    return '$baseUrl/api/files/$fileId';
  }

  List<String> _getImageFileIds(MiniQuestion question) {
    // 1. data içinden imageFileIds array'ini al (en yaygın format)
    if (question.data != null && question.data!['imageFileIds'] != null) {
      final imageFileIds = question.data!['imageFileIds'];
      if (imageFileIds is List) {
        final ids = imageFileIds.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        if (ids.length >= 3) {
          return ids.take(3).toList();
        }
      } else if (imageFileIds is String) {
        final ids = imageFileIds.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (ids.length >= 3) {
          return ids.take(3).toList();
        }
      }
    }
    
    // 2. data içinden mediaFiles array'ini al
    if (question.data != null && question.data!['mediaFiles'] != null) {
      final mediaFiles = question.data!['mediaFiles'];
      if (mediaFiles is List) {
        final ids = mediaFiles.map((e) {
          if (e is Map) {
            final mediaType = e['mediaType']?.toString().toLowerCase();
            if (mediaType == 'image') {
              return e['fileId']?.toString() ?? '';
            }
          }
          return '';
        }).where((e) => e.isNotEmpty).toList();
        if (ids.length >= 3) {
          return ids.take(3).toList();
        }
      }
    }
    
    // 3. images array'i
    if (question.data != null && question.data!['images'] != null) {
      final images = question.data!['images'];
      if (images is List) {
        final ids = images.map((e) {
          if (e is Map) {
            return e['fileId']?.toString() ?? e['id']?.toString() ?? e['_id']?.toString() ?? '';
          }
          return e.toString();
        }).where((e) => e.isNotEmpty).toList();
        if (ids.length >= 3) {
          return ids.take(3).toList();
        }
      }
    }
    
    // 4. options array'i
    if (question.data != null && question.data!['options'] != null) {
      final options = question.data!['options'];
      if (options is List) {
        final ids = options.map((e) {
          if (e is Map) {
            return e['imageFileId']?.toString() ?? e['fileId']?.toString() ?? e['id']?.toString() ?? '';
          }
          return e.toString();
        }).where((e) => e.isNotEmpty).toList();
        if (ids.length >= 3) {
          return ids.take(3).toList();
        }
      }
    }
    
    // 5. mediaFileId (tek resim)
    if (question.mediaFileId != null && question.mediaFileId!.isNotEmpty) {
      return [question.mediaFileId!];
    }
    
    return [];
  }
  
  // Her resim için doğru/yanlış bilgisini içeren yapı
  Map<String, bool> _getImageCorrectMap(MiniQuestion question) {
    final correctMap = <String, bool>{};
    
    debugPrint('   🔍 Doğru/yanlış haritası oluşturuluyor...');
    
    // 1. ÖNCE: data.mediaFiles array'inden isCorrect bilgisini al (EN YAYGIN)
    if (question.data != null && question.data!['mediaFiles'] != null) {
      final mediaFiles = question.data!['mediaFiles'];
      debugPrint('   🔍 mediaFiles bulundu: ${mediaFiles.runtimeType}');
      if (mediaFiles is List) {
        debugPrint('   🔍 mediaFiles listesi: ${mediaFiles.length} öğe');
        for (int i = 0; i < mediaFiles.length; i++) {
          final file = mediaFiles[i];
          if (file is Map) {
            final mediaType = file['mediaType']?.toString().toLowerCase();
            debugPrint('   🔍 Dosya $i: mediaType=$mediaType, fileId=${file['fileId']}, isCorrect=${file['isCorrect']}, correct=${file['correct']}');
            if (mediaType == 'image') {
              final fileId = file['fileId']?.toString() ?? '';
              // isCorrect, correct, isCorrectAnswer, correctAnswer gibi farklı field'ları kontrol et
              final isCorrect = file['isCorrect'] == true || 
                               file['isCorrect'] == 'true' ||
                               file['isCorrect'] == 1 ||
                               file['correct'] == true ||
                               file['correct'] == 'true' ||
                               file['correct'] == 1 ||
                               file['isCorrectAnswer'] == true ||
                               file['isCorrectAnswer'] == 'true' ||
                               file['correctAnswer'] == true ||
                               file['correctAnswer'] == 'true';
              if (fileId.isNotEmpty) {
                correctMap[fileId] = isCorrect;
                debugPrint('      ✅ $fileId: ${isCorrect ? "DOĞRU" : "YANLIŞ"}');
              }
            }
          }
        }
      }
    }
    
    // 2. imageFileIds array'i ile birlikte correctAnswers array'i olabilir
    if (question.data != null && question.data!['imageFileIds'] != null && 
        question.data!['correctAnswers'] != null) {
      final imageIds = question.data!['imageFileIds'];
      final correctAnswers = question.data!['correctAnswers'];
      debugPrint('   🔍 correctAnswers array bulundu');
      if (imageIds is List && correctAnswers is List) {
        for (int i = 0; i < imageIds.length && i < correctAnswers.length; i++) {
          final fileId = imageIds[i].toString();
          final isCorrect = correctAnswers[i] == true || 
                           correctAnswers[i] == 'true' ||
                           correctAnswers[i] == 1 ||
                           correctAnswers[i] == 'yes' ||
                           correctAnswers[i] == 'evet';
          correctMap[fileId] = isCorrect;
        }
      }
    }
    
    // 3. imageFileIds array'i içinde her öğe bir Map olabilir (isCorrect içerir)
    if (question.data != null && question.data!['imageFileIds'] != null) {
      final imageFileIds = question.data!['imageFileIds'];
      if (imageFileIds is List) {
        for (var item in imageFileIds) {
          if (item is Map) {
            final fileId = item['fileId']?.toString() ?? item['id']?.toString() ?? '';
            final isCorrect = item['isCorrect'] == true || 
                             item['isCorrect'] == 'true' ||
                             item['isCorrect'] == 1 ||
                             item['correct'] == true ||
                             item['correct'] == 'true' ||
                             item['correct'] == 1;
            if (fileId.isNotEmpty) {
              correctMap[fileId] = isCorrect;
            }
          }
        }
      }
    }
    
    debugPrint('   ✅ Toplam ${correctMap.length} resim için doğru/yanlış bilgisi bulundu');
    return correctMap;
  }

  int _getCorrectAnswerIndexForPage(MiniQuestion question, List<String> pageImageIds) {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔍 DOĞRU CEVAP KONTROLÜ - Sayfa ${_currentPage + 1}');
    debugPrint('   Sayfa resimleri: $pageImageIds');
    
    // ÖNCE: Her resim için doğru/yanlış bilgisini al (admin panelinden işaretlenen)
    final correctMap = _getImageCorrectMap(question);
    debugPrint('   🔍 Doğru/yanlış haritası: $correctMap');
    
    // Sayfa resimleri içinde doğru olanı bul
    for (int i = 0; i < pageImageIds.length; i++) {
      final imageId = pageImageIds[i];
      if (correctMap[imageId] == true) {
        debugPrint('   ✅ Doğru resim bulundu: index $i (ID: $imageId)');
        return i;
      }
    }
    
    // EĞER doğru/yanlış haritası boşsa, eski yöntemleri dene
    debugPrint('   ⚠️ Doğru/yanlış haritası boş, eski yöntemler deneniyor...');
    debugPrint('   question.correctAnswer: "${question.correctAnswer}"');
    
    // question.correctAnswer'ı kontrol et
    if (question.correctAnswer != null && question.correctAnswer!.isNotEmpty) {
      final answerStr = question.correctAnswer!.trim();
      debugPrint('   🔍 correctAnswer: "$answerStr"');
      
      // 1. Resim ID'leri içinde ara
      final foundIndex = pageImageIds.indexOf(answerStr);
      if (foundIndex >= 0) {
        debugPrint('   ✅ correctAnswer resim ID olarak bulundu: index $foundIndex');
        return foundIndex;
      }
      
      // 2. Integer olarak parse et (0, 1, 2)
      final answer = int.tryParse(answerStr);
      if (answer != null && answer >= 0 && answer < pageImageIds.length) {
        debugPrint('   ✅ correctAnswer (integer) bulundu: $answer');
        return answer;
      }
    }
    
    // data içinden kontrol et
    if (question.data != null) {
      // correctImageFileId
      if (question.data!['correctImageFileId'] != null) {
        final correctId = question.data!['correctImageFileId'].toString().trim();
        final foundIndex = pageImageIds.indexOf(correctId);
        if (foundIndex >= 0) {
          debugPrint('   ✅ correctImageFileId bulundu: index $foundIndex');
          return foundIndex;
        }
      }
      
      // correctIndex
      if (question.data!['correctIndex'] != null) {
        final indexStr = question.data!['correctIndex'].toString().trim();
        final index = int.tryParse(indexStr);
        if (index != null && index >= 0 && index < pageImageIds.length) {
          debugPrint('   ✅ correctIndex bulundu: $index');
          return index;
        }
      }
      
      // correctAnswer data içinde
      if (question.data!['correctAnswer'] != null) {
        final answerStr = question.data!['correctAnswer'].toString().trim();
        final foundIndex = pageImageIds.indexOf(answerStr);
        if (foundIndex >= 0) {
          debugPrint('   ✅ correctAnswer (data) bulundu: index $foundIndex');
          return foundIndex;
        }
        final answer = int.tryParse(answerStr);
        if (answer != null && answer >= 0 && answer < pageImageIds.length) {
          debugPrint('   ✅ correctAnswer (data, integer) bulundu: $answer');
          return answer;
        }
      }
    }
    
    debugPrint('   ❌ HATA: Doğru cevap bulunamadı!');
    debugPrint('   ⚠️ Varsayılan olarak 0 (ilk resim) kullanılıyor');
    debugPrint('═══════════════════════════════════════');
    return 0;
  }
  

  void _checkAnswer(int selectedIndex) {
    if (_pageCompleted || _groupedQuestions == null) return;
    
    final groupedQuestion = _groupedQuestions![_currentPage];
    final correctIndex = groupedQuestion.correctIndex;
    
    final isCorrect = selectedIndex == correctIndex;
    
    setState(() {
      _selectedIndex = selectedIndex;
      _pageCompleted = isCorrect;
    });
    
    if (isCorrect) {
      // Doğru cevap - tebrikler sesini çal
      _playCongratulationsSound();
      
      // Bir sonraki sayfanın resimlerini önceden yükle (doğru cevap verildiğinde)
      _preloadNextPageImages(_currentPage);
      
      // Son sayfadaysa tebrik ekranını göster ve aktiviteyi kaydet
      if (_groupedQuestions != null && _currentPage == _groupedQuestions!.length - 1) {
        // Aktiviteyi oturum servisine ekle (TAMAMLANMIŞ olarak işaretle)
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final selectedStudent = authProvider.selectedStudent;
        
        if (selectedStudent != null && _activityStartTime != null) {
          final duration = DateTime.now().difference(_activityStartTime!).inSeconds;
          final correctCount = _groupedQuestions!.length; // Tüm sayfalar doğru cevaplandı
          
          _sessionService.addActivity(
            studentId: selectedStudent.id,
            activityId: widget.activity.id,
            activityTitle: widget.activity.title,
            durationSeconds: duration,
            successStatus: '$correctCount/${_groupedQuestions!.length} sayfa tamamlandı',
            isCompleted: true, // Aktivite başarıyla tamamlandı
            correctAnswerCount: correctCount, // Doğru cevap sayısı
          );
        }
        
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _showCongratulations = true;
            });
          }
        });
      }
    }
  }

  Future<void> _playCongratulationsSound() async {
    try {
      // Tebrikler ses dosyası ID'si (data içinden alınabilir)
      final question = widget.questions[_currentPage];
      final soundFileId = question.data?['congratulationsSoundFileId'];
      
      if (soundFileId != null) {
        final url = _getFileUrl(soundFileId);
        await _audioPlayer.play(UrlSource(url));
      }
    } catch (e) {
      debugPrint('Tebrikler sesi çalınamadı: $e');
    }
  }

  void _changePage(int direction) {
    if (_groupedQuestions == null) return;
    
    if (direction > 0 && !_pageCompleted && _currentPage < _groupedQuestions!.length - 1) {
      return; // Sayfa tamamlanmadan ileri gidilemez
    }
    
    setState(() {
      _currentPage += direction;
      if (_currentPage < 0) _currentPage = 0;
      if (_currentPage >= _groupedQuestions!.length) _currentPage = _groupedQuestions!.length - 1;
      
      _pageCompleted = false;
      _selectedIndex = null;
    });
    
    // Bir sonraki sayfanın resimlerini önceden yükle (kullanıcı beklemez)
    _preloadNextPageImages(_currentPage);
  }
  
  /// Bir sonraki sayfanın resimlerini önceden yükle (preload)
  void _preloadNextPageImages(int currentPage) {
    if (!mounted || _groupedQuestions == null) return;
    
    // Bir sonraki sayfa var mı kontrol et
    final nextPageIndex = currentPage + 1;
    if (nextPageIndex >= _groupedQuestions!.length) return;
    
    final nextPage = _groupedQuestions![nextPageIndex];
    
    // Bir sonraki sayfanın tüm resimlerini önceden yükle
    for (int i = 0; i < nextPage.imageFileIds.length; i++) {
      final imageFileId = nextPage.imageFileIds[i];
      if (imageFileId.isNotEmpty) {
        final imageUrl = _getFileUrl(imageFileId);
        
        if (imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
          // Resmi arka planda önceden yükle (kullanıcı beklemez)
          Future.delayed(Duration(milliseconds: i * 100), () async {
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
  }

  void _restartGame() {
    setState(() {
      _currentPage = 0;
      _pageCompleted = false;
      _selectedIndex = null;
      _showCongratulations = false;
    });
  }

  /// Etkinlik tamamlandığında mail gönder
  /// Etkinlik tamamlandığında dialog'u kapat (aktivite zaten oturum servisine kaydedildi)
  void _onCompleted() {
    // Aktivite zaten oturum servisine kaydedildi (_showCongratulations gösterilmeden önce)
    // Sadece dialog'u kapat ve geri git
    Navigator.of(context).pop();
  }

  String _getTargetLetter() {
    // Activity title'dan hangi harfi arayacağını çıkar
    final title = widget.activity.title.toUpperCase();
    
    // "A HARFİ", "B HARFİ" gibi pattern'leri ara
    if (title.contains('A HARFİ') || title.contains('A GÖRSEL')) {
      return 'a';
    } else if (title.contains('B HARFİ') || title.contains('B GÖRSEL')) {
      return 'b';
    } else if (title.contains('C HARFİ') || title.contains('C GÖRSEL')) {
      return 'c';
    }
    // Varsayılan olarak "b" harfi
    return 'b';
  }

  String _getInstructionText() {
    // Activity veya soru içinden açıklama metnini al
    final question = widget.questions[_currentPage];
    if (question.data != null && question.data!['instruction'] != null) {
      return question.data!['instruction'].toString();
    }
    // Varsayılan açıklama - dinamik harf
    final targetLetter = _getTargetLetter();
    return 'İçinde $targetLetter harfi bulunan kelimenin resmine dokun';
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
    // Gruplanmış soruları kullan
    if (_groupedQuestions == null || _groupedQuestions!.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            'Sorular yükleniyor...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }
    
    if (_currentPage >= _groupedQuestions!.length) {
      return Scaffold(
        body: Center(
          child: Text(
            'Tüm sorular tamamlandı!',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    final groupedQuestion = _groupedQuestions![_currentPage];
    final imageFileIds = groupedQuestion.imageFileIds;
    final correctIndex = groupedQuestion.correctIndex;
    
    // Debug: Resim sayısını kontrol et
    debugPrint('═══════════════════════════════════════');
    debugPrint('📄 SAYFA ${_currentPage + 1}/${_groupedQuestions!.length}');
    debugPrint('🖼️ Resim sayısı: ${imageFileIds.length}');
    debugPrint('🖼️ Resim ID\'leri: $imageFileIds');
    debugPrint('✅ Doğru cevap index: $correctIndex');
    debugPrint('═══════════════════════════════════════');
    
    // Eğer 3 resim yoksa, detaylı hata mesajı göster
    if (imageFileIds.length < 3) {
      return Scaffold(
        body: Stack(
          children: [
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
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Bu sayfa için yeterli resim bulunamadı',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bulunan resim sayısı: ${imageFileIds.length}/3',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Sayfa: ${_currentPage + 1}/${_groupedQuestions!.length}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            if (imageFileIds.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Bulunan Resimler: $imageFileIds',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Lütfen admin panelinden bu soru için 3 resim ekleyin.\n\n'
                        'Resimler şu formatta olmalı:\n'
                        'data.imageFileIds: ["id1", "id2", "id3"]\n'
                        'veya\n'
                        'data.mediaFiles: [{fileId: "id1", mediaType: "Image"}, ...]',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
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
                // Üst Header (HTML'deki header gibi)
                Container(
                  margin: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[800]!.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${_getTargetLetter().toUpperCase()} HARFİ GÖRSEL BULMA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                // Activity Container (HTML'deki activity-container gibi)
                Expanded(
                  child: SingleChildScrollView(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Açıklama (HTML'deki h2 gibi)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.flag,
                                    color: Color(0xFFFFC107),
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                              child: Text(
                                groupedQuestion.instruction ?? _getInstructionText(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 30),
                            // Resim Grid (3 sütun - HTML'deki word-grid gibi)
                            SizedBox(
                              height: 250,
                              child: Row(
                                children: List.generate(3, (index) {
                                  final imageFileId = imageFileIds[index];
                                  final isSelected = _selectedIndex == index;
                                  final isCorrect = index == correctIndex;
                                  final showCorrect = _pageCompleted && isCorrect;
                                  final showWrong = isSelected && !isCorrect && _pageCompleted;
                                  
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: index == 0 ? 0 : 10,
                                        right: index == 2 ? 0 : 10,
                                      ),
                                      child: GestureDetector(
                                        onTap: _pageCompleted ? null : () => _checkAnswer(index),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 600),
                                          height: 250,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(15),
                                            border: Border.all(
                                              color: showCorrect
                                                  ? const Color(0xFF00B894)
                                                  : showWrong
                                                      ? const Color(0xFFFDCB6E)
                                                      : Colors.grey[300]!,
                                              width: showCorrect || showWrong ? 5 : 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: showCorrect
                                                    ? const Color(0xFF00B894).withValues(alpha: 0.5)
                                                    : showWrong
                                                        ? const Color(0xFFFDCB6E).withValues(alpha: 0.5)
                                                        : Colors.black.withValues(alpha: 0.2),
                                                blurRadius: showCorrect || showWrong ? 30 : 20,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: imageFileId.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: _getFileUrl(imageFileId),
                                                    cacheKey: '${imageFileId}_${_currentPage}_${index}_${_groupedQuestions?.length ?? 0}', // Sayfa ve soru sayısına göre cache key
                                                    fit: BoxFit.contain,
                                                    // Görüntü kodlama hatası için maxWidth/maxHeight ekle
                                                    maxWidthDiskCache: 400,
                                                    maxHeightDiskCache: 400,
                                                    memCacheWidth: 400,
                                                    memCacheHeight: 400,
                                                    placeholder: (context, url) => const Center(
                                                      child: CircularProgressIndicator(
                                                        color: Color(0xFF4FC3F7),
                                                      ),
                                                    ),
                                                    errorWidget: (context, url, error) {
                                                      // Görüntü kodlama hatasını yakala
                                                      debugPrint('❌ Image error: $url - $error');
                                                      return const Center(
                                                        child: Icon(
                                                          Icons.image_not_supported,
                                                          size: 48,
                                                          color: Colors.grey,
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : const Center(
                                                    child: Icon(
                                                      Icons.image,
                                                      size: 48,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                              const SizedBox(height: 20),
                            // Mesaj (HTML'deki message div gibi)
                            if (_selectedIndex != null)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                constraints: const BoxConstraints(minHeight: 70),
                                decoration: BoxDecoration(
                                  color: _pageCompleted
                                      ? const Color(0xFF00B894).withValues(alpha: 0.1)
                                      : const Color(0xFFFDCB6E).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _pageCompleted
                                        ? const Color(0xFF00B894)
                                        : const Color(0xFFFDCB6E),
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  _pageCompleted
                                      ? '🎉 HARİKASIN! 🎉'
                                      : '🤔 Tekrar dene! Doğru cevabı bulabilirsin! 💪',
                                  style: TextStyle(
                                    color: _pageCompleted
                                        ? const Color(0xFF00B894)
                                        : const Color(0xFFE17055),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 30),
                            // Navigasyon Butonları (HTML'deki navigation gibi)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: _currentPage == 0 ? null : () => _changePage(-1),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.arrow_back, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Önceki',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                ElevatedButton(
                              onPressed: (_currentPage >= _groupedQuestions!.length - 1 || !_pageCompleted)
                                  ? null
                                  : () => _changePage(1),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF74B9FF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Sonraki',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, size: 20),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tebrik Ekranı
          if (_showCongratulations)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(40),
                  padding: const EdgeInsets.all(50),
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
                        '🎉 TEBRİKLER! 🎉',
                        style: TextStyle(
                          color: Color(0xFF00B894),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Etkinliği tamamladın!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        '✨🌟✨',
                        style: TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Tamamlandı Butonu (Sadece kaydet, mail gönderme)
                          ElevatedButton(
                            onPressed: _onCompleted,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              'Tamamlandı',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Tekrar Oyna Butonu
                          ElevatedButton(
                            onPressed: _restartGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF74B9FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              'Tekrar Oyna',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
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

