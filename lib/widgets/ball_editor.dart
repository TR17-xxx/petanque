import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:petanque_score/models/game.dart';

const Map<String, Color> _markerColors = {
  'cochonnet': Color(0xFF84CC16),
  'team1': Color(0xFF2563EB),
  'team2': Color(0xFFDC2626),
};

const double _minRadius = 0.008;
const double _maxRadius = 0.1;
const double _minZoom = 0.08;
const double _maxZoom = 0.5;

class BallEditor extends StatefulWidget {
  final String photoUri;
  final Marker marker;
  final int imageWidth;
  final int imageHeight;
  final ValueChanged<Marker> onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const BallEditor({
    super.key,
    required this.photoUri,
    required this.marker,
    required this.imageWidth,
    required this.imageHeight,
    required this.onUpdate,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  State<BallEditor> createState() => _BallEditorState();
}

class _BallEditorState extends State<BallEditor> {
  late double _radius;
  late double _zoom; // crop area size (smaller = more zoomed in)
  late double _markerX; // relative 0-1
  late double _markerY; // relative 0-1

  @override
  void initState() {
    super.initState();
    _radius = widget.marker.circleRadius;
    _zoom = math.max(_radius * 10, 0.15).clamp(_minZoom, _maxZoom);
    _markerX = widget.marker.x;
    _markerY = widget.marker.y;
  }

  @override
  void didUpdateWidget(BallEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.marker.id != widget.marker.id) {
      _radius = widget.marker.circleRadius;
      _zoom = math.max(_radius * 10, 0.15).clamp(_minZoom, _maxZoom);
      _markerX = widget.marker.x;
      _markerY = widget.marker.y;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final color = _markerColors[widget.marker.type] ?? Colors.grey;

    // Crop zone: controlled by independent zoom slider
    final cropRelSize = _zoom;
    final displaySize = screenWidth - 32;
    final scaleFromImage = displaySize / (cropRelSize * widget.imageWidth);

    // Marker is always centered in the display
    final centerX = displaySize / 2;
    final centerY = displaySize / 2;
    final circlePixelR = _radius * widget.imageWidth * scaleFromImage;

    // Image offset to keep marker centered
    final imgDisplayW = widget.imageWidth * scaleFromImage;
    final imgDisplayH = widget.imageHeight * scaleFromImage;
    final imgOffsetX = centerX - _markerX * widget.imageWidth * scaleFromImage;
    final imgOffsetY = centerY - _markerY * widget.imageHeight * scaleFromImage;

    return Center(
      child: Container(
        width: displaySize + 16,
        decoration: BoxDecoration(
          color: const Color(0xFF94A3B8),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: const Color(0xFFD4A017),
              alignment: Alignment.center,
              child: const Text(
                'Ajustez la position et la taille',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),

            // Zoomed view with drag
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  // Convert pixel delta to relative coordinates
                  final dx = -details.delta.dx /
                      (widget.imageWidth * scaleFromImage);
                  final dy = -details.delta.dy /
                      (widget.imageHeight * scaleFromImage);
                  _markerX = (_markerX + dx).clamp(0.0, 1.0);
                  _markerY = (_markerY + dy).clamp(0.0, 1.0);
                });
              },
              child: Container(
                width: displaySize,
                height: displaySize,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Image (moves to keep marker centered)
                    Positioned(
                      left: imgOffsetX,
                      top: imgOffsetY,
                      child: Image.file(
                        File(widget.photoUri),
                        width: imgDisplayW,
                        height: imgDisplayH,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Overlay (crosshair + circle always at center)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BallEditorPainter(
                          markerX: centerX,
                          markerY: centerY,
                          radius: circlePixelR,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Zoom slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.zoom_in, size: 18, color: Color(0xFF475569)),
                  const SizedBox(width: 4),
                  const Text('Zoom',
                      style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  Expanded(
                    child: Slider(
                      value: _zoom,
                      min: _minZoom,
                      max: _maxZoom,
                      activeColor: const Color(0xFF64748B),
                      inactiveColor: const Color(0xFF475569),
                      onChanged: (v) => setState(() => _zoom = v),
                    ),
                  ),
                ],
              ),
            ),

            // Circle size slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.circle_outlined, size: 18, color: color),
                  const SizedBox(width: 4),
                  const Text('Taille',
                      style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  Expanded(
                    child: Slider(
                      value: _radius,
                      min: _minRadius,
                      max: _maxRadius,
                      activeColor: color,
                      inactiveColor: const Color(0xFF64748B),
                      onChanged: (v) => setState(() => _radius = v),
                    ),
                  ),
                ],
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  // Delete
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: widget.onDelete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Icon(Icons.delete, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cancel
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF94A3B8),
                          foregroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Annuler',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Validate
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => widget.onUpdate(
                          widget.marker.copyWith(
                            x: _markerX,
                            y: _markerY,
                            circleRadius: _radius,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF84CC16),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Valider',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
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

class _BallEditorPainter extends CustomPainter {
  final double markerX;
  final double markerY;
  final double radius;
  final Color color;

  _BallEditorPainter({
    required this.markerX,
    required this.markerY,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(markerX, markerY);

    // Fill
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    // Dashed circle
    _drawDashedCircle(canvas, center, radius, color, 2.0);

    // Crosshair
    final crossPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(markerX - radius - 8, markerY),
      Offset(markerX + radius + 8, markerY),
      crossPaint,
    );
    canvas.drawLine(
      Offset(markerX, markerY - radius - 8),
      Offset(markerX, markerY + radius + 8),
      crossPaint,
    );

    // Center dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, dotPaint);
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius,
      Color color, double strokeWidth) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dashLength = 8.0;
    const gapLength = 5.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    if (dashCount <= 0) return;

    for (var i = 0; i < dashCount; i++) {
      final startAngle =
          (i * (dashLength + gapLength) / circumference) * 2 * math.pi;
      final sweepAngle = (dashLength / circumference) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BallEditorPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.markerX != markerX ||
        oldDelegate.markerY != markerY;
  }
}
