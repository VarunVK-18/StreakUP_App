import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Interactive Circle Crop & Grid Alignment Screen.
/// Provides a draggable, pinch-to-zoom image viewer overlaid with a circular mask
/// and a 3x3 photographer rule-of-thirds grid for perfect profile alignment.
class CircleCropScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const CircleCropScreen({
    super.key,
    required this.imageBytes,
  });

  @override
  State<CircleCropScreen> createState() => _CircleCropScreenState();
}

class _CircleCropScreenState extends State<CircleCropScreen> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _cropAndDone() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null && mounted) {
          final pngBytes = byteData.buffer.asUint8List();
          Navigator.pop(context, pngBytes);
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isProcessing = false);
      Navigator.pop(context, widget.imageBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double circleDiameter = 280.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Position & Crop',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Reset Position',
            onPressed: () {
              _transformController.value = Matrix4.identity();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Drag or pinch to align your face inside the circle',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const Spacer(),
            Center(
              child: SizedBox(
                width: circleDiameter,
                height: circleDiameter,
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Interactive Zoomable Image captured cleanly inside RepaintBoundary
                      RepaintBoundary(
                        key: _cropKey,
                        child: Container(
                          color: Colors.black,
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 0.8,
                            maxScale: 4.0,
                            boundaryMargin: const EdgeInsets.all(double.infinity),
                            child: Center(
                              child: Image.memory(
                                widget.imageBytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 3x3 Grid Overlay & Guide (Outside RepaintBoundary so it's NOT captured in the photo!)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _GridAndCircleOverlayPainter(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            // Bottom Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isProcessing ? null : _cropAndDone,
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Choose',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridAndCircleOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw outer circular border guide
    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1,
      circlePaint,
    );

    // 2. Draw 3x3 Rule-of-Thirds Grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double stepX = size.width / 3;
    final double stepY = size.height / 3;

    // Vertical lines
    canvas.drawLine(Offset(stepX, 0), Offset(stepX, size.height), gridPaint);
    canvas.drawLine(Offset(stepX * 2, 0), Offset(stepX * 2, size.height), gridPaint);

    // Horizontal lines
    canvas.drawLine(Offset(0, stepY), Offset(size.width, stepY), gridPaint);
    canvas.drawLine(Offset(0, stepY * 2), Offset(size.width, stepY * 2), gridPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
