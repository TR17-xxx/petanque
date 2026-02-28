import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:petanque_score/models/game.dart';
import 'package:petanque_score/utils/helpers.dart';

const double _markerSize = 32.0;
const double _deleteButtonSize = 22.0;

const Map<String, Color> _markerColors = {
  'cochonnet': Color(0xFFF59E0B), // amber
  'team1': Color(0xFF2563EB), // blue
  'team2': Color(0xFFDC2626), // red
};

class PhotoMarkerWidget extends StatefulWidget {
  final String photoUri;
  final List<Marker> markers;
  final String activeMarkerType; // "cochonnet" | "team1" | "team2"
  final ValueChanged<List<Marker>> onMarkersChange;

  const PhotoMarkerWidget({
    super.key,
    required this.photoUri,
    required this.markers,
    required this.activeMarkerType,
    required this.onMarkersChange,
  });

  @override
  State<PhotoMarkerWidget> createState() => _PhotoMarkerWidgetState();
}

class _PhotoMarkerWidgetState extends State<PhotoMarkerWidget> {
  final TransformationController _transformController =
      TransformationController();
  Size _imageSize = Size.zero;
  Size _containerSize = Size.zero;
  bool _imageLoaded = false;
  bool _deletedRecently = false;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(PhotoMarkerWidget oldWidget) {
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

  /// Convert a local tap position to image-relative (0-1) coordinates,
  /// accounting for the current zoom/pan transform.
  Offset? _tapToRelative(Offset localPosition) {
    if (_containerSize == Size.zero) return null;

    // Invert the transform to get the position in the untransformed image space
    final matrix = _transformController.value;
    final inverseMatrix = Matrix4.inverted(matrix);
    final transformed = MatrixUtils.transformPoint(inverseMatrix, localPosition);

    // Calculate the displayed image dimensions within the container
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

  /// Get the displayed size of the image within the container (BoxFit.contain).
  Size _getDisplayedImageSize() {
    if (_imageSize == Size.zero || _containerSize == Size.zero) {
      return _containerSize;
    }
    final imageAspect = _imageSize.width / _imageSize.height;
    final containerAspect = _containerSize.width / _containerSize.height;

    if (imageAspect > containerAspect) {
      // Image is wider - fit to width
      final w = _containerSize.width;
      final h = w / imageAspect;
      return Size(w, h);
    } else {
      // Image is taller - fit to height
      final h = _containerSize.height;
      final w = h * imageAspect;
      return Size(w, h);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_deletedRecently) {
      _deletedRecently = false;
      return;
    }

    final rel = _tapToRelative(details.localPosition);
    if (rel == null) return;

    final newMarker = Marker(
      id: generateId(),
      x: rel.dx,
      y: rel.dy,
      type: widget.activeMarkerType,
    );

    if (widget.activeMarkerType == 'cochonnet') {
      // Replace existing cochonnet (only 1 allowed)
      final filtered =
          widget.markers.where((m) => m.type != 'cochonnet').toList();
      widget.onMarkersChange([...filtered, newMarker]);
    } else {
      // Append boule
      widget.onMarkersChange([...widget.markers, newMarker]);
    }
  }

  void _onMoveMarker(String markerId, double newX, double newY) {
    final updated = widget.markers.map((m) {
      if (m.id == markerId) {
        return m.copyWith(
          x: newX.clamp(0.0, 1.0),
          y: newY.clamp(0.0, 1.0),
        );
      }
      return m;
    }).toList();
    widget.onMarkersChange(updated);
  }

  void _onDeleteMarker(String markerId) {
    _deletedRecently = true;
    widget.onMarkersChange(
      widget.markers.where((m) => m.id != markerId).toList(),
    );
    // Reset flag after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _deletedRecently = false;
      }
    });
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        final displayedSize = _getDisplayedImageSize();
        final offsetX = (_containerSize.width - displayedSize.width) / 2;
        final offsetY = (_containerSize.height - displayedSize.height) / 2;

        return Stack(
          children: [
            // InteractiveViewer for zoom/pan
            GestureDetector(
              onTapUp: _onTapUp,
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 1.0,
                maxScale: 5.0,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: SizedBox(
                  width: _containerSize.width,
                  height: _containerSize.height,
                  child: Stack(
                    children: [
                      // Image
                      Center(
                        child: _imageLoaded
                            ? Image.file(
                                File(widget.photoUri),
                                width: displayedSize.width,
                                height: displayedSize.height,
                                fit: BoxFit.contain,
                              )
                            : const CircularProgressIndicator(),
                      ),

                      // Markers overlaid on the image
                      ...widget.markers.map((marker) {
                        final markerLeft =
                            offsetX + marker.x * displayedSize.width - _markerSize / 2;
                        final markerTop =
                            offsetY + marker.y * displayedSize.height - _markerSize / 2;
                        final color = _markerColors[marker.type] ??
                            const Color(0xFF94A3B8);

                        return Positioned(
                          left: markerLeft,
                          top: markerTop,
                          child: _DraggableMarker(
                            marker: marker,
                            color: color,
                            displayedSize: displayedSize,
                            onMove: (newX, newY) =>
                                _onMoveMarker(marker.id, newX, newY),
                            onDelete: () => _onDeleteMarker(marker.id),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Reset zoom button (top-right corner)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: _resetZoom,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.rotateCcw,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A single draggable marker circle with delete button.
class _DraggableMarker extends StatefulWidget {
  final Marker marker;
  final Color color;
  final Size displayedSize;
  final void Function(double newX, double newY) onMove;
  final VoidCallback onDelete;

  const _DraggableMarker({
    required this.marker,
    required this.color,
    required this.displayedSize,
    required this.onMove,
    required this.onDelete,
  });

  @override
  State<_DraggableMarker> createState() => _DraggableMarkerState();
}

class _DraggableMarkerState extends State<_DraggableMarker> {
  Offset _dragDelta = Offset.zero;
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _dragDelta,
      child: Transform.scale(
        scale: _scale,
        child: SizedBox(
          width: _markerSize + _deleteButtonSize,
          height: _markerSize + _deleteButtonSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Marker circle (centered with extra space for delete button)
              Positioned(
                left: 0,
                top: _deleteButtonSize / 2,
                child: GestureDetector(
                  onPanStart: (_) {
                    setState(() => _scale = 1.3);
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _dragDelta += details.delta;
                    });
                  },
                  onPanEnd: (_) {
                    setState(() => _scale = 1.0);
                    // Calculate new relative position
                    final deltaX = _dragDelta.dx / widget.displayedSize.width;
                    final deltaY = _dragDelta.dy / widget.displayedSize.height;
                    final newX = widget.marker.x + deltaX;
                    final newY = widget.marker.y + deltaY;
                    setState(() => _dragDelta = Offset.zero);
                    widget.onMove(newX, newY);
                  },
                  child: Container(
                    width: _markerSize,
                    height: _markerSize,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: widget.marker.type == 'cochonnet'
                        ? const Icon(
                            LucideIcons.target,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),

              // Delete button (top-right of marker)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: _deleteButtonSize,
                    height: _deleteButtonSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B), // slate-800
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      LucideIcons.x,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
