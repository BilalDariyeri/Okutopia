import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/content_service.dart';
import '../services/activity_progress_service.dart';
import '../services/current_session_service.dart';
import '../models/activity_model.dart';
import '../models/category_model.dart';
import '../providers/student_selection_provider.dart';

/// Okuma Geliştirme Metinleri Ekranı
/// Glassmorphism tasarım, kademeli zorluk, kilit sistemi
/// Tek tek hece gösterimi ve "Sonraki Heceye Geç" butonu
class ReadingDevelopmentScreen extends StatefulWidget {
  final Category category;

  const ReadingDevelopmentScreen({
    super.key,
    required this.category,
  });

  @override
  State<ReadingDevelopmentScreen> createState() => _ReadingDevelopmentScreenState();
}

class _ReadingDevelopmentScreenState extends State<ReadingDevelopmentScreen> with TickerProviderStateMixin {
  final ContentService _contentService = ContentService();
  final ActivityProgressService _progressService = ActivityProgressService();
  final CurrentSessionService _sessionService = CurrentSessionService();
  
  List<_ReadingLevel> _levels = [];
  bool _isLoading = true;
  String? _errorMessage;
  Set<String> _completedLevelIds = {};

  // Okuma modu state'leri
  bool _isReadingMode = false;
  _ReadingLevel? _currentLevel;
  int _currentSyllableIndex = 0;
  List<String> _syllables = [];
  DateTime? _readingStartTime; // Okuma başlangıç zamanı (süre hesaplama için)

  // Animasyon controller'ları
  late AnimationController _planet1Controller;
  late AnimationController _planet2Controller;
  late AnimationController _planet3Controller;
  late AnimationController _planet4Controller;

  @override
  void initState() {
    super.initState();
    
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
    
    _initializeData();
  }

  /// Verileri sırayla yükle (önce levels, sonra progress)
  Future<void> _initializeData() async {
    await _loadLevels();
    await _loadProgress();
  }

  @override
  void dispose() {
    _planet1Controller.dispose();
    _planet2Controller.dispose();
    _planet3Controller.dispose();
    _planet4Controller.dispose();
    super.dispose();
  }

  /// İlerleme verilerini yükle
  Future<void> _loadProgress() async {
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;
    
    if (selectedStudent != null) {
      final completed = await _progressService.getCompletedReadingTexts(selectedStudent.id);
      
      if (mounted) {
        setState(() {
          _completedLevelIds = completed;
        });
      }
    }
  }

  /// Seviyeleri yükle (Gruplar → Dersler → Aktiviteler)
  Future<void> _loadLevels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Kategorideki grupları al
      final groupsResponse = await _contentService.getGroupsByCategory(
        categoryId: widget.category.id,
      );

      List<_ReadingLevel> levels = [];
      int levelIndex = 0;

      // Her grup için dersleri ve aktiviteleri al
      for (final group in groupsResponse.groups) {
        final lessonsResponse = await _contentService.getLessonsByGroup(
          groupId: group.id,
        );

        for (final lesson in lessonsResponse.lessons) {
          final activitiesResponse = await _contentService.getActivitiesByLesson(
            lessonId: lesson.id,
          );

          // Okuma metni aktivitelerini filtrele
          final readingActivities = activitiesResponse.activities
              .where((a) => a.activityType == 'Text' && a.textLines != null && a.textLines!.isNotEmpty)
              .toList();

          for (final activity in readingActivities) {
            levelIndex++;
            levels.add(_ReadingLevel(
              id: activity.id,
              levelNumber: levelIndex,
              title: activity.title,
              description: _getLevelDescription(levelIndex),
              preview: _getContentPreview(activity),
              textLines: activity.textLines ?? [],
              durationMinutes: activity.durationMinutes,
            ));
          }
        }
      }

      // Eğer hiç okuma metni yoksa, örnek veriler oluştur
      if (levels.isEmpty) {
        levels = _createSampleLevels();
      }

      setState(() {
        _levels = levels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg.contains('500') || errorMsg.contains('Sunucu hatası')) {
          errorMsg = 'Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyin.';
        } else if (errorMsg.contains('401') || errorMsg.contains('Token')) {
          errorMsg = 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.';
        } else if (errorMsg.contains('403')) {
          errorMsg = 'Bu işlem için yetkiniz bulunmamaktadır.';
        } else if (errorMsg.contains('404')) {
          // 404 durumunda örnek veriler göster
          _levels = _createSampleLevels();
          _isLoading = false;
          return;
        }
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  /// Örnek seviyeler oluştur
  List<_ReadingLevel> _createSampleLevels() {
    return [
      _ReadingLevel(
        id: '1',
        levelNumber: 1,
        title: '1. Seviye',
        description: 'Sesler ve Kolay Heceler',
        preview: 'e, l, a, el, le',
        textLines: ['e', 'l', 'a', 'el', 'le', 'al', 'la', 'ela', 'ale', 'lale', 'elle'],
        durationMinutes: 5,
      ),
      _ReadingLevel(
        id: '2',
        levelNumber: 2,
        title: '2. Seviye',
        description: 'Basit Kelimeler ve Birleştirmeler',
        preview: 'su, at, ev, top',
        textLines: ['su', 'at', 'ev', 'top', 'bal', 'dal', 'sal', 'kal', 'gel', 'ver', 'al'],
        durationMinutes: 5,
      ),
      _ReadingLevel(
        id: '3',
        levelNumber: 3,
        title: '3. Seviye',
        description: 'Basit Cümleler',
        preview: 'Ali su iç.',
        textLines: ['Ali su iç.', 'Baba çay iç.', 'Gece ay var.', 'Lale çiçek al.', 'Oya top at.'],
        durationMinutes: 7,
      ),
      _ReadingLevel(
        id: '4',
        levelNumber: 4,
        title: '4. Seviye',
        description: 'Karmaşık Cümle Yapıları',
        preview: 'Ali çay içer.',
        textLines: ['Ali çay içer.', 'Baba börek alır.', 'Oya çiçek toplar.', 'Lale su verir.', 'Anne yemek yapar.'],
        durationMinutes: 10,
      ),
      _ReadingLevel(
        id: '5',
        levelNumber: 5,
        title: '5. Seviye',
        description: 'Kısa Okuma Paragrafları',
        preview: 'Ali bahçede oynar.',
        textLines: [
          'Ali bahçede oynar.',
          'Oya çiçek toplar.',
          'Baba çay içer.',
          'Anne yemek yapar.',
          'Hep birlikte mutlular.',
        ],
        durationMinutes: 15,
      ),
    ];
  }

  /// Seviye açıklamasını getir (kademeli zorluk mantığı)
  String _getLevelDescription(int levelNumber) {
    switch (levelNumber) {
      case 1:
        return 'Sesler ve Kolay Heceler';
      case 2:
        return 'Basit Kelimeler ve Birleştirmeler';
      case 3:
        return 'Basit Cümleler';
      case 4:
        return 'Karmaşık Cümle Yapıları';
      case 5:
        return 'Kısa Okuma Paragrafları';
      default:
        return 'Okuma Metni';
    }
  }

  /// İçerik önizlemesini getir
  String _getContentPreview(Activity activity) {
    if (activity.textLines != null && activity.textLines!.isNotEmpty) {
      final firstLine = activity.textLines!.first.trim();
      if (firstLine.length > 30) {
        return '${firstLine.substring(0, 27)}...';
      }
      return firstLine;
    }
    return activity.title;
  }

  /// Seviyenin açık olup olmadığını kontrol et (kilit sistemi)
  bool _isLevelUnlocked(int index) {
    // İlk seviye her zaman açık
    if (index == 0) return true;
    
    // Önceki seviye tamamlanmışsa bu seviye açık
    if (index > 0 && index < _levels.length) {
      final previousLevel = _levels[index - 1];
      return _completedLevelIds.contains(previousLevel.id);
    }
    
    return false;
  }

  /// Seviyenin tamamlanıp tamamlanmadığını kontrol et
  bool _isLevelCompleted(String levelId) {
    return _completedLevelIds.contains(levelId);
  }

  /// Seviye durumuna göre renk getir
  Color _getLevelColor(int index, bool isUnlocked, bool isCompleted) {
    if (isCompleted) {
      return const Color(0xFF4CAF50); // Tamamlandı - Parlak Yeşil
    } else if (!isUnlocked) {
      return Colors.grey; // Kilitli - Gri
    } else {
      // Aktif seviye - Turuncu/Canlı renk
      return const Color(0xFFFF9800);
    }
  }

  /// Okuma moduna geç
  void _startReading(_ReadingLevel level) {
    setState(() {
      _isReadingMode = true;
      _currentLevel = level;
      _currentSyllableIndex = 0;
      _syllables = level.textLines;
      _readingStartTime = DateTime.now(); // Okuma başlangıç zamanını kaydet
    });
  }

  /// Sonraki heceye geç
  void _nextSyllable() {
    if (_currentSyllableIndex < _syllables.length - 1) {
      setState(() {
        _currentSyllableIndex++;
      });
    } else {
      // Son hecedeyiz, seviyeyi tamamla
      _completeLevel();
    }
  }

  /// Seviyeyi tamamla
  void _completeLevel() {
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;
    
    if (selectedStudent != null && _currentLevel != null) {
      // Okuma süresini hesapla
      final durationSeconds = _readingStartTime != null
          ? DateTime.now().difference(_readingStartTime!).inSeconds
          : 0;
      
      // Seviyeyi tamamlandı olarak kaydet (kilit sistemi için)
      _progressService.markReadingTextCompleted(
        studentId: selectedStudent.id,
        readingTextId: _currentLevel!.id,
      );
      
      // İstatistik sistemine kaydet (süre ve etkinlik bilgisi)
      _sessionService.addReadingText(
        studentId: selectedStudent.id,
        readingTextId: _currentLevel!.id,
        readingTextTitle: '${_currentLevel!.levelNumber}. Seviye - ${_currentLevel!.description}',
        durationSeconds: durationSeconds,
        wordCount: _syllables.length, // Hece/kelime sayısı
      );
      
      setState(() {
        _completedLevelIds.add(_currentLevel!.id);
      });
    }
    
    // Tamamlama dialogu göster
    _showCompletionDialog();
  }

  /// Tamamlama dialogu
  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF344955),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '🎉 Tebrikler!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '${_currentLevel?.levelNumber}. Seviyeyi tamamladınız!',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          Row(
            children: [
              // Sonraki seviyeye geç butonu
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _goToNextLevel();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Sonraki Seviye',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Ana ekrana dön butonu
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _exitReadingMode();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Ana Ekrana Dön',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sonraki seviyeye geç
  void _goToNextLevel() {
    if (_currentLevel != null) {
      final currentIndex = _levels.indexWhere((l) => l.id == _currentLevel!.id);
      if (currentIndex < _levels.length - 1) {
        _startReading(_levels[currentIndex + 1]);
      } else {
        // Son seviyeydi, ana ekrana dön
        _exitReadingMode();
      }
    }
  }

  /// Okuma modundan çık
  void _exitReadingMode() {
    setState(() {
      _isReadingMode = false;
      _currentLevel = null;
      _currentSyllableIndex = 0;
      _syllables = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arka plan - Deep Purple gradient (Glassmorphism için)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF4A00E0), // Deep Purple açık
                  const Color(0xFF8E2DE2), // Deep Purple orta
                  const Color(0xFF4A148C), // Deep Purple koyu
                ],
              ),
            ),
            child: Stack(
              children: [
                // Yıldızlar ve gezegenler arka plan
                _buildBackgroundDecorations(),
              ],
            ),
          ),
          // Ana içerik
          SafeArea(
            child: _isReadingMode
                ? _buildReadingMode()
                : _buildLevelsListMode(),
          ),
        ],
      ),
    );
  }

  /// Seviye listesi modu
  Widget _buildLevelsListMode() {
    return Column(
      children: [
        // Header
        _buildAppHeader(),
        // Body
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : _errorMessage != null
                  ? _buildErrorState()
                  : _levels.isEmpty
                      ? _buildEmptyState()
                      : _buildLevelsList(),
        ),
      ],
    );
  }

  /// Okuma modu - Tek tek hece gösterimi
  Widget _buildReadingMode() {
    final currentSyllable = _syllables.isNotEmpty && _currentSyllableIndex < _syllables.length
        ? _syllables[_currentSyllableIndex]
        : '';
    final progress = _syllables.isNotEmpty
        ? (_currentSyllableIndex + 1) / _syllables.length
        : 0.0;

    return Column(
      children: [
        // Okuma modu header
        _buildReadingHeader(),
        // Ana içerik
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF344955),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hece gösterimi
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      child: Text(
                        currentSyllable,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Progress bar
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Progress text
                    Text(
                      '${_currentSyllableIndex + 1}/${_syllables.length} hece tamamlandı',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Sonraki heceye geç butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextSyllable,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentSyllableIndex < _syllables.length - 1
                                  ? 'Sonraki Heceye Geç'
                                  : 'Seviyeyi Tamamla',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Okuma modu header
  Widget _buildReadingHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 12,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Row(
        children: [
          // Geri butonu
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _exitReadingMode,
          ),
          const SizedBox(width: 8),
          // Başlık
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_currentLevel?.levelNumber}. Seviye',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _currentLevel?.description ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// App Header
  Widget _buildAppHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 12,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Row(
        children: [
          // Geri butonu
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          // Başlık
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Kademeli Zorluk Sistemi',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Seviyeler listesi (Glassmorphism tasarım)
  Widget _buildLevelsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        // Glassmorphism ana kapsayıcı
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _levels.length,
            itemBuilder: (context, index) {
              return _buildLevelCard(_levels[index], index);
            },
          ),
        ),
      ),
    );
  }

  /// Seviye kartı (Glassmorphism, kilit sistemi)
  Widget _buildLevelCard(_ReadingLevel level, int index) {
    final isUnlocked = _isLevelUnlocked(index);
    final isCompleted = _isLevelCompleted(level.id);
    final levelColor = _getLevelColor(index, isUnlocked, isCompleted);

    return GestureDetector(
      onTap: isUnlocked ? () => _startReading(level) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Glassmorphism efekti
          color: isUnlocked
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFF4CAF50).withValues(alpha: 0.6) // Parlak Yeşil
                : isUnlocked
                    ? levelColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
            width: isCompleted || isUnlocked ? 2 : 1,
          ),
          boxShadow: isUnlocked && !isCompleted
              ? [
                  BoxShadow(
                    color: levelColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Row(
              children: [
                // Sol: Seviye numarası ve durum ikonu
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: isUnlocked
                        ? LinearGradient(
                            colors: [
                              levelColor,
                              levelColor.withValues(alpha: 0.7),
                            ],
                          )
                        : null,
                    color: isUnlocked ? null : Colors.grey[700],
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: levelColor.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 30,
                          )
                        : !isUnlocked
                            ? Icon(
                                Icons.lock,
                                color: Colors.grey[400],
                                size: 26,
                              )
                            : Text(
                                '${level.levelNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: 16),
                // Sağ: İçerik
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Seviye başlığı
                      Text(
                        '${level.levelNumber}. Seviye',
                        style: TextStyle(
                          color: isUnlocked
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Seviye açıklaması
                      Text(
                        level.description,
                        style: TextStyle(
                          color: isUnlocked
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.4),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Hece sayısı
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${level.textLines.length} hece/kelime',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Durum ikonu (sağda)
                const SizedBox(width: 8),
                if (isCompleted)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Color(0xFF4CAF50),
                      size: 22,
                    ),
                  )
                else if (isUnlocked)
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 20,
                  ),
              ],
            ),
            // Kilit overlay
            if (!isUnlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
              left: 50.0 + 35.0 * math.sin(time * 1.2),
              bottom: 100.0 + 40.0 * math.cos(time * 1.2),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.pink.withValues(alpha: 0.5),
                      Colors.red.withValues(alpha: 0.3),
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

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz okuma metni eklenmemiş',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadLevels,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4A00E0),
              ),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Okuma seviyesi veri modeli
class _ReadingLevel {
  final String id;
  final int levelNumber;
  final String title;
  final String description;
  final String preview;
  final List<String> textLines;
  final int durationMinutes;

  _ReadingLevel({
    required this.id,
    required this.levelNumber,
    required this.title,
    required this.description,
    required this.preview,
    required this.textLines,
    required this.durationMinutes,
  });
}
