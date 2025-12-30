import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/content_service.dart';
import '../models/activity_model.dart';
import '../models/lesson_model.dart';
import 'questions_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  final Lesson lesson;

  const ActivitiesScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> with TickerProviderStateMixin {
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
      final response = await _contentService.getActivitiesByLesson(
        lessonId: widget.lesson.id,
      );

      setState(() {
        _activities = response.activities;
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
                            expandedHeight: MediaQuery.of(context).size.height * 0.15, // Responsive height (~100-120px)
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
                                widget.lesson.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: MediaQuery.of(context).size.width * 0.045, // Responsive font size (~16-18px)
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              centerTitle: false,
                            ),
                          ),
                          // Ana içerik
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: MediaQuery.of(context).size.width * 0.04, // Responsive padding (~12-16px)
                              vertical: MediaQuery.of(context).size.height * 0.02, // Responsive padding (~16px)
                            ),
                            sliver: _activities.isEmpty
                                ? SliverToBoxAdapter(child: _buildEmptyState())
                                : SliverGrid(
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2, // 2 sütun
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: MediaQuery.of(context).size.width < 400 ? 0.85 : 0.9, // Küçük ekranlarda daha kompakt
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
        // Gezegenler (basitleştirilmiş - sadece 2 tane)
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
      ],
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
            Icons.assignment_outlined,
            size: MediaQuery.of(context).size.width * 0.15, // Responsive icon size (~56px)
            color: Colors.white.withValues(alpha: 0.5),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02), // Responsive spacing (~16px)
          Text(
            'Bu derste henüz etkinlik eklenmemiş',
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
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04), // Responsive padding (~12-16px)
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C), // Koyu gri
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
              // Etkinlik İkonu - Responsive boyutlandırma
              Container(
                width: MediaQuery.of(context).size.width * 0.12, // ~48px küçük ekranlarda
                height: MediaQuery.of(context).size.width * 0.12,
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
                  size: MediaQuery.of(context).size.width * 0.06, // ~24px küçük ekranlarda
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.015), // Responsive spacing (~10px)
              // Etkinlik İsmi
              Expanded(
                child: Text(
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
      ),
    );
  }
}

