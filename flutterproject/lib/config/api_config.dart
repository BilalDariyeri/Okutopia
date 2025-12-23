import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Base URL - Platform'a göre değişir
  static String get baseUrl {
    // Web için
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    
    // Android emülatör için
    // return 'http://10.0.2.2:3000/api';
    
    // iOS simülatör için
    // return 'http://localhost:3000/api';
    
    // Fiziksel cihaz için (bilgisayarınızın IP adresini kullanın)
    // return 'http://192.168.1.105:3000/api';
    
    // Development için varsayılan (Android emülatör)
    return 'http://10.0.2.2:3000/api';
  }

  // Endpoints
  static String get loginEndpoint => '$baseUrl/users/login';
  static String get registerTeacherEndpoint => '$baseUrl/users/register/teacher';
  
  // Timeout süreleri
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

