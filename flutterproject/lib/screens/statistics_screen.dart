import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/statistics_service.dart';
import '../services/current_session_service.dart';
import 'dart:async';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final StatisticsService _statisticsService = StatisticsService();
  final CurrentSessionService _sessionService = CurrentSessionService();
  final TextEditingController _emailController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = true;
  bool _isSendingEmail = false;
  String? _errorMessage;
  
  List<SessionActivity> _sessionActivities = [];
  Duration _sessionTotalDuration = Duration.zero;
  DateTime? _sessionStartTime;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final selectedStudent = authProvider.selectedStudent;
    
    if (selectedStudent == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lütfen önce bir öğrenci seçin.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Backend'den öğrenci bilgilerini getir (email için)
      final stats = await _statisticsService.getStudentStatistics(selectedStudent.id);
      
      // Oturum verilerini getir
      _sessionActivities = _sessionService.getSessionActivities(selectedStudent.id);
      _sessionTotalDuration = _sessionService.getSessionTotalDuration(selectedStudent.id);
      _sessionStartTime = _sessionService.getSessionStartTime(selectedStudent.id);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        
        // Email controller'a varsayılan email'i yükle
        if (stats['student'] != null && stats['student']['parentEmail'] != null) {
          _emailController.text = stats['student']['parentEmail'];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _sendEmailReport() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final selectedStudent = authProvider.selectedStudent;
    
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

    // Oturum aktiviteleri kontrolü
    if (_sessionActivities.isEmpty) {
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
      // Oturum verilerini hazırla
      final sessionActivitiesData = _sessionActivities.map((activity) {
        return {
          'activityId': activity.activityId,
          'activityTitle': activity.activityTitle,
          'durationSeconds': activity.durationSeconds,
          'successStatus': activity.successStatus,
          'completedAt': activity.completedAt.toIso8601String(),
        };
      }).toList();

      // Backend'e oturum bazlı email gönder
      final result = await _statisticsService.sendSessionEmailToParent(
        selectedStudent.id,
        parentEmail: email,
        sessionActivities: sessionActivitiesData,
        totalDurationSeconds: _sessionTotalDuration.inSeconds,
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
        
        // İstatistikleri yenile
        await _loadStatistics();
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
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
    final authProvider = Provider.of<AuthProvider>(context);
    final selectedStudent = authProvider.selectedStudent;

    return Scaffold(
      backgroundColor: const Color(0xFF6C5CE7),
      body: SafeArea(
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
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadStatistics,
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
                                              authProvider.classroom?.name ?? 'Sınıf',
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
                                          if (_sessionStartTime != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatSessionStartTime(_sessionStartTime),
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

                              // Toplam Süre Kartı (Oturum)
                              _buildStatCard(
                                icon: Icons.timer,
                                title: 'Oturum Toplam Süresi',
                                value: _formatDuration(_sessionTotalDuration),
                                color: const Color(0xFF4ECDC4),
                                subtitle: _sessionActivities.isNotEmpty
                                    ? '${_sessionActivities.length} aktivite tamamlandı'
                                    : 'Henüz aktivite yok',
                              ),

                              const SizedBox(height: 12),

                              // Oturum Aktiviteleri Listesi
                              if (_sessionActivities.isNotEmpty) ...[
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
                                      ..._sessionActivities.reversed.map((activity) {
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
                                      }).toList(),
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
                              onPressed: _isSendingEmail ? null : _sendEmailReport,
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

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

