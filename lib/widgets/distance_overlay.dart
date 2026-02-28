import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:petanque_score/models/game.dart';

const Map<String, Color> _markerColors = {
  'cochonnet': Color(0xFF84CC16),
  'team1': Color(0xFF2563EB),
  'team2': Color(0xFFDC2626),
};

class DistanceOverlay extends StatefulWidget {
  final String photoUri;
  final List<Marker> markers;
  final List<BouleDistance> distances;
  final int closestTeamId;
  final int pointsScored;
  final String team1Name;
  final String team2Name;
  final VoidCallback onDetails;
  final VoidCallback onApply;

  const DistanceOverlay({
    super.key,
    required this.photoUri,
    required this.markers,
    required this.distances,
    required this.closestTeamId,
    required this.pointsScored,
    required this.team1Name,
    required this.team2Name,
    required this.onDetails,
    required this.onApply,
  });

  @override
  State<DistanceOverlay> createState() => _DistanceOverlayState();
}

class _DistanceOverlayState extends State<DistanceOverlay> {
  final TransformationController _transformController =
      TransformationController();
  Size _imageSize = Size.zero;
  Size _containerSize = Size.zero;
  bool _imageLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
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

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final winnerColor = widget.closestTeamId == 1
        ? _markerColors['team1']!
        : _markerColors['team2']!;
    final winnerName =
        widget.closestTeamId == 1 ? widget.team1Name : widget.team2Name;

    return Column(
      children: [
        // Winner banner
        Container(
          width: double.infinity,
          color: winnerColor,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Text(
            '$winnerName marque ${widget.pointsScored} point${widget.pointsScored > 1 ? 's' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Photo + overlay
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

              return Stack(
                children: [
                  InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 1.0,
                    maxScale: 8.0,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    child: SizedBox(
                      width: _containerSize.width,
                      height: _containerSize.height,
                      child: _imageLoaded
                          ? CustomPaint(
                              foregroundPainter: _DistanceOverlayPainter(
                                markers: widget.markers,
                                distances: widget.distances,
                                displayedSize: displayedSize,
                                imgOffset: Offset(imgOffsetX, imgOffsetY),
                              ),
                              child: Center(
                                child: Image.file(
                                  File(widget.photoUri),
                                  width: displayedSize.width,
                                  height: displayedSize.height,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                          : const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white)),
                    ),
                  ),

                  // Reset zoom button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: _resetZoom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.restart_alt,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Bottom bar
        Container(
          color: const Color(0xFF1E293B),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: widget.onDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Détails',
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
                    onPressed: widget.onApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: winnerColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Appliquer au score',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DistanceOverlayPainter extends CustomPainter {
  final List<Marker> markers;
  final List<BouleDistance> distances;
  final Size displayedSize;
  final Offset imgOffset;

  _DistanceOverlayPainter({
    required this.markers,
    required this.distances,
    required this.displayedSize,
    required this.imgOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (markers.isEmpty || distances.isEmpty) return;

    // Find cochonnet
    final cochonnet = markers.where((m) => m.type == 'cochonnet').firstOrNull;
    if (cochonnet == null) return;

    final cochX = imgOffset.dx + cochonnet.x * displayedSize.width;
    final cochY = imgOffset.dy + cochonnet.y * displayedSize.height;
    final cochCenter = Offset(cochX, cochY);

    // Sort distances by rank
    final sortedDistances = List<BouleDistance>.from(distances)
      ..sort((a, b) => a.rank.compareTo(b.rank));

    // Draw concentric dashed circles from cochonnet to each boule
    for (final bd in sortedDistances) {
      final bouleMarker =
          markers.where((m) => m.id == bd.markerId).firstOrNull;
      if (bouleMarker == null) continue;

      final bx = imgOffset.dx + bouleMarker.x * displayedSize.width;
      final by = imgOffset.dy + bouleMarker.y * displayedSize.height;
      final centerDist = (Offset(bx, by) - cochCenter).distance;
      // Subtract boule radius to reach tangent (edge) instead of center
      final boulePixelR = bouleMarker.circleRadius * displayedSize.width;
      final dist = (centerDist - boulePixelR).clamp(0.0, double.infinity);

      // Dashed circle
      _drawDashedCircle(
        canvas,
        cochCenter,
        dist,
        const Color(0xFF22D3EE), // cyan
        1.5,
      );
    }

    // Draw cochonnet marker
    final cochPixelR = cochonnet.circleRadius * displayedSize.width;
    final cochPaint = Paint()
      ..color = _markerColors['cochonnet']!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(cochCenter, math.max(cochPixelR, 6), cochPaint);
    final cochBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(cochCenter, math.max(cochPixelR, 6), cochBorder);

    // Draw boule markers with rank numbers
    for (final bd in sortedDistances) {
      final bouleMarker =
          markers.where((m) => m.id == bd.markerId).firstOrNull;
      if (bouleMarker == null) continue;

      final bx = imgOffset.dx + bouleMarker.x * displayedSize.width;
      final by = imgOffset.dy + bouleMarker.y * displayedSize.height;
      final teamColor = bd.teamId == 1
          ? _markerColors['team1']!
          : _markerColors['team2']!;

      // Circle background
      final bgPaint = Paint()
        ..color = teamColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(bx, by), 14, bgPaint);

      // White border
      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(bx, by), 14, borderPaint);

      // Rank number
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${bd.rank}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          bx - textPainter.width / 2,
          by - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius,
      Color color, double strokeWidth) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dashLength = 6.0;
    const gapLength = 4.0;
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
  bool shouldRepaint(covariant _DistanceOverlayPainter oldDelegate) => true;
}
