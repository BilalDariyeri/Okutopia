import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart';

/// Animation Controller Pool Manager for performance optimization
/// Prevents memory leaks by properly managing AnimationController lifecycle
class AnimationManager {
  static final Map<String, AnimationController> _controllers = {};
  static final Map<String, TickerProvider> _vsyncProviders = {};

  /// Get or create an AnimationController with the given key
  static AnimationController getController(
    String key,
    TickerProvider vsync, {
    Duration? duration,
    String? debugLabel,
  }) {
    // Return existing controller if available and not disposed
    if (_controllers.containsKey(key) && _controllers[key] != null) {
      if (!_controllers[key]!.isDismissed && !_controllers[key]!.isCompleted) {
        debugPrint('♻️  Reusing animation controller: $key');
        return _controllers[key]!;
      } else {
        // Controller is disposed, remove it
        debugPrint('🗑️  Removing disposed controller: $key');
        _controllers.remove(key);
        _vsyncProviders.remove(key);
      }
    }

    debugPrint('🎬 Creating new animation controller: ${debugLabel ?? key}');
    final controller = AnimationController(
      duration: duration ?? const Duration(seconds: 2),
      vsync: vsync,
      debugLabel: debugLabel,
    );
    
    _controllers[key] = controller;
    _vsyncProviders[key] = vsync;
    
    return controller;
  }

  /// Dispose a specific controller
  static void disposeController(String key) {
    if (_controllers.containsKey(key)) {
      final controller = _controllers[key];
      if (controller != null) {
        debugPrint('🗑️  Disposing animation controller: $key');
        controller.dispose();
      }
      _controllers.remove(key);
      _vsyncProviders.remove(key);
    }
  }

  /// Dispose all controllers (call on app exit)
  static void disposeAll() {
    debugPrint('🗑️  Disposing all ${_controllers.length} animation controllers');
    
    _controllers.forEach((key, controller) {
      if (controller != null) {
        debugPrint('🗑️  Disposing: $key');
        controller.dispose();
      }
    });
    
    _controllers.clear();
    _vsyncProviders.clear();
  }

  /// Check if a controller exists
  static bool hasController(String key) {
    return _controllers.containsKey(key) && _controllers[key] != null;
  }

  /// Get all active controller keys
  static List<String> getActiveKeys() {
    return _controllers.keys.where((key) => _controllers[key] != null).toList();
  }

  /// Get controller status for debugging
  static Map<String, dynamic> getControllerStatus(String key) {
    final controller = _controllers[key];
    if (controller == null) {
      return {
        'exists': false,
        'status': 'not_found',
      };
    }

    return {
      'exists': true,
      'status': controller.isDismissed 
          ? 'dismissed' 
          : controller.isCompleted 
              ? 'completed' 
              : 'animating',
      'isAnimating': controller.isAnimating,
      'value': controller.value,
      'debugLabel': controller.debugLabel,
    };
  }

  /// Debug info about all controllers
  static Map<String, dynamic> getDebugInfo() {
    final info = <String, dynamic>{
      'totalControllers': _controllers.length,
      'activeControllers': <String, dynamic>{},
    };

    _controllers.forEach((key, controller) {
      if (controller != null) {
        info['activeControllers'][key] = getControllerStatus(key);
      }
    });

    return info;
  }
}

/// Extension for easier usage in StatefulWidgets with TickerProvider
extension AnimationManagerExtension on State<StatefulWidget> {
  /// Get animation controller for this state
  AnimationController getAnimController(
    String key, {
    Duration? duration,
    String? debugLabel,
  }) {
    if (this is TickerProvider) {
      return AnimationManager.getController(
        '${widget.runtimeType}_$key',
        this as TickerProvider,
        duration: duration,
        debugLabel: debugLabel,
      );
    }
    throw StateError('This State must mixin TickerProviderStateMixin or SingleTickerProviderStateMixin');
  }

  /// Dispose animation controller for this state
  void disposeAnimController(String key) {
    AnimationManager.disposeController('${widget.runtimeType}_$key');
  }

  /// Dispose all animation controllers for this state
  void disposeAllAnimControllers() {
    final prefix = '${widget.runtimeType}_';
    AnimationManager.getActiveKeys()
        .where((key) => key.startsWith(prefix))
        .forEach((key) => AnimationManager.disposeController(key));
  }
}

