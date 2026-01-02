import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'letter_activities_screen.dart';
import '../models/category_model.dart';

class LetterGroupsScreen extends StatefulWidget {
  final Category category;

  const LetterGroupsScreen({
    super.key,
    required this.category,
  });

  @override
  State<LetterGroupsScreen> createState() => _LetterGroupsScreenState();
}

class _LetterGroupsScreenState extends State<LetterGroupsScreen> with TickerProviderStateMixin {
  // 1. Grup harfleri - mevcut içerik korunuyor
  final List<Map<String, String>> _firstGroupLetters = [
    {'lower': 'a', 'upper': 'A'},
    {'lower': 'n', 'upper': 'N'},
    {'lower': 'e', 'upper': 'E'},
    {'lower': 't', 'upper': 'T'},
    {'lower': 'i', 'upper': 'İ'},
    {'lower': 'l', 'upper': 'L'},
  ];
  
  // 2. Grup harfleri - admin panelinden eklenen harfler
  final List<Map<String, String>> _secondGroupLetters = [
    {'lower': 'o', 'upper': 'O'},
    {'lower': 'k', 'upper': 'K'},
    {'lower': 'u', 'upper': 'U'},
    {'lower': 'r', 'upper': 'R'},
    {'lower': 'ı', 'upper': 'I'},
    {'lower': 'm', 'upper': 'M'},
  ];
  
  // 3. Grup harfleri - admin panelinden eklenen harfler
  final List<Map<String, String>> _thirdGroupLetters = [
    {'lower': 'ü', 'upper': 'Ü'},
    {'lower': 's', 'upper': 'S'},
    {'lower': 'ö', 'upper': 'Ö'},
    {'lower': 'y', 'upper': 'Y'},
    {'lower': 'd', 'upper': 'D'},
    {'lower': 'z', 'upper': 'Z'},
  ];
  
  // 4. Grup harfleri - admin panelinden eklenen harfler
  final List<Map<String, String>> _fourthGroupLetters = [
    {'lower': 'ç', 'upper': 'Ç'},
    {'lower': 'b', 'upper': 'B'},
    {'lower': 'g', 'upper': 'G'},
    {'lower': 'c', 'upper': 'C'},
    {'lower': 'ş', 'upper': 'Ş'},
  ];
  
  // 5. Grup harfleri - admin panelinden eklenen harfler
  final List<Map<String, String>> _fifthGroupLetters = [
    {'lower': 'f', 'upper': 'F'},
    {'lower': 'h', 'upper': 'H'},
    {'lower': 'j', 'upper': 'J'},
    {'lower': 'p', 'upper': 'P'},
    {'lower': 'v', 'upper': 'V'},
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
  }

  @override
  void dispose() {
    _planet1Controller.dispose();
    _planet2Controller.dispose();
    _planet3Controller.dispose();
    _planet4Controller.dispose();
    super.dispose();
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
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Geri butonu
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      // "1. Grup" başlığı ve harf butonları
                      _buildGroupSection('1. Grup', _firstGroupLetters, const Color(0xFFFF6B35)),
                      const SizedBox(height: 40),
                      // "2. Grup" başlığı ve harf butonları
                      _buildGroupSection('2. Grup', _secondGroupLetters, const Color(0xFF4CAF50)),
                      const SizedBox(height: 40),
                      // "3. Grup" başlığı ve harf butonları
                      _buildGroupSection('3. Grup', _thirdGroupLetters, const Color(0xFF00BCD4)),
                      const SizedBox(height: 40),
                      // "4. Grup" başlığı ve harf butonları
                      _buildGroupSection('4. Grup', _fourthGroupLetters, const Color(0xFFFFEB3B)),
                      const SizedBox(height: 40),
                      // "5. Grup" başlığı ve harf butonları
                      _buildGroupSection('5. Grup', _fifthGroupLetters, const Color(0xFFFF9800)),
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

  Widget _buildGroupSection(String title, List<Map<String, String>> letters, Color buttonColor) {
    return Column(
      children: [
        // Grup başlığı - sol tarafta
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w400,
                fontFamily: 'Roboto',
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Harf butonları paneli
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: letters.map((letter) {
              return _buildLetterButton(letter, buttonColor);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLetterButton(Map<String, String> letter, Color buttonColor) {
    // Border rengi için daha koyu ton
    Color borderColor;
    if (buttonColor == const Color(0xFFFF6B35)) {
      borderColor = const Color(0xFFE55A2B); // Turuncu için koyu turuncu
    } else if (buttonColor == const Color(0xFF4CAF50)) {
      borderColor = const Color(0xFF388E3C); // Yeşil için koyu yeşil
    } else if (buttonColor == const Color(0xFF00BCD4)) {
      borderColor = const Color(0xFF0097A7); // Açık mavi için koyu mavi
    } else if (buttonColor == const Color(0xFFFFEB3B)) {
      borderColor = const Color(0xFFF9A825); // Sarı için koyu sarı
    } else {
      borderColor = const Color(0xFFE65100); // Turuncu için koyu turuncu (5. grup)
    }
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Harf seçildiğinde aktiviteler ekranına git
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => LetterActivitiesScreen(
                letter: letter['lower']!,
                letterUpper: letter['upper']!,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: buttonColor.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${letter['lower']} ${letter['upper']}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ),
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

