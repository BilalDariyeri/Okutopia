import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/statistics_service.dart';
import '../models/category_model.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/student_selection_provider.dart';
import '../providers/content_provider.dart';
import '../services/current_session_service.dart';
import 'groups_screen.dart';
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
  String? _studentId; // dispose() için saklanıyor (context'e ihtiyaç duymadan kullanmak için)
  

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
    
    _initializeSession();
    // Cache-first: Provider'dan kategorileri yükle (anında gösterir)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategoriesFromProvider();
    });
  }

  @override
  void dispose() {
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
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;
    
    if (selectedStudent == null) return;
    
    // dispose() için studentId'yi sakla
    _studentId = selectedStudent.id;

    try {
      // Oturum başlat
      final result = await _statisticsService.startSession(selectedStudent.id);
      if (!mounted) return;
      if (result['success'] == true && result['session'] != null) {
        // İstatistikleri yükle (bugünkü süre için)
        await _loadStatistics(selectedStudent.id);
      }
    } catch (e) {
      debugPrint('Oturum başlatma hatası: $e');
    }
  }

  Future<void> _loadStatistics(String studentId) async {
    try {
      await _statisticsService.getStudentStatistics(studentId);
      if (!mounted) return;
      // İstatistikler yüklendi, ActivityTimer otomatik başlayacak
    } catch (e) {
      debugPrint('İstatistik yükleme hatası: $e');
    }
  }

  // ActivityTimer callback - süre güncellendiğinde çağrılır
  void _onTimerUpdate(Duration duration, bool isRunning) {
    if (!mounted) return;
    
    // CurrentSessionService'e güncelle
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;
    if (selectedStudent != null) {
      _sessionService.updateSessionTotalDuration(selectedStudent.id, duration);
    }
  }

  Future<void> _endSessionOnDispose() async {
    // dispose() içinde context kullanılamaz, bu yüzden saklanan _studentId'yi kullan
    final studentId = _studentId;
    
    if (studentId == null) return;

    try {
      // Sadece oturumu bitir, email gönderme işlemi öğretmen tarafından yapılacak
      await _statisticsService.endSession(studentId);
    } catch (e) {
      debugPrint('Oturum bitirme hatası: $e');
    }
  }

  /// Cache-First: Provider'dan kategorileri yükle (Zero-Loading UI)
  Future<void> _loadCategoriesFromProvider() async {
    if (!mounted) return;
    
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    
    // Provider'dan cache'lenmiş veriyi kontrol et
    if (contentProvider.categories != null && contentProvider.categories!.isNotEmpty) {
      // Cache'de veri var, anında göster (loading yok!)
      setState(() {
        _errorMessage = null;
      });
      // Arka planda refresh yapılacak (Provider içinde)
      return;
    }
    
    // Cache yoksa yükle (ilk açılış)
    try {
      await contentProvider.loadCategories();
      if (!mounted) return;
      setState(() {
        _errorMessage = null;
      });
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
      setState(() {
        _errorMessage = errorMsg;
      });
    }
  }

  Color _getCategoryColor(int index) {
    return _categoryColors[index % _categoryColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false); // listen: false - gereksiz rebuild'i önle
    final contentProvider = Provider.of<ContentProvider>(context, listen: false); // listen: false - sadece veri okuma için
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;
    
    // Cache-First: Provider'dan kategorileri al (anında gösterilir)
    final categories = contentProvider.categories ?? [];

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
            child: _errorMessage != null
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
                              onPressed: _loadCategoriesFromProvider,
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
                            expandedHeight: 180,
                            floating: false,
                            pinned: false,
                            snap: false,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            flexibleSpace: FlexibleSpaceBar(
                              background: _buildTopHeader(selectedStudent, authProvider),
                            ),
                          ),
                          // Ana içerik - Cache-First: Anında gösterilir
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: MediaQuery.of(context).size.width * 0.04, // Responsive padding (~12-16px)
                              vertical: MediaQuery.of(context).size.height * 0.02, // Responsive padding (~16px)
                            ),
                            sliver: categories.isEmpty
                                ? SliverToBoxAdapter(
                                    child: contentProvider.isRefreshingCategories
                                        ? _buildSkeletonLoading()
                                        : _buildEmptyState(),
                                  )
                                : SliverGrid(
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3, // 3 sütun (web sitesindeki gibi)
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: MediaQuery.of(context).size.width < 400 ? 0.8 : 0.85, // Küçük ekranlarda daha kompakt
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        return _buildCategoryCard(categories[index], index);
                                      },
                                      childCount: categories.length,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
        children: [
          // Üst satır: Geri ok ve başlık
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
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
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'İçindekiler',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Öğrenci bilgisi - Üst satır
          if (selectedStudent != null)
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedStudent.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Consumer<UserProfileProvider>(
                        builder: (context, userProfileProvider, _) => Text(
                          userProfileProvider.classroom?.name ?? 'Sınıf',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
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
          const SizedBox(height: 2),
          // Timer ve Öğrenci Değiştir butonu - Alt satır (sağa hizalı)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Kompakt Timer Widget - ActivityTimer yerine
              _CompactTimerWidget(
                onTimerUpdate: _onTimerUpdate,
              ),
              const SizedBox(width: 4),
              // Öğrenci Değiştir butonu
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/student-selection');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71), // Yeşil
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  minimumSize: const Size(0, 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, size: 11),
                label: const Text(
                  'Öğrenci Değiştir',
                  style: TextStyle(
                    fontSize: 9,
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

  /// Skeleton Loading (CircularProgressIndicator yerine)
  Widget _buildSkeletonLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: MediaQuery.of(context).size.width < 400 ? 0.8 : 0.85, // Küçük ekranlarda daha kompakt
        ),
        itemCount: 6, // 6 skeleton kart göster
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(5),
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
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.08), // Responsive padding (~30px)
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16), // Standart BorderRadius
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.category_outlined,
            size: MediaQuery.of(context).size.width * 0.15, // Responsive icon size (~56px)
            color: Colors.white.withValues(alpha: 0.5),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02), // Responsive spacing (~16px)
          Text(
            'Henüz kategori eklenmemiş',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: MediaQuery.of(context).size.width * 0.04, // Responsive font size (~14-15px)
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
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
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.035), // Responsive padding (~10-14px)
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C), // Koyu gri (web sitesindeki gibi)
            borderRadius: BorderRadius.circular(16), // Standart BorderRadius
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Kategori İkonu - Responsive boyutlandırma
              Container(
                width: MediaQuery.of(context).size.width * 0.11, // ~44px küçük ekranlarda
                height: MediaQuery.of(context).size.width * 0.11,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12), // Standart BorderRadius
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: MediaQuery.of(context).size.width * 0.055, // ~22px küçük ekranlarda
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.012), // Responsive spacing (~8px)
              // Kategori İsmi
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
                Navigator.of(context).pushNamed('/statistics');
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
          // Notlar
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushNamed('/teacher-notes');
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_outlined,
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
                Navigator.of(context).pushNamed('/teacher-profile');
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

/// Kompakt Timer Widget - ActivityTimer yerine kullanılan küçük versiyon
class _CompactTimerWidget extends StatefulWidget {
  final void Function(Duration duration, bool isRunning)? onTimerUpdate;

  const _CompactTimerWidget({
    this.onTimerUpdate,
  });

  @override
  State<_CompactTimerWidget> createState() => _CompactTimerWidgetState();
}

class _CompactTimerWidgetState extends State<_CompactTimerWidget>
    with WidgetsBindingObserver {
  Timer? _timer;
  Duration _elapsedDuration = Duration.zero;
  bool _isRunning = true;
  bool _isPaused = false;
  Duration _pausedDuration = Duration.zero;
  DateTime? _lastResumeTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastResumeTime = DateTime.now();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        if (_isRunning && !_isPaused) {
          _pauseTimer();
        }
        break;
      case AppLifecycleState.resumed:
        if (!_isRunning && !_isPaused) {
          _resumeTimer();
        }
        break;
      default:
        break;
    }
  }

  void _startTimer() {
    _isRunning = true;
    _isPaused = false;
    _lastResumeTime = DateTime.now();
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_isRunning && !_isPaused) {
        setState(() {
          if (_lastResumeTime != null) {
            final now = DateTime.now();
            final sessionDuration = now.difference(_lastResumeTime!);
            _elapsedDuration = _pausedDuration + sessionDuration;
          }
        });
        
        widget.onTimerUpdate?.call(_elapsedDuration, _isRunning);
      }
    });
  }

  void _pauseTimer() {
    if (!_isRunning || _isPaused) return;
    
    setState(() {
      _isPaused = true;
      if (_lastResumeTime != null) {
        final now = DateTime.now();
        final sessionDuration = now.difference(_lastResumeTime!);
        _pausedDuration = _pausedDuration + sessionDuration;
      }
    });
    
    widget.onTimerUpdate?.call(_elapsedDuration, false);
  }

  void _resumeTimer() {
    if (_isRunning && !_isPaused) return;
    
    setState(() {
      _isPaused = false;
      _lastResumeTime = DateTime.now();
    });
    
    widget.onTimerUpdate?.call(_elapsedDuration, true);
  }

  void _toggleTimer() {
    if (_isPaused) {
      _resumeTimer();
    } else {
      _pauseTimer();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isPaused ? const Color(0xFF95A5A6) : const Color(0xFF4ECDC4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDuration(_elapsedDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _toggleTimer,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _isPaused ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPaused ? Icons.play_arrow : Icons.pause,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

