// Web-specific implementation
import 'dart:html' as html;
import 'dart:ui' as ui;

dynamic createVideoElement(String videoUrl, String viewId, Function(dynamic)? onError, Function()? onLoaded) {
  final videoElement = html.VideoElement()
    ..src = videoUrl
    ..autoplay = true
    ..loop = true
    ..muted = true
    ..controls = false
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'contain'
    ..crossOrigin = 'anonymous';

  // Error handling
  if (onError != null) {
    videoElement.onError.listen((event) {
      onError(videoElement);
    });
  }

  // Loaded event
  if (onLoaded != null) {
    videoElement.onLoadedData.listen((event) {
      onLoaded();
    });
  }

  ui.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) => videoElement,
  );

  return videoElement;
}

