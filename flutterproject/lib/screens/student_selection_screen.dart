import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/classroom_service.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';

class StudentSelectionScreen extends StatefulWidget {
  const StudentSelectionScreen({super.key});

  @override
  State<StudentSelectionScreen> createState() => _StudentSelectionScreenState();
}

class _StudentSelectionScreenState extends State<StudentSelectionScreen> with TickerProviderStateMixin {
  final ClassroomService _classroomService = ClassroomService();
  List<Student> _students = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Renk paleti (her öğrenci için farklı renk)
  final List<Color> _studentColors = [
    const Color(0xFFE74C3C), // Kırmızı
    const Color(0xFF3498DB), // Mavi
    const Color(0xFF2ECC71), // Yeşil
    const Color(0xFFF39C12), // Turuncu
    const Color(0xFF9B59B6), // Mor
    const Color(0xFF1ABC9C), // Turkuaz
    const Color(0xFFE67E22), // Turuncu-Kırmızı
    const Color(0xFF34495E), // Koyu Gri
  ];

  // Animasyon controller'ları
  late AnimationController _planet1Controller;
  late AnimationController _planet2Controller;
  late AnimationController _planet3Controller;
  late AnimationController _planet4Controller;
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    // Gezegen animasyonları için controller'lar (optimize edilmiş - daha hızlı)
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
    
    // Yıldız parıldama animasyonu (daha yavaş - daha az CPU kullanımı)
    _starController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    
    _loadStudents();
  }

  @override
  void dispose() {
    _planet1Controller.dispose();
    _planet2Controller.dispose();
    _planet3Controller.dispose();
    _planet4Controller.dispose();
    _starController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        throw Exception('Kullanıcı bilgisi bulunamadı.');
      }

      // Önce AuthProvider'dan classroom bilgisini kontrol et
      Classroom? classroom = authProvider.classroom;
      
      // Debug: Classroom bilgisini kontrol et
      debugPrint('🔍 Classroom kontrolü:');
      debugPrint('  - AuthProvider.classroom: ${classroom?.id}');
      debugPrint('  - Classroom name: ${classroom?.name}');
      debugPrint('  - User ID: ${user.id}');

      // Eğer classroom yoksa, öğretmenin sınıfını API'den çek
      if (classroom == null || classroom.id.isEmpty) {
        debugPrint('⚠️ Classroom null veya boş, API\'den çekiliyor...');
        final classrooms = await _classroomService.getTeacherClassrooms(user.id);
        if (!mounted) return;
        if (classrooms.isEmpty) {
          throw Exception('Öğretmenin sınıfı bulunamadı. Lütfen yönetici ile iletişime geçin.');
        }
        // İlk sınıfı kullan (genelde öğretmenin tek sınıfı olur)
        classroom = Classroom(
          id: classrooms.first.id,
          name: classrooms.first.name,
          teacher: user,
          students: [],
        );
        debugPrint('✅ API\'den classroom çekildi: ${classroom.id} - ${classroom.name}');
      } else {
        debugPrint('✅ AuthProvider\'dan classroom kullanılıyor: ${classroom.id} - ${classroom.name}');
      }

      final response = await _classroomService.getClassroomStudents(
        classroom.id,
        user.id,
      );
      if (!mounted) return;

      setState(() {
        _students = response.students;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        // Daha kullanıcı dostu hata mesajları
        if (errorMsg.contains('500') || errorMsg.contains('Sunucu hatası')) {
          errorMsg = 'Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyin.';
        } else if (errorMsg.contains('401') || errorMsg.contains('Token')) {
          errorMsg = 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.';
        } else if (errorMsg.contains('403')) {
          errorMsg = 'Bu işlem için yetkiniz bulunmamaktadır.';
        } else if (errorMsg.contains('404')) {
          errorMsg = 'Sınıf bulunamadı.';
        }
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  Color _getStudentColor(int index) {
    return _studentColors[index % _studentColors.length];
  }


  Future<void> _showAddStudentDialog() async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Yeni Öğrenci Ekle',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4834D4),
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: firstNameController,
                        decoration: InputDecoration(
                          labelText: 'Ad',
                          hintText: 'Öğrencinin adını girin',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ad gereklidir';
                          }
                          if (value.trim().length < 2) {
                            return 'Ad en az 2 karakter olmalıdır';
                          }
                          if (value.trim().length > 50) {
                            return 'Ad en fazla 50 karakter olabilir';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Soyad',
                          hintText: 'Öğrencinin soyadını girin',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Soyad gereklidir';
                          }
                          if (value.trim().length < 2) {
                            return 'Soyad en az 2 karakter olmalıdır';
                          }
                          if (value.trim().length > 50) {
                            return 'Soyad en fazla 50 karakter olabilir';
                          }
                          return null;
                        },
                      ),
                      if (isLoading) ...[
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text(
                    'İptal',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isLoading = true;
                            });

                            try {
                              final authProvider =
                                  Provider.of<AuthProvider>(context, listen: false);
                              final user = authProvider.user;
                              
                              if (user == null) {
                                throw Exception('Kullanıcı bilgisi bulunamadı.');
                              }

                              // Önce AuthProvider'dan classroom bilgisini kontrol et
                              Classroom? classroom = authProvider.classroom;

                              // Eğer classroom yoksa, öğretmenin sınıfını API'den çek
                              if (classroom == null || classroom.id.isEmpty) {
                                final classrooms = await _classroomService.getTeacherClassrooms(user.id);
                                if (classrooms.isEmpty) {
                                  throw Exception('Öğretmenin sınıfı bulunamadı. Lütfen yönetici ile iletişime geçin.');
                                }
                                // İlk sınıfı kullan (genelde öğretmenin tek sınıfı olur)
                                classroom = Classroom(
                                  id: classrooms.first.id,
                                  name: classrooms.first.name,
                                  teacher: user,
                                  students: [],
                                );
                              }

                              final firstName = firstNameController.text.trim();
                              final lastName = lastNameController.text.trim();

                              // Boşluk kontrolü
                              if (firstName.isEmpty || lastName.isEmpty) {
                                throw Exception('Ad ve soyad boş olamaz.');
                              }

                              await _classroomService.addStudentToClassroom(
                                classId: classroom.id,
                                firstName: firstName,
                                lastName: lastName,
                              );

                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '$firstName $lastName başarıyla eklendi',
                                    ),
                                    backgroundColor: const Color(0xFF2ECC71),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                // Listeyi yenile
                                _loadStudents();
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  isLoading = false;
                                });
                                
                                String errorMessage = 'Öğrenci eklenirken bir hata oluştu';
                                if (e is Exception) {
                                  errorMessage = e.toString().replaceAll('Exception: ', '');
                                } else {
                                  errorMessage = e.toString();
                                }
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMessage),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ekle',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      body: Container(
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
            // Yıldızlar ve gezegenler arka plan (animasyonlu)
            _buildBackgroundDecorations(),
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
                                onPressed: _loadStudents,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF4834D4),
                                ),
                                child: const Text('Tekrar Dene'),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 800, // Maksimum genişlik
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  _buildHeader(),
                                  const SizedBox(height: 24),
                                  // Öğretmen Kartı
                                  if (user != null) _buildTeacherCard(user),
                                  const SizedBox(height: 32),
                                  // Öğrencilerim Başlığı ve Ekle Butonu
                                  _buildStudentsHeader(),
                                  const SizedBox(height: 16),
                                  // Öğrenci Kartları
                                  if (_students.isEmpty)
                                    _buildEmptyState()
                                  else
                                    _buildStudentCards(),
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddStudentDialog();
        },
        backgroundColor: const Color(0xFF2ECC71),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Öğrenci Ekle',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
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
        // Yıldızlar (optimize edilmiş - statik, animasyon yok)
        ...List.generate(30, (index) {
          return Positioned(
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
        // Büyük gezegenler (optimize edilmiş - daha basit animasyonlar)
        // Gezegen 1 - Sol üst (turuncu-kırmızı)
        AnimatedBuilder(
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
        // Gezegen 2 - Sağ üst (sarı-altın)
        AnimatedBuilder(
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
        // Gezegen 3 - Sol alt (kırmızı-pembe)
        AnimatedBuilder(
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
        // Gezegen 4 - Sağ alt (mavi-cyan)
        AnimatedBuilder(
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

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Geri gidebiliyorsa geri git, yoksa login'e dön
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
        ),
        Expanded(
          child: Text(
            'Hangi Öğrenci ile Devam Etmek İstiyorsunuz?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () async {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            await authProvider.logout();
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
        ),
      ],
    );
  }

  Widget _buildTeacherCard(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
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
          // Öğretmen İkonu
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C5CE7),
                  const Color(0xFF4834D4),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.firstName.isNotEmpty
                    ? user.firstName[0].toUpperCase()
                    : 'Ö',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Öğretmen Bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Öğretmen',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Öğrencilerim',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        // FAB zaten var, burada boş bırakıyoruz
      ],
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
            Icons.school_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz öğrenci eklenmemiş',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sağ alttaki butona tıklayarak öğrenci ekleyebilirsiniz',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCards() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 3.5,
      ),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        return _buildStudentCard(_students[index], index);
      },
    );
  }

  Widget _buildStudentCard(Student student, int index) {
    final color = _getStudentColor(index);

    return GestureDetector(
      onTap: () async {
        // Öğrenciyi AuthProvider'a kaydet
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.setSelectedStudent(student);
        
        // Kısa bir bekleme (geçişi yavaşlatmak için)
        await Future.delayed(const Duration(milliseconds: 400));
        
        // Kategoriler ekranına git
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/categories');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst kısım: İkon ve menü
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Öğrenci İkonu
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      student.initials.isNotEmpty
                          ? student.initials
                          : student.firstName.isNotEmpty
                              ? student.firstName[0].toUpperCase()
                              : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Üç nokta menü
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 16,
                  ),
                  color: Colors.white,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        // TODO: İsim düzenle
                        break;
                      case 'remove':
                        // TODO: Sınıftan çıkar
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('İsmi Düzenle'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.person_remove, size: 18),
                          SizedBox(width: 8),
                          Text('Sınıftan Çıkar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Öğrenci İsmi ve ok ikonu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    student.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 12,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

