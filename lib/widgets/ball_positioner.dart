import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:petanque_score/models/game.dart';
import 'package:petanque_score/utils/helpers.dart';

const Map<String, Color> _markerColors = {
  'cochonnet': Color(0xFF84CC16), // lime-green
  'team1': Color(0xFF2563EB), // blue
  'team2': Color(0xFFDC2626), // red
};

const double _defaultRadius = 0.03;
const double _minRadius = 0.008;
const double _maxRadius = 0.1;

class BallPositioner extends StatefulWidget {
  final String photoUri;
  final String markerType; // "cochonnet" | "team1" | "team2"
  final List<Marker> existingMarkers;
  final ValueChanged<Marker> onValidate;
  final VoidCallback onBack;
  final String? instructionText;

  const BallPositioner({
    super.key,
    required this.photoUri,
    required this.markerType,
    this.existingMarkers = const [],
    required this.onValidate,
    required this.onBack,
    this.instructionText,
  });

  @override
  State<BallPositioner> createState() => _BallPositionerState();
}

class _BallPositionerState extends State<BallPositioner> {
  final TransformationController _transformController =
      TransformationController();
  Size _imageSize = Size.zero;
  Size _containerSize = Size.zero;
  bool _imageLoaded = false;
  Marker? _marker;
  double _circleRadius = _defaultRadius;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(BallPositioner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUri != widget.photoUri) {
      _loadImageSize();
    }
  }

  void _loadImageSize() {
    final file = File(widget.photoUri);
    final image = FileImage(file);
    image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) {
        if (mounted) {
          setState(() {
            _imageSize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
            _imageLoaded = true;
          });
        }
      }),
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Size _getDisplayedImageSize() {
    if (_imageSize == Size.zero || _containerSize == Size.zero) {
      return _containerSize;
    }
    final imageAspect = _imageSize.width / _imageSize.height;
    final containerAspect = _containerSize.width / _containerSize.height;
    if (imageAspect > containerAspect) {
      final w = _containerSize.width;
      return Size(w, w / imageAspect);
    } else {
      final h = _containerSize.height;
      return Size(h * imageAspect, h);
    }
  }

  Offset? _tapToRelative(Offset localPosition) {
    if (_containerSize == Size.zero) return null;
    final matrix = _transformController.value;
    final inverseMatrix = Matrix4.inverted(matrix);
    final transformed =
        MatrixUtils.transformPoint(inverseMatrix, localPosition);
    final displayedSize = _getDisplayedImageSize();
    final offsetX = (_containerSize.width - displayedSize.width) / 2;
    final offsetY = (_containerSize.height - displayedSize.height) / 2;
    final relX = (transformed.dx - offsetX) / displayedSize.width;
    final relY = (transformed.dy - offsetY) / displayedSize.height;
    if (relX >= 0 && relX <= 1 && relY >= 0 && relY <= 1) {
      return Offset(relX, relY);
    }
    return null;
  }

  void _onTapUp(TapUpDetails details) {
    final rel = _tapToRelative(details.localPosition);
    if (rel == null) return;
    setState(() {
      _marker = Marker(
        id: _marker?.id ?? generateId(),
        x: rel.dx,
        y: rel.dy,
        type: widget.markerType,
        circleRadius: _circleRadius,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _markerColors[widget.markerType] ?? Colors.grey;
    final canValidate = _marker != null;

    return Column(
      children: [
        // Instruction text
        if (widget.instructionText != null)
          Container(
            width: double.infinity,
            color: Colors.black.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              widget.instructionText!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Photo with overlay
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _containerSize =
                  Size(constraints.maxWidth, constraints.maxHeight);
              final displayedSize = _getDisplayedImageSize();
              final imgOffsetX =
                  (_containerSize.width - displayedSize.width) / 2;
              final imgOffsetY =
                  (_containerSize.height - displayedSize.height) / 2;

              return GestureDetector(
                onTapUp: _onTapUp,
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 1.0,
                  maxScale: 8.0,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: SizedBox(
                    width: _containerSize.width,
                    height: _containerSize.height,
                    child: _imageLoaded
                        ? CustomPaint(
                            foregroundPainter: _BallPositionerPainter(
                              image: FileImage(File(widget.photoUri)),
                              imageSize: _imageSize,
                              containerSize: _containerSize,
                              displayedSize: displayedSize,
                              imgOffset: Offset(imgOffsetX, imgOffsetY),
                              marker: _marker,
                              circleRadius: _circleRadius,
                              existingMarkers: widget.existingMarkers,
                              color: color,
                            ),
                            child: Image.file(
                              File(widget.photoUri),
                              width: _containerSize.width,
                              height: _containerSize.height,
                              fit: BoxFit.contain,
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),

        // Slider + buttons
        Container(
          color: const Color(0xFF1E293B),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Slider (only when marker is placed)
              if (_marker != null) ...[
                const Text(
                  'Taille du cercle',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('−',
                        style: TextStyle(
                            color: Color(0xFF64748B), fontSize: 11)),
                    Expanded(
                      child: Slider(
                        value: _circleRadius,
                        min: _minRadius,
                        max: _maxRadius,
                        activeColor: color,
                        inactiveColor: const Color(0xFF475569),
                        onChanged: (v) {
                          setState(() {
                            _circleRadius = v;
                            _marker = _marker!.copyWith(circleRadius: v);
                          });
                        },
                      ),
                    ),
                    const Text('+',
                        style: TextStyle(
                            color: Color(0xFF64748B), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: widget.onBack,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Retour',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: canValidate
                            ? () => widget.onValidate(
                                _marker!.copyWith(circleRadius: _circleRadius))
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              canValidate ? color : const Color(0xFF475569),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF475569).withValues(alpha: 0.5),
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Valider',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// CustomPainter that draws the existing markers and the active marker circle
class _BallPositionerPainter extends CustomPainter {
  final FileImage image;
  final Size imageSize;
  final Size containerSize;
  final Size displayedSize;
  final Offset imgOffset;
  final Marker? marker;
  final double circleRadius;
  final List<Marker> existingMarkers;
  final Color color;

  _BallPositionerPainter({
    required this.image,
    required this.imageSize,
    required this.containerSize,
    required this.displayedSize,
    required this.imgOffset,
    required this.marker,
    required this.circleRadius,
    required this.existingMarkers,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw existing markers (read-only)
    for (final m in existingMarkers) {
      final mx = imgOffset.dx + m.x * displayedSize.width;
      final my = imgOffset.dy + m.y * displayedSize.height;
      final mr = m.circleRadius * displayedSize.width;
      final mc = _markerColors[m.type] ?? Colors.grey;

      final fillPaint = Paint()
        ..color = mc.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(mx, my), mr, fillPaint);

      _drawDashedCircle(canvas, Offset(mx, my), mr, mc, 1.5);
    }

    // Draw active marker
    if (marker != null) {
      final mx = imgOffset.dx + marker!.x * displayedSize.width;
      final my = imgOffset.dy + marker!.y * displayedSize.height;
      final pixelR = circleRadius * displayedSize.width;

      // Fill
      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(mx, my), pixelR, fillPaint);

      // Dashed circle
      _drawDashedCircle(canvas, Offset(mx, my), pixelR, color, 2.0);

      // Crosshair
      final crossPaint = Paint()
        ..color = color.withValues(alpha: 0.6)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(mx - pixelR - 5, my),
        Offset(mx + pixelR + 5, my),
        crossPaint,
      );
      canvas.drawLine(
        Offset(mx, my - pixelR - 5),
        Offset(mx, my + pixelR + 5),
        crossPaint,
      );

      // Center dot
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(mx, my), 3, dotPaint);
    }
  }

  void _drawDashedCircle(
      Canvas canvas, Offset center, double radius, Color color, double strokeWidth) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dashLength = 8.0;
    const gapLength = 5.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();

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
  bool shouldRepaint(covariant _BallPositionerPainter oldDelegate) {
    return oldDelegate.marker != marker ||
        oldDelegate.circleRadius != circleRadius ||
        oldDelegate.existingMarkers != existingMarkers;
  }
}
