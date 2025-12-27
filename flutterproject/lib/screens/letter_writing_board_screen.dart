import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/mini_question_model.dart';
import '../models/activity_model.dart';
import '../config/api_config.dart';


class LetterWritingBoardScreen extends StatefulWidget {
  final Activity activity;
  final List<MiniQuestion> questions;
  final int currentQuestionIndex;

  const LetterWritingBoardScreen({
    super.key,
    required this.activity,
    required this.questions,
    this.currentQuestionIndex = 0,
  });

  @override
  State<LetterWritingBoardScreen> createState() => _LetterWritingBoardScreenState();
}

class _LetterWritingBoardScreenState extends State<LetterWritingBoardScreen> {
  final List<List<Offset>> _paths = [];
  final List<Color> _pathColors = [];
  final List<bool> _pathErasing = [];
  Color _currentColor = Colors.black;
  bool _isErasing = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  String? _videoError;
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    final question = widget.questions[widget.currentQuestionIndex];
    
    // Video dosya ID'sini al (videoFileId veya mediaFileId)
    String? videoFileId;
    if (question.data?['videoFileId'] != null) {
      videoFileId = question.data!['videoFileId'].toString();
    } else if (question.mediaFileId != null && question.mediaType == 'Video') {
      videoFileId = question.mediaFileId.toString();
    }

    if (videoFileId != null && videoFileId.isNotEmpty) {
      final videoUrl = _getFileUrl(videoFileId);
      print('📹 Video URL: $videoUrl');
      
      // Hem web hem mobil için video_player kullan (web'de de çalışır)
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );

      _videoController!.initialize().then((_) {
        print('✅ Video başarıyla yüklendi');
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
            _videoError = null;
          });
          _videoController!.setLooping(true);
          _videoController!.play();
        }
      }).catchError((error) {
        print('❌ Video yüklenemedi: $error');
        print('❌ Video URL: $videoUrl');
        if (mounted) {
          setState(() {
            _isVideoInitialized = false;
            _videoError = error.toString();
          });
        }
      });
    } else {
      print('⚠️ Video dosya ID bulunamadı');
      print('   question.data: ${question.data}');
      print('   question.mediaFileId: ${question.mediaFileId}');
      print('   question.mediaType: ${question.mediaType}');
    }
  }

  String _getFileUrl(String? fileId) {
    if (fileId == null) return '';
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    return '$baseUrl/api/files/$fileId';
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      print('⚠️ RenderBox bulunamadı');
      return;
    }
    
    final localPosition = box.globalToLocal(details.globalPosition);
    print('🎨 Çizim başladı: $localPosition');
    
    setState(() {
      _paths.add([localPosition]);
      _pathColors.add(_currentColor);
      _pathErasing.add(_isErasing);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _paths.isEmpty) return;
    
    final localPosition = box.globalToLocal(details.globalPosition);
    
    setState(() {
      if (_paths.isNotEmpty && _paths.last.isNotEmpty) {
        _paths.last.add(localPosition);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Path zaten sonlandırılmış durumda
  }

  void _clearCanvas() {
    setState(() {
      _paths.clear();
      _pathColors.clear();
      _pathErasing.clear();
    });
  }

  void _selectColor(Color color) {
    setState(() {
      _currentColor = color;
      _isErasing = false;
    });
  }

  void _toggleEraser() {
    setState(() {
      _isErasing = !_isErasing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: Row(
        children: [
          // Sol sidebar - Video
          Container(
            width: MediaQuery.of(context).size.width * 0.25,
            color: Colors.white,
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.22,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: _isVideoInitialized && 
                       _videoController != null && 
                       _videoController!.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : _videoError != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Video yüklenemedi',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    _videoError!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  'Video yükleniyor...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
          ),
          // Sağ ana alan - Canvas
          Expanded(
            child: Stack(
              children: [
                // Notebook (defter görünümü)
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 400,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: 400,
                        child: CustomPaint(
                          key: _canvasKey,
                          painter: NotebookPainter(_paths, _pathColors, _pathErasing),
                        ),
                      ),
                    ),
                  ),
                ),
                // Renk paleti ve butonlar
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildColorButton(Colors.black),
                          const SizedBox(width: 10),
                          _buildColorButton(Colors.red),
                          const SizedBox(width: 10),
                          _buildColorButton(Colors.green),
                          const SizedBox(width: 10),
                          _buildColorButton(Colors.blue),
                          const SizedBox(width: 10),
                          _buildColorButton(Colors.orange),
                          const SizedBox(width: 10),
                          _buildEraserButton(),
                          const SizedBox(width: 10),
                          _buildClearButton(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    return GestureDetector(
      onTap: () => _selectColor(color),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildEraserButton() {
    return GestureDetector(
      onTap: _toggleEraser,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _isErasing ? const Color(0xFFFFCCCB) : Colors.grey.shade200,
          border: Border.all(
            color: _isErasing ? const Color(0xFFF44336) : Colors.grey.shade400,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Text(
            '🧽',
            style: TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildClearButton() {
    return GestureDetector(
      onTap: _clearCanvas,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border.all(
            color: Colors.grey.shade400,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Text(
            '🧹',
            style: TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }
}

class NotebookPainter extends CustomPainter {
  final List<List<Offset>> paths;
  final List<Color> pathColors;
  final List<bool> pathErasing;

  NotebookPainter(this.paths, this.pathColors, this.pathErasing);

  @override
  void paint(Canvas canvas, Size size) {
    // Defter arka planı (üst yarı beyaz, alt yarı sarı)
    final whiteRect = Rect.fromLTWH(0, 0, size.width, size.height / 2);
    final yellowRect = Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2);
    
    canvas.drawRect(whiteRect, Paint()..color = Colors.white);
    canvas.drawRect(yellowRect, Paint()..color = const Color(0xFFFAF9B4));

    // Tüm path'leri çiz
    for (int i = 0; i < paths.length; i++) {
      if (paths[i].length < 2) continue;

      final paint = Paint()
        ..strokeWidth = pathErasing[i] ? 20.0 : 12.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (pathErasing[i]) {
        // Silgi için arka plan rengini kullan (beyaz veya sarı)
        paint.blendMode = BlendMode.srcOver;
        // Path'in orta noktasını kullanarak hangi yarıda olduğunu belirle
        final midY = (paths[i].first.dy + paths[i].last.dy) / 2;
        paint.color = midY < size.height / 2 ? Colors.white : const Color(0xFFFAF9B4);
      } else {
        paint.blendMode = BlendMode.srcOver;
        paint.color = pathColors[i];
      }

      for (int j = 0; j < paths[i].length - 1; j++) {
        canvas.drawLine(paths[i][j], paths[i][j + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(NotebookPainter oldDelegate) {
    // Her zaman repaint et (performans için optimize edilebilir ama şimdilik güvenli)
    return true;
  }
}

