// lib/screens/selfie_with_dino_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../widgets/logo.dart';
import '../theme/design_tokens.dart';

enum FilterType { none, warm, cool, vintage }

class SelfieWithDinoScreen extends StatefulWidget {
  const SelfieWithDinoScreen({super.key});

  @override
  State<SelfieWithDinoScreen> createState() => _SelfieWithDinoScreenState();
}

class _SelfieWithDinoScreenState extends State<SelfieWithDinoScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _captureKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  File? _photo;
  Uint8List? _photoBytes;
  bool _isCapturing = true;
  bool _isProcessing = false;
  String? _captureError;

  // Sticker properties
  Offset _stickerOffset = const Offset(0, 0);
  double _stickerScale = 1.0;
  Offset _dragStart = Offset.zero;
  Offset _stickerOffsetStart = Offset.zero;
  double _scaleStart = 1.0;
  double _baseStickerSize = 200;

  String _selectedPose = 'idle';
  final List<String> _poses = ['idle', 'walk', 'eat'];
  final Map<String, String> _poseAssetMap = {
    'idle': 'assets/dino/idle.png',
    'walk': 'assets/dino/walk.png',
    'eat': 'assets/dino/eat.png',
  };

  FilterType _selectedFilter = FilterType.none;
  Size _compositeSize = Size.zero;
  late AnimationController _poseSwitchController;

  @override
  void initState() {
    super.initState();
    _poseSwitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePhoto());
  }

  @override
  void dispose() {
    _poseSwitchController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    setState(() {
      _isCapturing = true;
      _captureError = null;
    });
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );
      if (shot == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      if (!mounted) return;

      final bytes = await shot.readAsBytes();
      setState(() {
        _photo = File(shot.path);
        _photoBytes = bytes;
        _stickerOffset = const Offset(0, 0);
        _stickerScale = 1.0;
        _selectedPose = 'idle';
        _selectedFilter = FilterType.none;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _captureError = "Check that ChocoDino has camera permission in your device settings, then try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<Uint8List> _captureComposite() async {
    final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // Mobile‑only save – no web code
  Future<void> _saveToGallery() async {
    if (_photo == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final bytes = await _captureComposite();
      final result = await ImageGallerySaverPlus.saveImage(bytes, name: 'dino_selfie');
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to gallery! 🦖📸'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save.'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveAndContinue() async {
    await _saveToGallery();
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      Navigator.pop(context, true);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _dragStart = details.focalPoint;
    _stickerOffsetStart = _stickerOffset;
    _scaleStart = _stickerScale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      final rawOffset = _stickerOffsetStart + (details.focalPoint - _dragStart);
      final maxDx = _compositeSize.width / 2;
      final maxDy = _compositeSize.height / 2;
      _stickerOffset = Offset(
        rawOffset.dx.clamp(-maxDx, maxDx),
        rawOffset.dy.clamp(-maxDy, maxDy),
      );
      _stickerScale = (_scaleStart * details.scale).clamp(0.4, 3.0);
    });
  }

  void _resetSticker() => setState(() {
    _stickerOffset = const Offset(0, 0);
    _stickerScale = 1.0;
  });

  void _switchPose(String pose) {
    setState(() => _selectedPose = pose);
    _poseSwitchController.forward(from: 0);
  }

  Widget _buildFilterButton(FilterType filter, String label) {
    final selected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = filter);
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.black87 : Colors.white, fontSize: 14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _captureError != null
            ? _buildCaptureError()
            : (_photo == null || _photoBytes == null
                ? _buildLoading()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      _baseStickerSize = (constraints.maxWidth * 0.35).clamp(120.0, 350.0);
                      return Column(
                        children: [
                          Expanded(child: _buildComposite()),
                          _buildControls(),
                        ],
                      );
                    },
                  )),
      ),
    );
  }

  Widget _buildCaptureError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xxxl),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.xlAll,
            boxShadow: AppElevation.strong(Colors.black),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📷', style: TextStyle(fontSize: 44)),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                "Couldn't open the camera",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppFontSize.title,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _captureError ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: AppFontSize.body, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFF7A00),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isCapturing) ...[
            const CircularProgressIndicator(color: Color(0xFFFFAB00)),
            const SizedBox(height: 16),
            const Text('Opening camera…', style: TextStyle(color: Colors.white70)),
          ],
        ],
      ),
    );
  }

  Widget _buildComposite() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ---- SHAREABLE CARD ----
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: LayoutBuilder(
                builder: (context, cardConstraints) {
                  _compositeSize = Size(cardConstraints.maxWidth, cardConstraints.maxHeight);
                  return RepaintBoundary(
                    key: _captureKey,
                    child: GestureDetector(
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFC947), Color(0xFFFF7A00)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildFilteredPhoto(),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 140,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                                    ),
                                  ),
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Transform.translate(
                                  key: ValueKey(_selectedPose),
                                  offset: _stickerOffset,
                                  child: Transform.scale(
                                    scale: _stickerScale,
                                    child: SizedBox(
                                      width: _baseStickerSize,
                                      height: _baseStickerSize,
                                      child: Image.asset(
                                        _poseAssetMap[_selectedPose]!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.pets, size: 80, color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 14,
                                right: 14,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.92),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Text('🍫🦖', style: TextStyle(fontSize: 20)),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'I took a selfie with my Dino!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFFAB00),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Choco Dino',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.85),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // ---- ON‑SCREEN CONTROLS ----
        Positioned(
          top: 12,
          left: 12,
          child: Row(
            children: [
              _CircleIconButton(
                icon: Icons.center_focus_strong,
                tooltip: 'Reset dino',
                onPressed: _resetSticker,
              ),
              const SizedBox(width: 8),
              _CircleIconButton(
                icon: Icons.camera_alt,
                tooltip: 'Retake',
                onPressed: _takePhoto,
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                '👆 Drag & pinch to position your dino',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilteredPhoto() {
    if (_photoBytes == null) return const Placeholder(color: Colors.grey);
    Widget photo = Image.memory(_photoBytes!, fit: BoxFit.cover);
    switch (_selectedFilter) {
      case FilterType.none:
        break;
      case FilterType.warm:
        photo = ColorFiltered(
          colorFilter: const ColorFilter.mode(Color(0xFFFFD700), BlendMode.modulate),
          child: photo,
        );
        break;
      case FilterType.cool:
        photo = ColorFiltered(
          colorFilter: const ColorFilter.mode(Color(0xFF87CEEB), BlendMode.hue),
          child: photo,
        );
        break;
      case FilterType.vintage:
        photo = ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.393, 0.769, 0.189, 0, 0,
            0.349, 0.686, 0.168, 0, 0,
            0.272, 0.534, 0.131, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: photo,
        );
        break;
    }
    return photo;
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poses
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _poses.map((pose) {
              final selected = _selectedPose == pose;
              return GestureDetector(
                onTap: () => _switchPose(pose),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.white : Colors.white.withOpacity(0.3),
                    border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2),
                  ),
                  child: Image.asset(
                    _poseAssetMap[pose]!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.pets, size: 28, color: selected ? Colors.black87 : Colors.white70),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          // Filters
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFilterButton(FilterType.none, 'None'),
              const SizedBox(width: 6),
              _buildFilterButton(FilterType.warm, 'Warm'),
              const SizedBox(width: 6),
              _buildFilterButton(FilterType.cool, 'Cool'),
              const SizedBox(width: 6),
              _buildFilterButton(FilterType.vintage, 'Vintage'),
            ],
          ),
          const SizedBox(height: 8),
          // Actions – only Skip & Save (no Share)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _isProcessing ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
                label: const Text('Skip', style: TextStyle(color: Colors.white70)),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _isProcessing ? null : _takePhoto,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    label: const Text('Retake', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download),
                    label: Text(_isProcessing ? 'Processing…' : 'Save & Continue'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _CircleIconButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.5),
      shape: const CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}