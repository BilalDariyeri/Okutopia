import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import '../services/content_service.dart';
import '../services/statistics_service.dart';
import '../services/current_session_service.dart';
import '../models/category_model.dart';
import '../providers/auth_provider.dart';
import 'groups_screen.dart';
import 'statistics_screen.dart';
import 'teacher_notes_screen.dart';
import '../widgets/activity_timer.dart';
import 'package:provider/provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with TickerProviderStateMixin {
  final ContentService _contentService = ContentService();
  final StatisticsService _statisticsService = StatisticsService();
  final CurrentSessionService _sessionService = CurrentSessionService();
  final ScrollController _scrollController = ScrollController();
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Süre takibi
  DateTime? _sessionStartTime;
  Duration _sessionDuration = Duration.zero;
  Timer? _timer;

  // Renk paleti (görseldeki renklere göre)
  final List<Color> _categoryColors = [
    const Color(0xFF3498DB), // Mavi (Harf Grupları)
    const Color(0xFFE91E63), // Pembe (Kademeli Öğrenme, Okuma Metinleri)
    const Color(0xFF9B59B6), // Mor (Görsel Dikkat, Öğretmen Notları)
    const Color(0xFFF39C12), // Turuncu (Çizgi Çalışmaları)
  ];
  
  // Kategori ikonları (görseldeki ikonlara göre)
  final List<IconData> _categoryIcons = [
    Icons.view_column, // Harf Grupları - dikey çubuklar
    Icons.view_agenda, // Kademeli Öğrenme - yatay çubuklar
    Icons.article, // Okuma Metinleri - yatay çubuklar
    Icons.center_focus_strong, // Görsel Dikkat - hedef
    Icons.note, // Öğretmen Notları - yatay çubuklar
    Icons.draw, // Çizgi Çalışmaları - yatay çubuklar
  ];

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
    
    _loadCategories();
    _initializeSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    _planet1Controller.dispose();
    _planet2Controller.dispose();
    _planet3Controller.dispose();
    _planet4Controller.dispose();
    // Async işlemi await etmeden başlat (dispose async olamaz)
    _endSessionOnDispose();
    super.dispose();
  }

  Future<void> _initializeSession() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final selectedStudent = authProvider.selectedStudent;
    
    if (selectedStudent == null) return;

    try {
      // Oturum başlat
      final result = await _statisticsService.startSession(selectedStudent.id);
      if (!mounted) return;
      if (result['success'] == true && result['session'] != null) {
        setState(() {
          _sessionStartTime = DateTime.parse(result['session']['startTime']);
          _sessionDuration = Duration.zero;
        });
        
        // Timer başlat
        _startTimer();
      }
    } catch (e) {
      debugPrint('Oturum başlatma hatası: $e');
      // Hata olsa bile timer'ı başlat (local tracking)
      _sessionStartTime = DateTime.now();
      _startTimer();
    }
  }


  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_sessionStartTime != null) {
        setState(() {
          _sessionDuration = DateTime.now().difference(_sessionStartTime!);
        });
      }
    });
  }

  Future<void> _endSessionOnDispose() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final selectedStudent = authProvider.selectedStudent;
    
    if (selectedStudent == null) return;

    try {
      // Oturum verilerini hazırla (lastSessionStats güncellemesi için)
      final sessionService = CurrentSessionService();
      final sessionActivities = sessionService.getSessionActivities(selectedStudent.id);
      final totalDuration = sessionService.getSessionTotalDuration(selectedStudent.id);
      
      // Oturum aktivitelerini formatla
      final sessionActivitiesData = sessionActivities.map((activity) {
        return {
          'activityId': activity.activityId,
          'activityTitle': activity.activityTitle,
          'durationSeconds': activity.durationSeconds,
          'successStatus': activity.successStatus,
          'completedAt': activity.completedAt.toIso8601String(),
        };
      }).toList();
      
      // Oturumu bitir ve lastSessionStats'ı güncelle
      await _statisticsService.endSession(
        selectedStudent.id,
        sessionActivities: sessionActivitiesData,
        totalDurationSeconds: totalDuration.inSeconds,
      );
      
      debugPrint('✅ Oturum bitirildi ve lastSessionStats güncellendi');
    } catch (e) {
      debugPrint('❌ Oturum bitirme hatası: $e');
    }
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _contentService.getAllCategories();
      if (!mounted) return;

      setState(() {
        _categories = response.categories;
        _isLoading = false;
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
          errorMsg = 'Kategoriler bulunamadı.';
        }
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  Color _getCategoryColor(int index) {
    return _categoryColors[index % _categoryColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final selectedStudent = authProvider.selectedStudent;

    return Scaffold(
      body: Stack(
        children: [
          // Arka plan
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF6C5CE7), // Açık mor
                  const Color(0xFF4834D4), // Orta mor
                  const Color(0xFF2D1B69), // Koyu mor
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _loadCategories,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF4834D4),
                              ),
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
                      )
                    : CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          // Üst Header (Pembe gradient bar) - Scroll'da gizlenir
                          SliverAppBar(
                            expandedHeight: 200,
                            floating: false,
                            pinned: false,
                            snap: false,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            flexibleSpace: FlexibleSpaceBar(
                              background: _buildTopHeader(selectedStudent, authProvider),
                            ),
                          ),
                          // Ana içerik
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            sliver: _categories.isEmpty
                                ? SliverToBoxAdapter(child: _buildEmptyState())
                                : SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3, // 3 sütun (web sitesindeki gibi)
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.85, // Kartlar daha kare
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        return _buildCategoryCard(_categories[index], index);
                                      },
                                      childCount: _categories.length,
                                    ),
                                  ),
                          ),
                          // Alt navigasyon için boşluk
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 70),
                          ),
                        ],
                      ),
          ),
          // Alt navigasyon bar (sabit)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNavigation(),
          ),
        ],
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
        // Gezegenler (optimize edilmiş)
        AnimatedBuilder(
          key: const ValueKey('planet1'),
          animation: _planet1Controller,
          builder: (context, child) {
            final time = _planet1Controller.value * 2 * math.pi;
            final baseX = -50.0;
            final baseY = 50.0;
            final radiusX = 25.0;
            final radiusY = 35.0;
            
            return Positioned(
              left: baseX + radiusX * math.sin(time),
              top: baseY + radiusY * math.cos(time),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
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
            final screenWidth = MediaQuery.of(context).size.width;
            final baseX = screenWidth + 30.0;
            final baseY = 100.0;
            final radiusX = 30.0;
            final radiusY = 45.0;
            
            return Positioned(
              right: screenWidth - (baseX - radiusX * math.sin(time * 0.8)),
              top: baseY + radiusY * math.cos(time * 0.8),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.yellow.withValues(alpha: 0.3),
                      blurRadius: 25,
                      spreadRadius: 4,
                    ),
                  ],
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
            final screenHeight = MediaQuery.of(context).size.height;
            final baseX = 50.0;
            final baseY = screenHeight - 100.0;
            final radiusX = 35.0;
            final radiusY = 40.0;
            
            return Positioned(
              left: baseX + radiusX * math.sin(time * 1.2),
              bottom: screenHeight - (baseY - radiusY * math.cos(time * 1.2)),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
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
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final baseX = screenWidth - 20.0;
            final baseY = screenHeight - 150.0;
            final radiusX = 25.0;
            final radiusY = 45.0;
            
            return Positioned(
              right: screenWidth - (baseX - radiusX * math.sin(time * 0.9)),
              bottom: screenHeight - (baseY - radiusY * math.cos(time * 0.9)),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.cyan.withValues(alpha: 0.5),
                      Colors.blue.withValues(alpha: 0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopHeader(selectedStudent, AuthProvider authProvider) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFE91E63), // Pembe
              const Color(0xFFAD1457), // Koyu pembe
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst satır: Geri ok, başlık ve Timer
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacementNamed('/student-selection');
                    }
                  },
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'İçindekiler',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                // Sağ üstte ActivityTimer
                ActivityTimer(
                  initialDuration: _sessionDuration,
                  onTimerUpdate: (duration, isRunning) {
                    // Timer süresini CurrentSessionService'e kaydet
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final selectedStudent = authProvider.selectedStudent;
                    if (selectedStudent != null) {
                      _sessionService.updateSessionTotalDuration(selectedStudent.id, duration);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Alt başlık
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'Eğitim materyallerine kolayca erişin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Öğrenci bilgisi
            if (selectedStudent != null)
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE91E63),
                          const Color(0xFFAD1457),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        selectedStudent.firstName.isNotEmpty
                            ? selectedStudent.firstName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedStudent.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authProvider.classroom?.name ?? 'Sınıf',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Öğrenci Değiştir butonu (daha küçük)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/student-selection');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71), // Yeşil
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 12),
                    label: const Text(
                      'Değiştir',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz kategori eklenmemiş',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCategoryCard(Category category, int index) {
    final color = _getCategoryColor(index);
    final icon = _categoryIcons[index % _categoryIcons.length];

    return GestureDetector(
      onTap: () {
        // Kategori seçildiğinde gruplar ekranına git
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GroupsScreen(category: category),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C), // Koyu gri (web sitesindeki gibi)
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Kategori İkonu (kare, renkli - web sitesindeki gibi büyük)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            // Kategori İsmi (web sitesindeki gibi)
            Text(
              category.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Alt başlık (varsa - örn: "hece-kelime-cümle")
            if (category.description != null && category.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                category.description!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Ana Sayfa (aktif - pembe gradient)
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Zaten bu sayfadayız
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE91E63),
                      const Color(0xFFAD1457),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.home,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ana Sayfa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // İstatistikler
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const StatisticsScreen(),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'İstatistikler',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Öğretmen Notları
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TeacherNotesScreen(),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Notlar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Profil
          Expanded(
            child: GestureDetector(
              onTap: () {
                // TODO: Profil ekranına git
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Profil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

