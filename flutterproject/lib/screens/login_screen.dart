import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureConfirmPassword = true;
  bool _showError = false;
  String _errorMessage = '';
  
  late AnimationController _planet1Controller;
  late AnimationController _planet2Controller;
  late AnimationController _planet3Controller;
  late AnimationController _planet4Controller;
  late AnimationController _starController;
  late AnimationController _errorController;
  
  @override
  void initState() {
    super.initState();
    // Gezegen animasyonları için controller'lar (sonsuz döngü - yavaş)
    _planet1Controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _planet2Controller = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat();
    
    _planet3Controller = AnimationController(
      duration: const Duration(seconds: 22),
      vsync: this,
    )..repeat();
    
    _planet4Controller = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
    
    _starController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _errorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }
  
  @override
  void dispose() {
    _planet1Controller.dispose();
    _planet2Controller.dispose();
    _planet3Controller.dispose();
    _planet4Controller.dispose();
    _starController.dispose();
    _errorController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }


  void _showErrorFromTop(String message) {
    setState(() {
      _errorMessage = message;
      _showError = true;
    });
    _errorController.forward().then((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _errorController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _showError = false;
              });
            }
          });
        }
      });
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      // Başarılı giriş - ana ekrana yönlendir
      Navigator.of(context).pushReplacementNamed('/student-selection');
    } else if (mounted) {
      // Hata göster - yukarıdan
      _showErrorFromTop(authProvider.errorMessage ?? 'Giriş başarısız');
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_registerPasswordController.text != _confirmPasswordController.text) {
      if (mounted) {
        _showErrorFromTop('Şifreler eşleşmiyor');
      }
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.registerTeacher(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _registerEmailController.text.trim(),
      password: _registerPasswordController.text,
    );

    if (success && mounted) {
      // Başarılı kayıt - ana ekrana yönlendir
      Navigator.of(context).pushReplacementNamed('/student-selection');
    } else if (mounted) {
      // Hata göster - yukarıdan
      _showErrorFromTop(authProvider.errorMessage ?? 'Kayıt başarısız');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
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
            // Hata mesajı - yukarıdan
            if (_showError) _buildErrorBanner(),
            // Ana içerik - ekranın ortasında
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 500, // Maksimum genişlik
                      minHeight: MediaQuery.of(context).size.height - 100,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Başlık
                        _buildHeader(),
                        const SizedBox(height: 40),
                        // Login/Register kartı
                        _buildAuthCard(),
                        const SizedBox(height: 40),
                        // Footer - scroll ile birlikte hareket eder
                        _buildFooter(),
                      ],
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

  Widget _buildErrorBanner() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _errorController,
        curve: Curves.easeOut,
      )),
      child: Container(
        margin: const EdgeInsets.only(top: 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () {
                _errorController.reverse().then((_) {
                  if (mounted) {
                    setState(() {
                      _showError = false;
                    });
                  }
                });
              },
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
        // Yıldızlar (daha fazla ve parıldayan)
        ...List.generate(80, (index) {
          return AnimatedBuilder(
            animation: _starController,
            builder: (context, child) {
              final twinkle = (index % 3 == 0) 
                  ? 0.5 + (0.5 * (0.5 + 0.5 * (1 - _starController.value)))
                  : 0.8;
              return Positioned(
                left: (index * 37.7) % screenWidth,
                top: (index * 23.3) % screenHeight,
                child: Container(
                  width: 2 + (index % 3 == 0 ? 1 : 0),
                  height: 2 + (index % 3 == 0 ? 1 : 0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: twinkle),
                    shape: BoxShape.circle,
                    boxShadow: index % 5 == 0 ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.5),
                        blurRadius: 3,
                        spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                ),
              );
            },
          );
        }),
        // Büyük gezegenler (animasyonlu ve canlı renkler - daha hareketli)
        // Gezegen 1 - Sol üst (turuncu-kırmızı) - Sonsuz döngü
        AnimatedBuilder(
          animation: Listenable.merge([_planet1Controller]),
          builder: (context, child) {
            // Sürekli artan zaman değeri (sonsuz döngü)
            final time = _planet1Controller.value * 2 * math.pi;
            final baseX = -50.0;
            final baseY = 50.0;
            final radiusX = 30.0;
            final radiusY = 40.0;
            
            return Positioned(
              left: baseX + radiusX * math.sin(time),
              top: baseY + radiusY * math.cos(time),
              child: Transform.scale(
                scale: 1.0 + 0.15 * (1 + math.sin(time * 0.5)),
                child: Transform.rotate(
                  angle: time,
                  child: Container(
            
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.deepOrange.withValues(alpha: 0.6),
                          Colors.orange.withValues(alpha: 0.4),
                          Colors.red.withValues(alpha: 0.3),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.5),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Gezegen 2 - Sağ üst (sarı-altın) - Sonsuz döngü
        AnimatedBuilder(
          animation: Listenable.merge([_planet2Controller]),
          builder: (context, child) {
            // Sürekli artan zaman değeri (sonsuz döngü)
            final time = _planet2Controller.value * 2 * math.pi;
            final screenWidth = MediaQuery.of(context).size.width;
            final baseX = screenWidth + 30.0;
            final baseY = 100.0;
            final radiusX = 35.0;
            final radiusY = 50.0;
            
            return Positioned(
              right: screenWidth - (baseX - radiusX * math.sin(time * 0.8)),
              top: baseY + radiusY * math.cos(time * 0.8),
              child: Transform.scale(
                scale: 1.0 + 0.2 * (1 + math.sin(time * 0.6)),
                child: Transform.rotate(
                  angle: -time,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.amber.withValues(alpha: 0.6),
                          Colors.yellow.withValues(alpha: 0.5),
                          Colors.orange.withValues(alpha: 0.4),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.yellow.withValues(alpha: 0.6),
                          blurRadius: 35,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Gezegen 3 - Sol alt (kırmızı-pembe) - Sonsuz döngü
        AnimatedBuilder(
          animation: Listenable.merge([_planet3Controller]),
          builder: (context, child) {
            // Sürekli artan zaman değeri (sonsuz döngü)
            final time = _planet3Controller.value * 2 * math.pi;
            final screenHeight = MediaQuery.of(context).size.height;
            final baseX = 50.0;
            final baseY = screenHeight - 100.0;
            final radiusX = 40.0;
            final radiusY = 45.0;
            
            return Positioned(
              left: baseX + radiusX * math.sin(time * 1.2),
              bottom: screenHeight - (baseY - radiusY * math.cos(time * 1.2)),
              child: Transform.scale(
                scale: 1.0 + 0.18 * (1 + math.sin(time * 0.7)),
                child: Transform.rotate(
                  angle: time * 1.5,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.pink.withValues(alpha: 0.6),
                          Colors.red.withValues(alpha: 0.5),
                          Colors.deepOrange.withValues(alpha: 0.4),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Gezegen 4 - Sağ alt (mavi-cyan) - Sonsuz döngü
        AnimatedBuilder(
          animation: Listenable.merge([_planet4Controller]),
          builder: (context, child) {
            // Sürekli artan zaman değeri (sonsuz döngü)
            final time = _planet4Controller.value * 2 * math.pi;
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final baseX = screenWidth - 20.0;
            final baseY = screenHeight - 150.0;
            final radiusX = 30.0;
            final radiusY = 50.0;
            
            return Positioned(
              right: screenWidth - (baseX - radiusX * math.sin(time * 0.9)),
              bottom: screenHeight - (baseY - radiusY * math.cos(time * 0.9)),
              child: Transform.scale(
                scale: 1.0 + 0.15 * (1 + math.sin(time * 0.5)),
                child: Transform.rotate(
                  angle: -time * 1.5,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.cyan.withValues(alpha: 0.6),
                          Colors.blue.withValues(alpha: 0.5),
                          Colors.lightBlue.withValues(alpha: 0.4),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Kayan yıldız (animasyonlu)
        AnimatedBuilder(
          animation: _starController,
          builder: (context, child) {
            return Positioned(
              left: 100 + (screenWidth * 0.3 * _starController.value),
              top: 80 - (screenHeight * 0.1 * _starController.value),
              child: Transform.rotate(
                angle: 0.5,
                child: Opacity(
                  opacity: 1.0 - _starController.value,
                  child: Container(
                    width: 2,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.8),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'OKUTOPİA DÜNYASINA HOŞGELDİNİZ',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600, // Daha yumuşak bold
            color: Colors.white,
            letterSpacing: 1.0,
            height: 1.3, // Satır yüksekliği
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.2),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Okuma ve öğrenme dünyasına adım atın',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.9),
            letterSpacing: 0.3,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Text(
      '© 2025 OKUTOPİA. Tüm hakları saklıdır.',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        color: Colors.white.withValues(alpha: 0.7),
        letterSpacing: 0.3,
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık
            Text(
              _isLoginMode ? 'Giriş Yap' : 'Üye Ol',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600, // Daha yumuşak
                color: Colors.white,
                letterSpacing: 0.5,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isLoginMode
                  ? 'Hesabınıza giriş yaparak eğitim materyallerine erişin'
                  : 'Yeni hesap oluşturarak eğitim yolculuğunuza başlayın',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
                letterSpacing: 0.2,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            // Form alanları
            if (_isLoginMode) ...[
              _buildEmailField(),
              const SizedBox(height: 20),
              _buildPasswordField(),
              const SizedBox(height: 12),
              _buildForgotPasswordLink(),
            ] else ...[
              _buildFirstNameField(),
              const SizedBox(height: 20),
              _buildLastNameField(),
              const SizedBox(height: 20),
              _buildRegisterEmailField(),
              const SizedBox(height: 20),
              _buildRegisterPasswordField(),
              const SizedBox(height: 20),
              _buildConfirmPasswordField(),
            ],
            const SizedBox(height: 30),
            // Giriş/Kayıt butonu
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                return ElevatedButton(
                  onPressed: authProvider.isLoading
                      ? null
                      : (_isLoginMode ? _handleLogin : _handleRegister),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: authProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLoginMode ? 'Giriş Yap' : 'Kayıt Ol',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, color: Colors.white),
                          ],
                        ),
                );
              },
            ),
            const SizedBox(height: 20),
            // Ayırıcı
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'veya',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
              ],
            ),
            const SizedBox(height: 20),
            // Kayıt/Giriş geçiş butonu
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoginMode = !_isLoginMode;
                  _formKey.currentState?.reset();
                });
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.2),
                side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                _isLoginMode ? Icons.person_add : Icons.login,
                color: Colors.white,
              ),
              label: Text(
                _isLoginMode ? 'Üye Ol' : 'Giriş Yap',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
      ),
      decoration: InputDecoration(
        labelText: 'E-posta',
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
        ),
        prefixIcon: const Icon(Icons.email, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'E-posta adresi gerekli';
        }
        final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
        if (!emailRegex.hasMatch(value.trim())) {
          return 'Geçerli bir e-posta adresi girin';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Şifre',
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        prefixIcon: const Icon(Icons.lock, color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.white70,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Şifre gerekli';
        }
        return null;
      },
    );
  }

  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          // Şifremi unuttum işlevi
        },
        child: Text(
          'Şifremi Unuttum',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildFirstNameField() {
    return TextFormField(
      controller: _firstNameController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Ad',
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        prefixIcon: const Icon(Icons.person, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Ad gerekli';
        }
        if (value.length < 2) {
          return 'Ad en az 2 karakter olmalı';
        }
        return null;
      },
    );
  }

  Widget _buildLastNameField() {
    return TextFormField(
      controller: _lastNameController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Soyad',
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Soyad gerekli';
        }
        if (value.length < 2) {
          return 'Soyad en az 2 karakter olmalı';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterEmailField() {
    return TextFormField(
      controller: _registerEmailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
      ),
      decoration: InputDecoration(
        labelText: 'E-posta',
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
        ),
        prefixIcon: const Icon(Icons.email, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'E-posta adresi gerekli';
        }
        final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
        if (!emailRegex.hasMatch(value.trim())) {
          return 'Geçerli bir e-posta adresi girin';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterPasswordField() {
    return TextFormField(
      controller: _registerPasswordController,
      obscureText: _obscureRegisterPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Şifre',
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        prefixIcon: const Icon(Icons.lock, color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureRegisterPassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.white70,
          ),
          onPressed: () {
            setState(() {
              _obscureRegisterPassword = !_obscureRegisterPassword;
            });
          },
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Şifre gerekli';
        }
        if (value.length < 6) {
          return 'Şifre en az 6 karakter olmalı';
        }
        // Backend validasyonu: en az bir büyük harf ve bir rakam
        if (!RegExp(r'^(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
          return 'Şifre en az bir büyük harf ve bir rakam içermeli';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Şifre Tekrar',
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.white70,
          ),
          onPressed: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Şifre tekrarı gerekli';
        }
        if (value != _registerPasswordController.text) {
          return 'Şifreler eşleşmiyor';
        }
        return null;
      },
    );
  }
}

