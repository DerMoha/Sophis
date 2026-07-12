import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:sophis/ui/theme/app_theme.dart';

class NutritionLabelCameraScreen extends StatefulWidget {
  final String title;
  final String guidance;

  const NutritionLabelCameraScreen({
    super.key,
    required this.title,
    required this.guidance,
  });

  @override
  State<NutritionLabelCameraScreen> createState() =>
      _NutritionLabelCameraScreenState();
}

class _NutritionLabelCameraScreenState extends State<NutritionLabelCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _camera;
  bool _initializing = true;
  bool _capturing = false;
  bool _torchEnabled = false;
  String? _error;
  Offset? _focusPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera available');
      _camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await _openCamera();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _openCamera() async {
    final camera = _camera;
    if (camera == null) return;
    final controller = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    await controller.initialize();
    await controller.setFlashMode(FlashMode.off);
    if (!mounted) return;
    setState(() {
      _initializing = false;
      _error = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _openCamera();
    }
  }

  Future<void> _focus(TapDownDetails details, Size size) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final point = Offset(
      (details.localPosition.dx / size.width).clamp(0, 1),
      (details.localPosition.dy / size.height).clamp(0, 1),
    );
    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
      if (!mounted) return;
      setState(() => _focusPoint = details.localPosition);
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _focusPoint = null);
      });
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    final enabled = !_torchEnabled;
    try {
      await controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchEnabled = enabled);
    } catch (_) {}
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      Navigator.pop(context, image);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = error.toString();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!_initializing &&
              controller != null &&
              controller.value.isInitialized)
            LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final previewSize = controller.value.previewSize;
                return GestureDetector(
                  onTapDown: (details) => _focus(details, size),
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: previewSize?.height ?? size.width,
                        height: previewSize?.width ?? size.height,
                        child: CameraPreview(controller),
                      ),
                    ),
                  ),
                );
              },
            )
          else
            const Center(child: CircularProgressIndicator()),
          const _NutritionTableOverlay(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: widget.title,
                  torchEnabled: _torchEnabled,
                  onClose: () => Navigator.pop(context),
                  onTorch: _toggleTorch,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.guidance,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: const [Shadow(blurRadius: 6)],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _ShutterButton(onPressed: _capturing ? null : _capture),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_focusPoint case final point?)
            Positioned(
              left: point.dx - 24,
              top: point.dy - 24,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amber, width: 2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
              ),
            ),
          if (_error case final error?)
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.only(top: 72, left: 24, right: 24),
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade900,
                  child:
                      Text(error, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final bool torchEnabled;
  final VoidCallback onClose;
  final VoidCallback onTorch;

  const _TopBar({
    required this.title,
    required this.torchEnabled,
    required this.onClose,
    required this.onTorch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: onTorch,
            icon: Icon(torchEnabled ? Icons.flash_on : Icons.flash_off),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _ShutterButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 76,
        height: 76,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onPressed == null ? Colors.white54 : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _NutritionTableOverlay extends StatelessWidget {
  const _NutritionTableOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _NutritionTableOverlayPainter()),
    );
  }
}

class _NutritionTableOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = size.width * 0.88;
    final frameHeight = frameWidth / 1.25;
    final frame = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: frameWidth,
      height: frameHeight,
    );
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(18)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(shade, Paint()..color = Colors.black54);

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const corner = 30.0;
    for (final segments in [
      [
        frame.topLeft + const Offset(corner, 0),
        frame.topLeft,
        frame.topLeft + const Offset(0, corner),
      ],
      [
        frame.topRight - const Offset(corner, 0),
        frame.topRight,
        frame.topRight + const Offset(0, corner),
      ],
      [
        frame.bottomLeft + const Offset(0, -corner),
        frame.bottomLeft,
        frame.bottomLeft + const Offset(corner, 0),
      ],
      [
        frame.bottomRight + const Offset(0, -corner),
        frame.bottomRight,
        frame.bottomRight + const Offset(-corner, 0),
      ],
    ]) {
      canvas.drawLine(segments[0], segments[1], paint);
      canvas.drawLine(segments[1], segments[2], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
