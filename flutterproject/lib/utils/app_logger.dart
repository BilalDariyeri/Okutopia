import 'package:flutter/foundation.dart';

/// Simple logging utility to replace print statements
class AppLogger {
  static const String _tag = 'OKUTOPIA';
  
  /// Debug level logging (only in debug mode)
  static void debug(String message) {
    if (kDebugMode) {
      print('🔍 $_tag: $message');
    }
  }
  
  /// Info level logging (shows in both debug and release)
  static void info(String message) {
    print('ℹ️ $_tag: $message');
  }
  
  /// Warning level logging
  static void warning(String message) {
    print('⚠️ $_tag: $message');
  }
  
  /// Error level logging
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('❌ $_tag: $message');
    }
    if (error != null) {
      print('   Error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      print('   Stack trace:\n$stackTrace');
    }
  }
  
  /// Network request logging
  static void network(String method, String url, {int? statusCode, String? response}) {
    if (kDebugMode) {
      print('🌐 $_tag: $method $url');
      if (statusCode != null) {
        print('   Status: $statusCode');
      }
      if (response != null) {
        print('   Response: $response');
      }
    }
  }
  
  /// User action logging
  static void userAction(String action, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      print('👤 $_tag: $action');
      if (data != null) {
        print('   Data: $data');
      }
    }
  }
}
