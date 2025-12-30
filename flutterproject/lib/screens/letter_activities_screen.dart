import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/content_service.dart';
import '../models/activity_model.dart';
import 'questions_screen.dart';

class LetterActivitiesScreen extends StatefulWidget {
  final String letter;
  final String letterUpper;

  const LetterActivitiesScreen({
    super.key,
    required this.letter,
    required this.letterUpper,
  });

  @override
  State<LetterActivitiesScreen> createState() => _LetterActivitiesScreenState();
}

class _LetterActivitiesScreenState extends State<LetterActivitiesScreen> with TickerProviderStateMixin {
  final ContentService _contentService = ContentService();
  final ScrollController _scrollController = ScrollController();
  List<Activity> _activities = [];
  bool _isLoading = true;
  String? _errorMessage;

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
    
    _loadActivities();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _planet1Controller.dispose();
    _planet2Controller.dispose();
    _planet3Controller.dispose();
    _planet4Controller.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Tüm kategorileri çek
      final categoriesResponse = await _contentService.getAllCategories();
      final allActivities = <Activity>[];
      
      // Her kategori için grupları çek
      for (var category in categoriesResponse.categories) {
        try {
          final groupsResponse = await _contentService.getGroupsByCategory(
            categoryId: category.id,
          );
          
          // Her grup için dersleri çek
          for (var group in groupsResponse.groups) {
            try {
              final lessonsResponse = await _contentService.getLessonsByGroup(
                groupId: group.id,
              );
              
              // Her ders için aktiviteleri çek
              for (var lesson in lessonsResponse.lessons) {
                try {
                  final activitiesResponse = await _contentService.getActivitiesByLesson(
                    lessonId: lesson.id,
                  );
                  
                  // Harfe göre filtreleme yap - Her harf için belirli aktiviteler
                  for (var activity in activitiesResponse.activities) {
                    final titleUpper = activity.title.toUpperCase();
                    final letterUpper = widget.letterUpper.toUpperCase();
                    final letterLower = widget.letter.toUpperCase();
                    
                    // ÖNCE "Sesi Hissetme" kontrolü yap - ÇOK GENİŞ KONTROL
                    // Admin panelinde "Sesi Hissetme" adında aktivite var, bunu kesinlikle göster
                    // "sesi hisset" ve "sesi hissetme" varyasyonlarını yakala
                    final isSesiHissetme = titleUpper == 'SESİ HİSSETME' ||
                        titleUpper.contains('SESİ HİSSETME') ||
                        titleUpper.contains('SES HİSSETME') ||
                        titleUpper.contains('SESİ HİSSET') ||
                        titleUpper.contains('SES HİSSET') ||
                        // "sesi hisset" (tam kelime)
                        titleUpper == 'SESİ HİSSET' ||
                        titleUpper == 'SES HİSSET' ||
                        // "1. grup harf" gibi ifadelerle birlikte olabilir
                        (titleUpper.contains('SESİ') && titleUpper.contains('HİSSETME')) ||
                        (titleUpper.contains('SES') && titleUpper.contains('HİSSETME')) ||
                        (titleUpper.contains('SESİ') && titleUpper.contains('HİSSET')) ||
                        (titleUpper.contains('SES') && titleUpper.contains('HİSSET')) ||
                        // Sadece "SES" veya "HİSSET" kelimeleri de olabilir
                        (titleUpper.contains('SES') && titleUpper.contains('GRUP')) ||
                        (titleUpper.contains('HİSSET') && titleUpper.contains('GRUP'));
                    
                    // Eğer "Sesi Hissetme" aktivitesi ise, harf kontrolü yap
                    if (isSesiHissetme) {
                      // "1. grup harf" kontrolü - eğer varsa, 1. grup harfleri için göster
                      final hasGroupHarf = titleUpper.contains('GRUP') && 
                          (titleUpper.contains('HARF') || titleUpper.contains('HARFİ') || titleUpper.contains('1'));
                      
                      // Eğer "1. grup harf" varsa, 1. grup harfleri için göster (a, n, e, t, i, l)
                      // NOT: B ve C artık 1. grupta değil, 4. grupta
                      if (hasGroupHarf) {
                        final firstGroupLetters = ['A', 'N', 'E', 'T', 'İ', 'I', 'L'];
                        if (firstGroupLetters.contains(letterUpper) || 
                            firstGroupLetters.contains(letterLower)) {
                          allActivities.add(activity);
                          continue;
                        }
                      }
                      
                      // "A Harfi Sesi Hissetme" gibi başlıklar için harf kontrolü
                      // ÇOK GENİŞ harf kontrolü - başlıkta harf geçiyorsa (herhangi bir yerde) kabul et
                      final hasLetter = titleUpper.contains(letterUpper) || 
                          titleUpper.contains(letterLower) ||
                          titleUpper.contains(' ${letterUpper} ') ||
                          titleUpper.contains(' ${letterLower} ') ||
                          titleUpper.startsWith('${letterUpper} ') ||
                          titleUpper.startsWith('${letterLower} ') ||
                          titleUpper.contains(' ${letterUpper} HARF') ||
                          titleUpper.contains(' ${letterLower} HARF') ||
                          titleUpper.contains(' ${letterUpper} HARFİ') ||
                          titleUpper.contains(' ${letterLower} HARFİ') ||
                          titleUpper.contains('${letterUpper} HARF') ||
                          titleUpper.contains('${letterLower} HARF') ||
                          titleUpper.contains('HARF ${letterUpper}') ||
                          titleUpper.contains('HARF ${letterLower}') ||
                          titleUpper.contains('HARFİ ${letterUpper}') ||
                          titleUpper.contains('HARFİ ${letterLower}') ||
                          // "A Harfi" formatı
                          titleUpper.contains('${letterUpper} HARFİ') ||
                          titleUpper.contains('${letterLower} HARFİ') ||
                          // Emoji kontrolü
                          (titleUpper.contains('🎵') && (titleUpper.contains(letterUpper) || titleUpper.contains(letterLower))) ||
                          (titleUpper.contains('🎶') && (titleUpper.contains(letterUpper) || titleUpper.contains(letterLower)));
                      
                      // Eğer harf varsa veya "1. grup harf" ise göster
                      if (hasLetter || hasGroupHarf) {
                        allActivities.add(activity);
                        continue;
                      }
                    }
                    
                    // Diğer ses aktiviteleri için kontrol (isSesiHissetme değilse)
                    if (!isSesiHissetme) {
                      final hasOtherSound = titleUpper.contains('SESİ HİSSET') ||
                          titleUpper.contains('SES HİSSET') ||
                          titleUpper.contains('HİSSETME') ||
                          titleUpper.contains('HİSSET') ||
                          titleUpper.contains('SESİ') ||
                          titleUpper.contains('SES') ||
                          titleUpper.contains('🎵') ||
                          titleUpper.contains('🎶') ||
                          (titleUpper.contains('SES') && titleUpper.contains('HİSSET')) ||
                          (titleUpper.contains('SESİ') && titleUpper.contains('HİSSET'));
                      
                      if (hasOtherSound) {
                      final hasLetter = titleUpper.contains(letterUpper) || 
                          titleUpper.contains(letterLower) ||
                          titleUpper.contains(' ${letterUpper} ') ||
                          titleUpper.contains(' ${letterLower} ') ||
                          titleUpper.startsWith('${letterUpper} ') ||
                          titleUpper.startsWith('${letterLower} ') ||
                          titleUpper.contains(' ${letterUpper} HARF') ||
                          titleUpper.contains(' ${letterLower} HARF') ||
                          titleUpper.contains(' ${letterUpper} HARFİ') ||
                          titleUpper.contains(' ${letterLower} HARFİ') ||
                          titleUpper.contains('${letterUpper} HARF') ||
                          titleUpper.contains('${letterLower} HARF') ||
                          titleUpper.contains('HARF ${letterUpper}') ||
                          titleUpper.contains('HARF ${letterLower}') ||
                          titleUpper.contains('HARFİ ${letterUpper}') ||
                          titleUpper.contains('HARFİ ${letterLower}') ||
                          (titleUpper.contains('GRUP') && (titleUpper.contains(letterUpper) || titleUpper.contains(letterLower))) ||
                          (titleUpper.contains('🎵') && (titleUpper.contains(letterUpper) || titleUpper.contains(letterLower))) ||
                          (titleUpper.contains('🎶') && (titleUpper.contains(letterUpper) || titleUpper.contains(letterLower)));
                      
                        if (hasLetter) {
                          allActivities.add(activity);
                          continue;
                        }
                      }
                    }
                    
                    // Normal filtreleme (sesi hissetme değilse)
                    // Aktivite başlığında harf var mı kontrol et (çok esnek - her türlü formatı yakala)
                    final hasLetter = titleUpper.contains(letterUpper) || 
                        titleUpper.contains(letterLower) ||
                        titleUpper.contains(' ${letterUpper} ') ||
                        titleUpper.contains(' ${letterLower} ') ||
                        titleUpper.startsWith('${letterUpper} ') ||
                        titleUpper.startsWith('${letterLower} ') ||
                        titleUpper.contains(' ${letterUpper} HARF') ||
                        titleUpper.contains(' ${letterLower} HARF') ||
                        titleUpper.contains(' ${letterUpper} HARFİ') ||
                        titleUpper.contains(' ${letterLower} HARFİ') ||
                        titleUpper.contains('${letterUpper} HARF') ||
                        titleUpper.contains('${letterLower} HARF') ||
                        titleUpper.contains('HARF ${letterUpper}') ||
                        titleUpper.contains('HARF ${letterLower}') ||
                        titleUpper.contains('HARFİ ${letterUpper}') ||
                        titleUpper.contains('HARFİ ${letterLower}') ||
                        // Emoji veya özel karakterlerle başlayan başlıklar için
                        (titleUpper.contains('🎵') && (titleUpper.contains(letterUpper) || titleUpper.contains(letterLower))) ||
                        (titleUpper.contains('🎶') && (titleUpper.contains(letterUpper) || titleUpper.contains(letterLower)));
                    
                    if (!hasLetter) continue;
                    
                    // Her harf için belirli aktiviteleri göster
                    bool shouldShow = false;
                    
                    // Aktivite tipi kontrolleri (çok esnek - tüm varyasyonları yakala)
                    final hasVisual = titleUpper.contains('GÖRSELDEN BULMA') ||
                        titleUpper.contains('GÖRSELDEN') ||
                        titleUpper.contains('GÖRSEL');
                    final hasLetterFind = titleUpper.contains('KELİMEDE BULMA') ||
                        titleUpper.contains('KELİMEDE HARF') ||
                        titleUpper.contains('KELİMEDE');
                    final hasWriting = titleUpper.contains('NASIL YAZILIR') ||
                        titleUpper.contains('YAZILIR') ||
                        titleUpper.contains('YAZ');
                    final hasSound = titleUpper.contains('SESİ HİSSETME') ||
                        titleUpper.contains('SES HİSSETME') ||
                        titleUpper.contains('SESİ HİSSET') ||
                        titleUpper.contains('SES HİSSET') ||
                        titleUpper.contains('HİSSETME') ||
                        titleUpper.contains('HİSSET') ||
                        (titleUpper.contains('SES') && titleUpper.contains('HİSSET'));
                    
                    if (letterUpper == 'A') {
                      // A harfi için: görselden bulma, kelimeden bulma, nasıl yazılır, sesi hissetme
                      shouldShow = hasVisual || hasLetterFind || hasWriting || hasSound;
                    } else if (letterUpper == 'B') {
                      // B harfi için: görselden bulma, kelimeden bulma, sesi hissetme, büyük b nasıl yazılır
                      final hasBigBWriting = (titleUpper.contains('BÜYÜK') && hasWriting) ||
                          (titleUpper.contains('BÜYÜK B') && titleUpper.contains('YAZ'));
                      shouldShow = hasVisual || hasLetterFind || hasBigBWriting;
                    } else if (letterUpper == 'C') {
                      // C harfi için: nasıl yazılır
                      shouldShow = hasWriting;
                    } else {
                      // Diğer harfler için tüm aktiviteleri göster
                      shouldShow = true;
                    }
                    
                    if (shouldShow) {
                      allActivities.add(activity);
                    }
                  }
                } catch (e) {
                  // Hata durumunda devam et
                  continue;
                }
              }
            } catch (e) {
              // Hata durumunda devam et
              continue;
            }
          }
        } catch (e) {
          // Hata durumunda devam et
          continue;
        }
      }
      
      setState(() {
        _activities = allActivities;
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
          errorMsg = 'Etkinlikler bulunamadı.';
        }
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  // Renk paleti
  final List<Color> _activityColors = [
    const Color(0xFF3498DB), // Mavi
    const Color(0xFFE91E63), // Pembe
    const Color(0xFF9B59B6), // Mor
    const Color(0xFFF39C12), // Turuncu
    const Color(0xFF2ECC71), // Yeşil
    const Color(0xFF1ABC9C), // Turkuaz
  ];

  Color _getActivityColor(int index) {
    return _activityColors[index % _activityColors.length];
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'Drawing':
        return Icons.draw;
      case 'Listening':
        return Icons.headphones;
      case 'Quiz':
        return Icons.quiz;
      case 'Visual':
        return Icons.visibility;
      default:
        return Icons.assignment;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                              onPressed: _loadActivities,
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
                          // Üst Header
                          SliverAppBar(
                            expandedHeight: 120,
                            floating: false,
                            pinned: true,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            flexibleSpace: FlexibleSpaceBar(
                              title: Text(
                                '${widget.letterUpper} Harfi',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              centerTitle: false,
                            ),
                          ),
                          // Ana içerik
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            sliver: _activities.isEmpty
                                ? SliverToBoxAdapter(child: _buildEmptyState())
                                : SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2, // 2 sütun
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.9,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        return _buildActivityCard(_activities[index], index);
                                      },
                                      childCount: _activities.length,
                                    ),
                                  ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Activity activity, int index) {
    final color = _getActivityColor(index);
    final icon = _getActivityIcon(activity.type);

    return GestureDetector(
      onTap: () {
        // Etkinlik seçildiğinde sorular ekranına git
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => QuestionsScreen(activity: activity),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C), // Koyu gri
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
            // Etkinlik İkonu
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
            // Etkinlik İsmi
            Text(
              activity.title,
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
            if (activity.durationMinutes > 0) ...[
              const SizedBox(height: 6),
              Text(
                '${activity.durationMinutes} dakika',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
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
            Icons.assignment_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.letterUpper} harfi için henüz etkinlik eklenmemiş',
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
}

