import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/statistics_service.dart';
import '../models/category_model.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/student_selection_provider.dart';
import '../providers/content_provider.dart';
import '../widgets/activity_timer.dart';
import '../services/current_session_service.dart';
import 'groups_screen.dart';
import 'letter_groups_screen.dart';
import 'reading_texts_selection_screen.dart';
import 'reading_development_screen.dart';
import 'package:provider/provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with TickerProviderStateMixin {
  final StatisticsService _statisticsService = StatisticsService();
  final CurrentSessionService _sessionService = CurrentSessionService();
  final ScrollController _scrollController = ScrollController();
  String? _errorMessage;
  String? _studentId;
  

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

  // Animasyon controller'ları (uzay teması için)
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
    
    // Cache-first: Provider'dan kategorileri yükle (anında gösterir - öncelikli)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategoriesFromProvider();
    });
    
    // Session ve statistics işlemlerini arka plana al (non-blocking)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _initializeSession();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _planet1Controller.dispose();
    _planet2Controller.dispose();
    _planet3Controller.dispose();
    _planet4Controller.dispose();
    _endSessionOnDispose();
    super.dispose();
  }

  Future<void> _initializeSession() async {
    if (!mounted) return;
    
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;
    
    if (selectedStudent == null) return;
    
    _studentId = selectedStudent.id;

    try {
      final result = await _statisticsService.startSession(selectedStudent.id)
          .timeout(const Duration(seconds: 3), onTimeout: () {
        return {'success': false};
      });
      
      if (!mounted) return;
      
      if (result['success'] == true && result['session'] != null) {
        _loadStatistics(selectedStudent.id);
      }
    } catch (e) {
      debugPrint('Oturum başlatma hatası: $e');
    }
  }

  Future<void> _loadStatistics(String studentId) async {
    if (!mounted) return;
    
    try {
      await _statisticsService.getStudentStatistics(studentId)
          .timeout(const Duration(seconds: 3));
      
      if (!mounted) return;
    } on TimeoutException {
      debugPrint('İstatistik yükleme timeout - sessizce devam ediliyor');
    } catch (e) {
      debugPrint('İstatistik yükleme hatası: $e');
    }
  }

  void _onTimerUpdate(Duration duration, bool isRunning) {
    if (!mounted) return;
    
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;
    if (selectedStudent != null) {
      _sessionService.updateSessionTotalDuration(selectedStudent.id, duration);
    }
  }

  Future<void> _endSessionOnDispose() async {
    final studentId = _studentId;
    
    if (studentId == null) return;

    try {
      await _statisticsService.endSession(studentId);
    } catch (e) {
      debugPrint('Oturum bitirme hatası: $e');
    }
  }

  Future<void> _loadCategoriesFromProvider() async {
    if (!mounted) return;
    
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    
    if (contentProvider.categories != null && contentProvider.categories!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
      return;
    }
    
    try {
      await contentProvider.loadCategories()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        return;
      });
      
      if (!mounted) return;
      
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
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
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
        });
      }
    }
  }

  Color _getCategoryColor(int index) {
    return _categoryColors[index % _categoryColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;
    
    final categories = contentProvider.categories ?? [];

    return Scaffold(
      body: Stack(
        children: [
          // Uzay temalı arka plan - Deep Purple gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF4A00E0), // Deep Purple açık
                  const Color(0xFF8E2DE2), // Deep Purple orta
                  const Color(0xFF2D1B69), // Deep Purple koyu
                ],
              ),
            ),
            child: Stack(
              children: [
                // Yıldızlar ve gezegenler
                _buildBackgroundDecorations(),
              ],
            ),
          ),
          // Ana içerik
          SafeArea(
            child: _errorMessage != null
                    ? _buildErrorState()
                    : Column(
                        children: [
                          // Üst Header
                          _buildTopHeader(selectedStudent, authProvider),
                          // Kategoriler Grid
                          Expanded(
                            child: categories.isEmpty
                                ? (contentProvider.isRefreshingCategories
                                    ? _buildSkeletonLoading()
                                    : _buildEmptyState())
                                : _buildCategoriesGrid(categories),
                          ),
                        ],
                      ),
          ),
          // Alt navigasyon bar
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

  /// Uzay temalı arka plan dekorasyonları
  Widget _buildBackgroundDecorations() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Stack(
      children: [
        // Yıldızlar
        ...List.generate(40, (index) {
          return Positioned(
            key: ValueKey('star_$index'),
            left: (index * 37.7) % screenWidth,
            top: (index * 23.3) % screenHeight,
            child: Container(
              width: 2 + (index % 4 == 0 ? 1.5 : 0),
              height: 2 + (index % 4 == 0 ? 1.5 : 0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7 + (index % 3) * 0.1),
                shape: BoxShape.circle,
                boxShadow: index % 5 == 0 ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.4),
                    blurRadius: 3,
                    spreadRadius: 1,
                  ),
                ] : null,
              ),
            ),
          );
        }),
        // Gezegen 1 (Turuncu - sol üst)
        AnimatedBuilder(
          key: const ValueKey('planet1'),
          animation: _planet1Controller,
          builder: (context, child) {
            final time = _planet1Controller.value * 2 * math.pi;
            return Positioned(
              left: -60.0 + 30.0 * math.sin(time),
              top: 80.0 + 40.0 * math.cos(time),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.deepOrange.withValues(alpha: 0.6),
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
        // Gezegen 2 (Sarı - sağ üst)
        AnimatedBuilder(
          key: const ValueKey('planet2'),
          animation: _planet2Controller,
          builder: (context, child) {
            final time = _planet2Controller.value * 2 * math.pi;
            return Positioned(
              right: -30.0 + 35.0 * math.sin(time * 0.8),
              top: 150.0 + 50.0 * math.cos(time * 0.8),
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.6),
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
        // Gezegen 3 (Pembe - sol alt)
        AnimatedBuilder(
          key: const ValueKey('planet3'),
          animation: _planet3Controller,
          builder: (context, child) {
            final time = _planet3Controller.value * 2 * math.pi;
            return Positioned(
              left: 30.0 + 40.0 * math.sin(time * 1.2),
              bottom: 120.0 + 45.0 * math.cos(time * 1.2),
              child: Container(
                width: 90,
                height: 90,
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
        // Gezegen 4 (Cyan - sağ alt)
        AnimatedBuilder(
          key: const ValueKey('planet4'),
          animation: _planet4Controller,
          builder: (context, child) {
            final time = _planet4Controller.value * 2 * math.pi;
            return Positioned(
              right: 20.0 + 30.0 * math.sin(time * 0.9),
              bottom: 180.0 + 35.0 * math.cos(time * 0.9),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE91E63).withValues(alpha: 0.9), // Pembe
            const Color(0xFF9C27B0).withValues(alpha: 0.85), // Mor
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Geri butonu
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacementNamed('/student-selection');
                }
              },
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          // Öğrenci bilgisi
          if (selectedStudent != null)
            Expanded(
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.3),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        selectedStudent.firstName.isNotEmpty
                            ? selectedStudent.firstName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // İsim ve sınıf
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedStudent.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Consumer<UserProfileProvider>(
                          builder: (context, userProfileProvider, _) => Text(
                            userProfileProvider.classroom?.name ?? 'Sınıf',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          // Timer
          ActivityTimer(
            onTimerUpdate: _onTimerUpdate,
          ),
          const SizedBox(width: 8),
          // Öğrenci Değiştir butonu
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2ECC71),
                  const Color(0xFF27AE60),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.of(context).pushReplacementNamed('/student-selection');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.swap_horiz, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Değiştir',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid(List<Category> categories) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      child: Container(
        // Glassmorphism kapsayıcı
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return _buildCategoryCard(categories[index], index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Category category, int index) {
    final color = _getCategoryColor(index);
    final icon = _categoryIcons[index % _categoryIcons.length];

    return GestureDetector(
      onTap: () {
        final categoryNameLower = category.name.toLowerCase();
        
        if (categoryNameLower.contains('harf') || 
            categoryNameLower.contains('letter')) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => LetterGroupsScreen(category: category),
            ),
          );
        } 
        else if (categoryNameLower.contains('kademeli') || 
                 categoryNameLower.contains('öğrenme') ||
                 categoryNameLower.contains('ogrenme') ||
                 categoryNameLower.contains('progressive')) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ReadingTextsSelectionScreen(),
            ),
          );
        }
        else if (categoryNameLower.contains('okuma') || 
                 categoryNameLower.contains('reading') ||
                 categoryNameLower.contains('metin') ||
                 categoryNameLower.contains('geliştirme') ||
                 categoryNameLower.contains('gelistirme')) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ReadingDevelopmentScreen(category: category),
            ),
          );
        }
        else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GroupsScreen(category: category),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          // Glassmorphism kart
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Kategori İkonu
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            // Kategori İsmi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                category.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2D1B69).withValues(alpha: 0.95),
            const Color(0xFF1A0F40),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Ana Sayfa (aktif)
          _buildNavItem(
            icon: Icons.home_rounded,
            label: 'Ana Sayfa',
            isActive: true,
            onTap: () {},
          ),
          // İstatistikler
          _buildNavItem(
            icon: Icons.bar_chart_rounded,
            label: 'İstatistikler',
            isActive: false,
            onTap: () => Navigator.of(context).pushNamed('/statistics'),
          ),
          // Notlar
          _buildNavItem(
            icon: Icons.note_alt_rounded,
            label: 'Notlar',
            isActive: false,
            onTap: () => Navigator.of(context).pushNamed('/teacher-notes'),
          ),
          // Profil
          _buildNavItem(
            icon: Icons.person_rounded,
            label: 'Profil',
            isActive: false,
            onTap: () => Navigator.of(context).pushNamed('/teacher-profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: isActive
              ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFE91E63).withValues(alpha: 0.3),
                      const Color(0xFFE91E63).withValues(alpha: 0.1),
                    ],
                  ),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive 
                    ? const Color(0xFFE91E63) 
                    : Colors.white.withValues(alpha: 0.7),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive 
                      ? const Color(0xFFE91E63) 
                      : Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 32),
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
        margin: const EdgeInsets.symmetric(horizontal: 32),
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
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE91E63),
                    const Color(0xFF9C27B0),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _loadCategoriesFromProvider,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      'Tekrar Dene',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
