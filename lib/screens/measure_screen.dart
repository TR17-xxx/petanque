import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/models/game.dart';
import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/services/storage_service.dart';
import 'package:petanque_score/services/secure_storage_service.dart';
import 'package:petanque_score/services/distance_service.dart';
import 'package:petanque_score/services/ai_measure_service.dart';
import 'package:petanque_score/widgets/camera_level_view.dart';
import 'package:petanque_score/widgets/ball_positioner.dart';
import 'package:petanque_score/widgets/ball_editor.dart';
import 'package:petanque_score/widgets/distance_overlay.dart';
import 'package:petanque_score/widgets/distance_results.dart';
import 'package:petanque_score/utils/colors.dart';

enum _Step {
  capture,
  camera,
  placeCochonnet,
  placeBoules,
  visual,
  results,
  aiLoading,
  aiResults,
}

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key, this.gameId});
  final String? gameId;

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  _Step _step = _Step.capture;
  String? _photoUri;
  List<Marker> _markers = [];
  String _activeTeam = 'team1';
  MeasureResult? _result;
  Game? _game;
  bool _hasApiKey = false;
  int _imgWidth = 0;
  int _imgHeight = 0;
  Marker? _editingMarker;

  final ImagePicker _imagePicker = ImagePicker();

  // Non-slate local colors
  static const _amber50 = Color(0xFFFFFBEB);
  static const _amber800 = Color(0xFF92400E);
  static const _blue500 = Color(0xFF3B82F6);
  static const _blue600 = Color(0xFF2563EB);
  static const _red500 = Color(0xFFEF4444);
  static const _red600 = Color(0xFFDC2626);
  static const _purple600 = Color(0xFF7C3AED);
  static const _slate600 = Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final Game? game;
    if (widget.gameId != null) {
      game = await StorageService.loadActiveGame(widget.gameId!);
    } else {
      game = null;
    }
    final apiKey = await SecureStorageService.loadApiKey();
    if (mounted) {
      setState(() {
        _game = game;
        _hasApiKey = apiKey != null && apiKey.isNotEmpty;
      });
    }
  }

  int get _cochonnetCount => _markers.where((m) => m.type == 'cochonnet').length;
  int get _team1Count => _markers.where((m) => m.type == 'team1').length;
  int get _team2Count => _markers.where((m) => m.type == 'team2').length;
  bool get _canCalculate => _cochonnetCount >= 1 && _team1Count >= 1 && _team2Count >= 1;

  void _handleTakePhoto() {
    setState(() => _step = _Step.camera);
  }

  Future<void> _handlePhotoTaken(String photoPath) async {
    final file = File(photoPath);
    final image = await decodeImageFromList(await file.readAsBytes());
    if (mounted) {
      setState(() {
        _photoUri = photoPath;
        _markers = [];
        _imgWidth = image.width;
        _imgHeight = image.height;
        _step = _Step.placeCochonnet;
      });
    }
  }

  Future<void> _handlePickImage() async {
    final XFile? img = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (img != null && mounted) {
      final file = File(img.path);
      final decoded = await decodeImageFromList(await file.readAsBytes());
      setState(() {
        _photoUri = img.path;
        _markers = [];
        _imgWidth = decoded.width;
        _imgHeight = decoded.height;
        _step = _Step.placeCochonnet;
      });
    }
  }

  void _handleCochonnetValidate(Marker cochonnet) {
    setState(() {
      _markers = _markers.where((m) => m.type != 'cochonnet').toList()..add(cochonnet);
      _step = _Step.placeBoules;
    });
  }

  void _handleBouleAdded(Marker boule) {
    setState(() {
      _markers = [..._markers, boule];
    });
  }

  void _handleEditMarker(Marker marker) {
    setState(() => _editingMarker = marker);
  }

  void _handleUpdateMarker(Marker updated) {
    setState(() {
      _markers = _markers.map((m) => m.id == updated.id ? updated : m).toList();
      _editingMarker = null;
    });
  }

  void _handleDeleteMarker() {
    if (_editingMarker == null) return;
    setState(() {
      _markers = _markers.where((m) => m.id != _editingMarker!.id).toList();
      _editingMarker = null;
    });
  }

  void _handleCalculate() {
    final measureResult = DistanceService.calculateDistances(_markers);
    if (measureResult != null) {
      setState(() {
        _result = measureResult;
        _step = _Step.visual;
      });
    }
  }

  Future<void> _handleAIAnalysis() async {
    if (_photoUri == null) {
      _showError('Photo requise', 'Prenez ou choisissez une photo d\'abord.');
      return;
    }
    setState(() => _step = _Step.aiLoading);
    try {
      final aiResult = await AiMeasureService.analyzeWithAI(
        _photoUri!,
        _game?.team1.name ?? 'Équipe 1',
        _game?.team2.name ?? 'Équipe 2',
      );
      if (mounted) {
        setState(() {
          _result = aiResult;
          _step = _Step.aiResults;
        });
      }
    } catch (error) {
      if (mounted) {
        _showError('Erreur', error.toString().replaceFirst('Exception: ', ''));
        setState(() => _step = _Step.placeBoules);
      }
    }
  }

  Future<void> _handleApply() async {
    if (_result == null) return;
    await StorageService.saveMeasureResult(_result!);
    if (mounted) context.pop();
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: slate800)),
        content: Text(message, style: const TextStyle(fontSize: 14, color: slate500)),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.capture:
        return _buildCaptureStep();
      case _Step.camera:
        return _buildCameraStep();
      case _Step.placeCochonnet:
        return _buildPlaceCochonnetStep();
      case _Step.placeBoules:
        return _buildPlaceBoulesStep();
      case _Step.visual:
        return _buildVisualStep();
      case _Step.results:
      case _Step.aiResults:
        return _buildResultsStep();
      case _Step.aiLoading:
        return _buildAiLoadingStep();
    }
  }

  // ════════════════════════════════════════════════
  // CAPTURE STEP
  // ════════════════════════════════════════════════
  Widget _buildCaptureStep() {
    final theme = context.watch<ThemeProvider>();
    final themeColor = theme.colors.shade600;

    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(LucideIcons.arrowLeft, size: 24, color: slate800),
                  ),
                  const SizedBox(width: 12),
                  const Text('Mesure de distance',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: slate800)),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Advice
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _amber50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Pour une mesure précise, prenez la photo bien à la verticale, au-dessus des boules',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: _amber800, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Camera button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _handleTakePhoto,
                          icon: const Icon(LucideIcons.camera, size: 24),
                          label: const Text('Prendre une photo',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Gallery button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _handlePickImage,
                          icon: const Icon(LucideIcons.image, size: 24, color: slate500),
                          label: const Text('Choisir depuis la galerie',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _slate600)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: slate200),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      if (_hasApiKey) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Ou analysez directement avec l\'IA après avoir choisi une photo',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: slate400),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // CAMERA STEP (with level indicator overlay)
  // ════════════════════════════════════════════════
  Widget _buildCameraStep() {
    return CameraLevelView(
      onPhotoTaken: _handlePhotoTaken,
      onBack: () => setState(() => _step = _Step.capture),
    );
  }

  // ════════════════════════════════════════════════
  // PLACE COCHONNET STEP
  // ════════════════════════════════════════════════
  Widget _buildPlaceCochonnetStep() {
    return Scaffold(
      backgroundColor: slate900,
      body: SafeArea(
        child: BallPositioner(
          photoUri: _photoUri!,
          markerType: 'cochonnet',
          instructionText: 'Positionnez le cercle sur le cochonnet',
          onValidate: _handleCochonnetValidate,
          onBack: () => setState(() => _step = _Step.capture),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // PLACE BOULES STEP
  // ════════════════════════════════════════════════
  Widget _buildPlaceBoulesStep() {
    final theme = context.watch<ThemeProvider>();
    final themeColor = theme.colors.shade600;

    return Scaffold(
      backgroundColor: slate900,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _step = _Step.placeCochonnet),
                            child: const Icon(LucideIcons.arrowLeft, size: 24, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: slate700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.x, size: 16, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Quitter', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _markerCounter(const Color(0xFF84CC16), _cochonnetCount),
                          const SizedBox(width: 12),
                          _markerCounter(_blue500, _team1Count),
                          const SizedBox(width: 12),
                          _markerCounter(_red500, _team2Count),
                        ],
                      ),
                    ],
                  ),
                ),
                // Photo with markers
                Expanded(
                  child: _BoulesPhotoView(
                    photoUri: _photoUri!,
                    markers: _markers,
                    activeTeam: _activeTeam,
                    onAddBoule: _handleBouleAdded,
                    onEditMarker: _handleEditMarker,
                    onMoveMarker: _handleUpdateMarker,
                  ),
                ),
                // Bottom bar
                Container(
                  color: slate800,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      // Team selector
                      Row(
                        children: [
                          Expanded(child: _typeButton(
                            label: _game?.team1.name ?? 'Éq. 1',
                            icon: LucideIcons.circleDot, type: 'team1', activeColor: _blue600)),
                          const SizedBox(width: 8),
                          Expanded(child: _typeButton(
                            label: _game?.team2.name ?? 'Éq. 2',
                            icon: LucideIcons.circleDot, type: 'team2', activeColor: _red600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (_hasApiKey) ...[
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _handleAIAnalysis,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _purple600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: const Text('Analyse IA',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _canCalculate ? _handleCalculate : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _canCalculate ? themeColor : _slate600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                  disabledBackgroundColor: _slate600.withValues(alpha: 0.5),
                                  disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                                ),
                                child: const Text('Calculer les distances',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // BallEditor modal overlay
            if (_editingMarker != null)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: BallEditor(
                  photoUri: _photoUri!,
                  marker: _editingMarker!,
                  imageWidth: _imgWidth,
                  imageHeight: _imgHeight,
                  onUpdate: _handleUpdateMarker,
                  onDelete: _handleDeleteMarker,
                  onCancel: () => setState(() => _editingMarker = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _markerCounter(Color color, int count) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _typeButton({required String label, required IconData icon, required String type, required Color activeColor}) {
    final isActive = _activeTeam == type;
    return GestureDetector(
      onTap: () => setState(() => _activeTeam = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor : slate700,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : slate400),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive ? Colors.white : slate400)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // VISUAL STEP
  // ════════════════════════════════════════════════
  Widget _buildVisualStep() {
    return Scaffold(
      backgroundColor: slate900,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _step = _Step.placeBoules),
                    child: const Icon(LucideIcons.arrowLeft, size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text('Résultat visuel',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: DistanceOverlay(
                photoUri: _photoUri!,
                markers: _markers,
                distances: _result!.distances!,
                closestTeamId: _result!.closestTeamId,
                pointsScored: _result!.pointsScored,
                team1Name: _game?.team1.name ?? 'Équipe 1',
                team2Name: _game?.team2.name ?? 'Équipe 2',
                onDetails: () => setState(() => _step = _Step.results),
                onApply: _handleApply,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // RESULTS STEP
  // ════════════════════════════════════════════════
  Widget _buildResultsStep() {
    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_step == _Step.aiResults) {
                          _result = null;
                          _step = _Step.capture;
                        } else {
                          _step = _Step.visual;
                        }
                      });
                    },
                    child: const Icon(LucideIcons.arrowLeft, size: 24, color: slate800),
                  ),
                  const SizedBox(width: 12),
                  const Text('Résultats',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: slate800)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: DistanceResults(
                  result: _result!,
                  team1Name: _game?.team1.name ?? 'Équipe 1',
                  team2Name: _game?.team2.name ?? 'Équipe 2',
                  onApply: _handleApply,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // AI LOADING STEP
  // ════════════════════════════════════════════════
  Widget _buildAiLoadingStep() {
    final theme = context.watch<ThemeProvider>();
    final themeColor = theme.colors.shade600;
    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: themeColor, strokeWidth: 3),
              const SizedBox(height: 16),
              const Text('Analyse en cours...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _slate600)),
              const SizedBox(height: 4),
              const Text('L\'IA examine la photo',
                  style: TextStyle(fontSize: 14, color: slate400)),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Internal widget: Boules photo view with tap to add/edit
// ════════════════════════════════════════════════

const Map<String, Color> _markerColorsMap = {
  'cochonnet': Color(0xFF84CC16),
  'team1': Color(0xFF2563EB),
  'team2': Color(0xFFDC2626),
};

class _BoulesPhotoView extends StatefulWidget {
  final String photoUri;
  final List<Marker> markers;
  final String activeTeam;
  final ValueChanged<Marker> onAddBoule;
  final ValueChanged<Marker> onEditMarker;
  final ValueChanged<Marker> onMoveMarker;

  const _BoulesPhotoView({
    required this.photoUri,
    required this.markers,
    required this.activeTeam,
    required this.onAddBoule,
    required this.onEditMarker,
    required this.onMoveMarker,
  });

  @override
  State<_BoulesPhotoView> createState() => _BoulesPhotoViewState();
}

class _BoulesPhotoViewState extends State<_BoulesPhotoView> {
  final TransformationController _tc = TransformationController();
  Size _imageSize = Size.zero;
  Size _containerSize = Size.zero;
  bool _imageLoaded = false;

  // Drag state
  String? _draggingMarkerId;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(_BoulesPhotoView old) {
    super.didUpdateWidget(old);
    if (old.photoUri != widget.photoUri) _loadImageSize();
  }

  void _loadImageSize() {
    final image = FileImage(File(widget.photoUri));
    image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) {
        if (mounted) {
          setState(() {
            _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble());
            _imageLoaded = true;
          });
        }
      }),
    );
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Size _getDisplayedImageSize() {
    if (_imageSize == Size.zero || _containerSize == Size.zero) return _containerSize;
    final ia = _imageSize.width / _imageSize.height;
    final ca = _containerSize.width / _containerSize.height;
    if (ia > ca) {
      final w = _containerSize.width;
      return Size(w, w / ia);
    } else {
      final h = _containerSize.height;
      return Size(h * ia, h);
    }
  }

  Offset? _tapToRelative(Offset local) {
    if (_containerSize == Size.zero) return null;
    final inv = Matrix4.inverted(_tc.value);
    final pt = MatrixUtils.transformPoint(inv, local);
    final ds = _getDisplayedImageSize();
    final ox = (_containerSize.width - ds.width) / 2;
    final oy = (_containerSize.height - ds.height) / 2;
    final rx = (pt.dx - ox) / ds.width;
    final ry = (pt.dy - oy) / ds.height;
    if (rx >= 0 && rx <= 1 && ry >= 0 && ry <= 1) return Offset(rx, ry);
    return null;
  }

  Marker? _findNearMarker(Offset rel) {
    const thresh = 0.04;
    Marker? closest;
    double minD = double.infinity;
    for (final m in widget.markers) {
      final d = (m.x - rel.dx) * (m.x - rel.dx) + (m.y - rel.dy) * (m.y - rel.dy);
      if (d < minD) { minD = d; closest = m; }
    }
    return (closest != null && minD < thresh * thresh) ? closest : null;
  }

  void _onTapUp(TapUpDetails details) {
    final rel = _tapToRelative(details.localPosition);
    if (rel == null) return;

    final near = _findNearMarker(rel);
    if (near != null) {
      widget.onEditMarker(near);
      return;
    }

    // Create marker, add it, and open BallEditor immediately
    final newMarker = Marker(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      x: rel.dx,
      y: rel.dy,
      type: widget.activeTeam,
      circleRadius: 0.03,
    );
    widget.onAddBoule(newMarker);
    widget.onEditMarker(newMarker);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final rel = _tapToRelative(details.localPosition);
    if (rel == null) return;
    final near = _findNearMarker(rel);
    if (near != null) {
      setState(() {
        _draggingMarkerId = near.id;
      });
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_draggingMarkerId == null) return;
    final rel = _tapToRelative(details.localPosition);
    if (rel == null) return;
    final marker = widget.markers.firstWhere((m) => m.id == _draggingMarkerId);
    widget.onMoveMarker(marker.copyWith(
      x: rel.dx.clamp(0.0, 1.0),
      y: rel.dy.clamp(0.0, 1.0),
    ));
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() => _draggingMarkerId = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        final ds = _getDisplayedImageSize();
        final ox = (_containerSize.width - ds.width) / 2;
        final oy = (_containerSize.height - ds.height) / 2;

        return Stack(
          children: [
            // Photo + markers — always takes the full space
            GestureDetector(
              onTapUp: _onTapUp,
              onLongPressStart: _onLongPressStart,
              onLongPressMoveUpdate: _onLongPressMoveUpdate,
              onLongPressEnd: _onLongPressEnd,
              child: InteractiveViewer(
                transformationController: _tc,
                minScale: 1.0,
                maxScale: 8.0,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: SizedBox(
                  width: _containerSize.width,
                  height: _containerSize.height,
                  child: _imageLoaded
                      ? CustomPaint(
                          foregroundPainter: _BoulesOverlayPainter(
                            markers: widget.markers,
                            displayedSize: ds,
                            imgOffset: Offset(ox, oy),
                          ),
                          child: Center(
                            child: Image.file(File(widget.photoUri),
                                width: ds.width, height: ds.height, fit: BoxFit.contain),
                          ),
                        )
                      : const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BoulesOverlayPainter extends CustomPainter {
  final List<Marker> markers;
  final Size displayedSize;
  final Offset imgOffset;

  _BoulesOverlayPainter({
    required this.markers,
    required this.displayedSize,
    required this.imgOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in markers) {
      _drawMarker(canvas, m, m.circleRadius);
    }
  }

  void _drawMarker(Canvas canvas, Marker m, double radius) {
    final mx = imgOffset.dx + m.x * displayedSize.width;
    final my = imgOffset.dy + m.y * displayedSize.height;
    final pr = radius * displayedSize.width;
    final color = _markerColorsMap[m.type] ?? Colors.grey;

    canvas.drawCircle(Offset(mx, my), pr,
        Paint()..color = color.withValues(alpha: 0.1)..style = PaintingStyle.fill);
    _drawDashedCircle(canvas, Offset(mx, my), pr, color, 1.5);
    canvas.drawCircle(Offset(mx, my), 3, Paint()..color = color..style = PaintingStyle.fill);
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Color color, double sw) {
    final paint = Paint()..color = color..strokeWidth = sw..style = PaintingStyle.stroke;
    const dl = 8.0, gl = 5.0;
    final circ = 2 * math.pi * radius;
    final n = (circ / (dl + gl)).floor();
    if (n <= 0) return;
    for (var i = 0; i < n; i++) {
      final sa = (i * (dl + gl) / circ) * 2 * math.pi;
      final sw2 = (dl / circ) * 2 * math.pi;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), sa, sw2, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoulesOverlayPainter old) => true;
}
