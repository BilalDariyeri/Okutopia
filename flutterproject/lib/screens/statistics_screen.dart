import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/student_selection_provider.dart';
import '../providers/statistics_provider.dart';
import '../services/statistics_service.dart';
import '../services/current_session_service.dart';
import '../models/student_model.dart';
import '../utils/debounce_throttle.dart';
import 'dart:async';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final StatisticsService _statisticsService = StatisticsService();
  final TextEditingController _emailController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 500));
  
  bool _isSendingEmail = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Cache-First: Provider'dan istatistikleri yükle (anında gösterir)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatisticsFromProvider();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _scrollController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  /// Cache-First: Provider'dan istatistikleri yükle (Zero-Loading UI)
  Future<void> _loadStatisticsFromProvider() async {
    if (!mounted) return;
    
    final statisticsProvider = Provider.of<StatisticsProvider>(context, listen: false);
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;
    
    if (selectedStudent == null) {
      setState(() {
        _errorMessage = 'Lütfen önce bir öğrenci seçin.';
      });
      return;
    }

    // Provider'dan cache'lenmiş veriyi kontrol et
    final cachedStats = statisticsProvider.getStatistics(selectedStudent.id);
    final cachedActivities = statisticsProvider.getSessionActivities(selectedStudent.id);
    
    if (cachedStats != null && cachedActivities != null) {
      // Cache'de veri var, anında göster (loading yok!)
      setState(() {
        _errorMessage = null;
        // Email controller'a varsayılan email'i yükle
        if (cachedStats['student'] != null && cachedStats['student']['parentEmail'] != null) {
          _emailController.text = cachedStats['student']['parentEmail'];
        }
      });
      // Arka planda refresh yapılacak (Provider içinde)
      return;
    }

    // Cache yoksa yükle (ilk açılış)
    try {
      await statisticsProvider.loadStatistics(selectedStudent.id);
      if (!mounted) return;
      
      final stats = statisticsProvider.getStatistics(selectedStudent.id);
      setState(() {
        _errorMessage = null;
        if (stats != null && stats['student'] != null && stats['student']['parentEmail'] != null) {
          _emailController.text = stats['student']['parentEmail'];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _sendEmailReport() async {
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;
    
    if (selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce bir öğrenci seçin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen veli e-posta adresini giriniz.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Email formatını kontrol et
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçerli bir e-posta adresi giriniz.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Provider'dan oturum verilerini al
    final statisticsProvider = Provider.of<StatisticsProvider>(context, listen: false);
    final sessionActivities = statisticsProvider.getSessionActivities(selectedStudent.id) ?? [];
    final sessionTotalDuration = statisticsProvider.getSessionDuration(selectedStudent.id) ?? Duration.zero;

    // Oturum aktiviteleri kontrolü
    if (sessionActivities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu oturumda henüz aktivite tamamlanmamış.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSendingEmail = true;
    });

    try {
      // Oturum verilerini hazırla - SADECE tamamlanmış aktiviteleri filtrele
      final completedActivities = sessionActivities.where((activity) => activity.isCompleted).toList();
      
      if (completedActivities.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tamamlanmış aktivite bulunamadı. Rapor gönderilemez.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isSendingEmail = false;
        });
        return;
      }
      
      final sessionActivitiesData = completedActivities.map((activity) {
        return {
          'activityId': activity.activityId,
          'activityTitle': activity.activityTitle,
          'durationSeconds': activity.durationSeconds,
          'successStatus': activity.successStatus,
          'completedAt': activity.completedAt.toIso8601String(),
          'isCompleted': activity.isCompleted,
          'correctAnswerCount': activity.correctAnswerCount,
        };
      }).toList();

      // Backend'e oturum bazlı email gönder
      final result = await _statisticsService.sendSessionEmailToParent(
        selectedStudent.id,
        parentEmail: email,
        sessionActivities: sessionActivitiesData,
        totalDurationSeconds: sessionTotalDuration.inSeconds,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rapor başarıyla gönderildi!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // İstatistikleri yenile (cache-first)
        await statisticsProvider.loadStatistics(selectedStudent.id, forceRefresh: true);
        await statisticsProvider.loadStatistics(selectedStudent.id, forceRefresh: true);
      } else {
        throw Exception(result['message'] ?? 'Email gönderilemedi.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingEmail = false;
        });
      }
    }
  }

  String _formatSessionStartTime(DateTime? startTime) {
    if (startTime == null) return 'Bilinmiyor';
    
    final now = DateTime.now();
    final difference = now.difference(startTime);
    
    if (difference.inHours > 0) {
      return '${difference.inHours} saat önce başladı';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce başladı';
    } else {
      return 'Az önce başladı';
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;
    
    return Consumer<StatisticsProvider>(
      builder: (context, statisticsProvider, child) {
        // Cache-First: Provider'dan verileri al (anında gösterilir)
        final sessionActivities = (selectedStudent != null
            ? statisticsProvider.getSessionActivities(selectedStudent.id) ?? []
            : []) as List<SessionActivity>;
        final sessionStartTime = selectedStudent != null
            ? statisticsProvider.getSessionStartTime(selectedStudent.id)
            : null;
        
        return _buildScaffold(context, sessionActivities, sessionStartTime, selectedStudent);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, List<SessionActivity> sessionActivities, DateTime? sessionStartTime, Student? selectedStudent) {
    final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFF6C5CE7),
      body: SafeArea(
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
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadStatisticsFromProvider,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4834D4),
                          ),
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Üst Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFE91E63),
                              const Color(0xFFAD1457),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const Expanded(
                              child: Text(
                                'İstatistikler ve Raporlar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // İstatistik Kartları
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Öğrenci Bilgisi
                              if (selectedStudent != null)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF4ECDC4),
                                              const Color(0xFF44A08D),
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
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              selectedStudent.fullName,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2C2C2C),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              userProfileProvider.classroom?.name ?? 'Sınıf',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Oturum Özeti Başlığı
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF9B59B6),
                                      const Color(0xFF8E44AD),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF9B59B6).withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Oturum Özeti',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (sessionStartTime != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatSessionStartTime(sessionStartTime),
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.9),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Oturum Aktiviteleri Listesi
                              if (sessionActivities.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.list,
                                            color: const Color(0xFF9B59B6),
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Bugünkü Çalışmalar',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2C2C2C),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      ...sessionActivities.reversed.map((activity) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.grey[200]!,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        const Color(0xFF4ECDC4),
                                                        const Color(0xFF44A08D),
                                                      ],
                                                    ),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.play_circle_outline,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        activity.activityTitle,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF2C2C2C),
                                                        ),
                                                      ),
                                                      if (activity.successStatus != null) ...[
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          activity.successStatus!,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF9B59B6).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    activity.formattedDuration,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF9B59B6),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Bu oturumda henüz aktivite tamamlanmamış',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),

                      // Alt Email Formu
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Veli E-posta Adresi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C2C2C),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'ornek@email.com',
                                prefixIcon: const Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isSendingEmail ? null : () {
                                _debouncer.call(() {
                                  _sendEmailReport();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4ECDC4),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: _isSendingEmail
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Gönderiliyor...'),
                                      ],
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.send),
                                        SizedBox(width: 8),
                                        Text(
                                          'Raporu Gönder',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

