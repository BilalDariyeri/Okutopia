import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Simple logging utility to replace print statements
class AppLogger {
  static const String _tag = 'OKUTOPIA';
  
  /// Debug level logging (only in debug mode)
  static void debug(String message) {
    if (kDebugMode) {
      developer.log('🔍 $message', name: _tag);
    }
  }
  
  /// Info level logging (shows in both debug and release)
  static void info(String message) {
    developer.log('ℹ️ $message', name: _tag);
  }
  
  /// Warning level logging
  static void warning(String message) {
    developer.log('⚠️ $message', name: _tag, level: 900); // Warning level
  }
  
  /// Error level logging
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    developer.log(
      '❌ $message',
      name: _tag,
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  /// Network request logging
  static void network(String method, String url, {int? statusCode, String? response}) {
    if (kDebugMode) {
      final buffer = StringBuffer('🌐 $method $url');
      if (statusCode != null) {
        buffer.write('\n   Status: $statusCode');
      }
      if (response != null) {
        buffer.write('\n   Response: $response');
      }
      developer.log(buffer.toString(), name: _tag);
    }
  }
  
  /// User action logging
  static void userAction(String action, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      final buffer = StringBuffer('👤 $action');
      if (data != null) {
        buffer.write('\n   Data: $data');
      }
      developer.log(buffer.toString(), name: _tag);
    }
  }
}
