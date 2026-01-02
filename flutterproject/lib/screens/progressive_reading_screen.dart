import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/reading_text_model.dart';
import '../services/activity_progress_service.dart';
import '../services/current_session_service.dart';
import '../providers/student_selection_provider.dart';

class ProgressiveReadingScreen extends StatefulWidget {
  final ReadingText readingText;
  final int totalTexts;
  final List<ReadingText>? allTexts; // Tüm metinler listesi
  final Function(int)? onTextChanged; // Metin değiştiğinde callback

  const ProgressiveReadingScreen({
    super.key,
    required this.readingText,
    this.totalTexts = 34,
    this.allTexts,
    this.onTextChanged,
  });

  @override
  State<ProgressiveReadingScreen> createState() => _ProgressiveReadingScreenState();
}

class _ProgressiveReadingScreenState extends State<ProgressiveReadingScreen> with TickerProviderStateMixin {
  final ActivityProgressService _progressService = ActivityProgressService();
  final CurrentSessionService _sessionService = CurrentSessionService();
  late ReadingText _currentReadingText;
  List<ReadingText>? _allTexts;
  
  // Kelime bazlı interaktif özellikler
  Set<String> _readWordPositions = {}; // Okunan kelimelerin pozisyonları (lineIndex_wordIndex)
  int _readWordCount = 0; // Okunan kelime sayısı
  int _totalWordCount = 0; // Toplam kelime sayısı
  DateTime? _readingStartTime; // Okuma başlangıç zamanı

  // Animasyon controller'ları (uzay teması için)
  late AnimationController _planet1Controller;
  late AnimationController _planet2Controller;
  late AnimationController _planet3Controller;
  late AnimationController _planet4Controller;

  @override
  void initState() {
    super.initState();
    _currentReadingText = widget.readingText;
    _allTexts = widget.allTexts;
    // Eğer allTexts verilmemişse, örnek verilerden oluştur
    if (_allTexts == null) {
      _allTexts = ReadingText.getAllExamples();
    }
    _initializeWordTracking();
    
    // Okuma başlangıç zamanını kaydet
    _readingStartTime = DateTime.now();
    
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
    
    // Status bar'ı gizle (immersive mode)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Kelime takibini başlat
  void _initializeWordTracking() {
    _readWordPositions.clear();
    _readWordCount = 0;
    // Tüm satırlardaki kelimeleri say (boş satırları ve boş kelimeleri filtrele)
    // Önce boş olmayan satırları al, sonra kelimelere böl
    final nonEmptyLines = _currentReadingText.lines
        .where((line) => line.trim().isNotEmpty)
        .toList();
    _totalWordCount = nonEmptyLines
        .expand((line) => line.split(' ').where((word) => word.trim().isNotEmpty))
        .length;
  }
  
  /// Boş olmayan satırların listesini ve orijinal index'lerini döndürür
  List<MapEntry<int, String>> _getNonEmptyLinesWithIndex() {
    return _currentReadingText.lines
        .asMap()
        .entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .toList();
  }

  /// Kelime pozisyonu için benzersiz key oluştur
  String _getWordKey(int lineIndex, int wordIndex) {
    return '${lineIndex}_$wordIndex';
  }

  /// Kelimeye tıklandığında çağrılır
  void _onWordTapped(int lineIndex, int wordIndex) {
    final wordKey = _getWordKey(lineIndex, wordIndex);
    
    // Eğer bu pozisyondaki kelime daha önce okunmadıysa
    if (!_readWordPositions.contains(wordKey)) {
      setState(() {
        _readWordPositions.add(wordKey);
        _readWordCount++;
      });
      
      // Tüm kelimeler okundu mu kontrol et
      if (_readWordCount == _totalWordCount && _totalWordCount > 0) {
        _markTextAsCompleted();
      }
    }
  }

  /// Metni tamamlandı olarak işaretle
  void _markTextAsCompleted() {
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;
    
    if (selectedStudent != null && _readingStartTime != null) {
      // Okuma süresini hesapla
      final duration = DateTime.now().difference(_readingStartTime!).inSeconds;
      
      // Kademeli kilit sistemi için kaydet
      _progressService.markReadingTextCompleted(
        studentId: selectedStudent.id,
        readingTextId: _currentReadingText.id,
      );
      
      // Oturum istatistikleri için kaydet (email sistemine dahil olacak)
      _sessionService.addReadingText(
        studentId: selectedStudent.id,
        readingTextId: _currentReadingText.id,
        readingTextTitle: _currentReadingText.title,
        durationSeconds: duration,
        wordCount: _readWordCount,
      );
    }
  }

  /// Kelimenin okunup okunmadığını kontrol eder
  bool _isWordRead(int lineIndex, int wordIndex) {
    final wordKey = _getWordKey(lineIndex, wordIndex);
    return _readWordPositions.contains(wordKey);
  }

  @override
  void dispose() {
    // Animasyon controller'larını temizle
    _planet1Controller.dispose();
    _planet2Controller.dispose();
    _planet3Controller.dispose();
    _planet4Controller.dispose();
    
    // Status bar'ı tekrar göster
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _goToText(int textNumber) {
    if (textNumber == 0) {
      Navigator.of(context).pop();
    } else if (textNumber > 0 && textNumber <= widget.totalTexts) {
      // Aynı ekranda metni güncelle
      final newText = _allTexts?.firstWhere(
        (text) => text.textNumber == textNumber,
        orElse: () => _currentReadingText,
      );
      
      if (newText != null && newText.textNumber != _currentReadingText.textNumber) {
        setState(() {
          _currentReadingText = newText;
          // Yeni metin için kelime takibini sıfırla
          _initializeWordTracking();
          // Yeni metin için okuma başlangıç zamanını sıfırla
          _readingStartTime = DateTime.now();
        });
        // Callback'i çağır (isteğe bağlı)
        widget.onTextChanged?.call(textNumber);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arka plan (uzay teması)
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
          Column(
            children: [
              // App Header (Status bar gizli olduğu için SafeArea kaldırıldı)
              _buildAppHeader(),
              
              // Main Content
              Expanded(
                child: _buildMainContent(),
              ),
              
              // Bottom Navigation
              _buildBottomNavigation(),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildAppHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C5CE7).withValues(alpha: 0.85), // Açık mor - şeffaf
            const Color(0xFF4834D4).withValues(alpha: 0.80), // Orta mor - şeffaf
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Geri butonu
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // Başlık
          Expanded(
            child: Text(
              'Okuma Metni ${_currentReadingText.textNumber}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Spacer (geri butonu ile simetri için)
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF344955), // Koyu gri kart arka planı
            borderRadius: BorderRadius.circular(20),
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
              // Başlık ve Kelime Sayısı (yan yana)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık (sol taraf)
                  Expanded(
                    child: Text(
                      _currentReadingText.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Kelime Sayısı (sağ taraf)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_readWordCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '/$_totalWordCount',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // Metin satırları (kelime kelime, layoutType'a göre hizalama)
              ..._getNonEmptyLinesWithIndex().asMap().entries.map((entry) {
                final displayIndex = entry.key; // Görüntüleme için index (boş satırlar hariç)
                final originalIndex = entry.value.key; // Orijinal satır index'i
                final line = entry.value.value;
                final layoutType = _currentReadingText.layoutType;
                
                // Hizalama belirleme
                Alignment alignment;
                double? fontSize;
                
                // Boş olmayan satırların sayısını al
                final nonEmptyLines = _getNonEmptyLinesWithIndex();
                final totalNonEmptyLines = nonEmptyLines.length;
                
                switch (layoutType) {
                  case ReadingTextLayoutType.diamond:
                    // Baklava deseni: Ortada başla, ortada bit
                    alignment = Alignment.center;
                    // Ortadaki satırlar daha büyük, kenarlar daha küçük
                    final middleIndex = totalNonEmptyLines ~/ 2;
                    final distanceFromMiddle = (displayIndex - middleIndex).abs();
                    fontSize = 20.0 - (distanceFromMiddle * 2.0);
                    fontSize = fontSize.clamp(16.0, 24.0);
                    break;
                  case ReadingTextLayoutType.pyramid:
                    // Piramit: Tüm satırlar ortalanmış, kısadan uzuna
                    alignment = Alignment.center;
                    fontSize = 20.0;
                    break;
                  case ReadingTextLayoutType.standard:
                    // Düz metin: Soldan hizalı
                    alignment = Alignment.centerLeft;
                    fontSize = 20.0;
                    break;
                }
                
                // Satırı kelimelere böl
                final words = line.split(' ').where((w) => w.trim().isNotEmpty).toList();
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Align(
                    alignment: alignment,
                    child: Wrap(
                      alignment: alignment == Alignment.center 
                          ? WrapAlignment.center 
                          : WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: words.asMap().entries.map((wordEntry) {
                        final wordIndex = wordEntry.key;
                        final word = wordEntry.value.trim();
                        // Orijinal satır index'ini kullan (kelime pozisyonu için)
                        final isRead = _isWordRead(originalIndex, wordIndex);
                        
                        return Padding(
                          padding: EdgeInsets.only(
                            right: wordIndex < words.length - 1 ? 8 : 0,
                          ),
                          child: InkWell(
                            onTap: () => _onWordTapped(originalIndex, wordIndex),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                word,
                                style: TextStyle(
                                  color: isRead ? Colors.red : Colors.white,
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w400,
                                  height: 1.5,
                                  letterSpacing: 0.5,
                                  decoration: isRead 
                                      ? TextDecoration.underline 
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }),
              
              const SizedBox(height: 40),
              
              // Navigasyon butonları
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Önceki Metin butonu
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentReadingText.textNumber > 1
                          ? () => _goToText(_currentReadingText.textNumber - 1)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF424242), // Gri ton
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Önceki Metin',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Sonraki Metin butonu (Kilit mekanizması ile)
                  Expanded(
                    child: GestureDetector(
                      onTap: (_readWordCount == _totalWordCount && 
                              _totalWordCount > 0 &&
                              _currentReadingText.textNumber < widget.totalTexts)
                          ? () {
                              // Tüm kelimeler okundu, sonraki metne geç
                              _goToText(_currentReadingText.textNumber + 1);
                            }
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          // Tüm kelimeler okunduysa ve son metin değilse aktif
                          gradient: (_readWordCount == _totalWordCount && 
                                     _totalWordCount > 0 &&
                                     _currentReadingText.textNumber < widget.totalTexts)
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFE91E63), // Pembe
                                    Color(0xFF9C27B0), // Mor
                                  ],
                                )
                              : null,
                          // Pasif durum: Gri renk
                          color: (_readWordCount < _totalWordCount || 
                                 _currentReadingText.textNumber >= widget.totalTexts)
                              ? Colors.grey[600]
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Sonraki Metin',
                            style: TextStyle(
                              color: (_readWordCount == _totalWordCount && 
                                     _totalWordCount > 0 &&
                                     _currentReadingText.textNumber < widget.totalTexts)
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4834D4).withValues(alpha: 0.85), // Orta mor - şeffaf
            const Color(0xFF2D1B69).withValues(alpha: 0.80), // Koyu mor - şeffaf
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Ana Sayfa
          _buildBottomNavItem(
            icon: Icons.home,
            label: 'Ana Sayfa',
            onTap: () {
              // Ana sayfaya git
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          // Metinler
          _buildBottomNavItem(
            icon: Icons.book,
            label: 'Metinler',
            onTap: () {
              // Metinler listesine git
              Navigator.of(context).pop();
            },
            isActive: true,
          ),
          // İstatistikler
          _buildBottomNavItem(
            icon: Icons.bar_chart,
            label: 'İstatistikler',
            onTap: () {
              // İstatistikler ekranına git
              Navigator.of(context).pushNamed('/statistics');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                    const Color(0xFF4834D4).withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.8),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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

