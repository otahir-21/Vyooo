import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/story_service.dart';
import '../../screens/upload/creator_live_route.dart';

enum _Tab { story, gallery, live }

enum _StoryFilter { normal, warm, cool, mono, vivid }

class _StoryImageEdit {
  const _StoryImageEdit({
    this.filter = _StoryFilter.normal,
    this.overlayText = '',
  });

  final _StoryFilter filter;
  final String overlayText;

  _StoryImageEdit copyWith({
    _StoryFilter? filter,
    String? overlayText,
  }) {
    return _StoryImageEdit(
      filter: filter ?? this.filter,
      overlayText: overlayText ?? this.overlayText,
    );
  }
}

/// Story upload (Figma): camera + Story/Gallery/Live tabs, caption + Post,
/// multi-image strip. Gallery uses the **system photo picker** (`pickMultiImage`)
/// only — no in-app grid (avoids “full gallery / video list” UX).
class StoryUploadScreen extends StatefulWidget {
  const StoryUploadScreen({super.key});

  @override
  State<StoryUploadScreen> createState() => _StoryUploadScreenState();
}

class _StoryUploadScreenState extends State<StoryUploadScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _camCtrl;
  bool _camReady = false;
  bool _isFront = false;
  bool _camPermDenied = false;
  String? _camError;

  _Tab _tab = _Tab.story;

  List<File> _images = [];
  List<_StoryImageEdit> _imageEdits = [];
  int _previewIdx = 0;
  final _captionCtrl = TextEditingController();
  bool _uploading = false;

  final _picker = ImagePicker();

  static const Map<_StoryFilter, String> _filterLabels = <_StoryFilter, String>{
    _StoryFilter.normal: 'Normal',
    _StoryFilter.warm: 'Warm',
    _StoryFilter.cool: 'Cool',
    _StoryFilter.mono: 'Mono',
    _StoryFilter.vivid: 'Vivid',
  };

  static const List<String> _videoExtensions = [
    '.mp4',
    '.mov',
    '.m4v',
    '.webm',
    '.avi',
    '.mkv',
  ];

  bool _isImagePath(String path) {
    final p = path.toLowerCase();
    if (_videoExtensions.any(p.endsWith)) return false;
    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.heic') ||
        p.endsWith('.heif') ||
        p.endsWith('.webp') ||
        p.endsWith('.gif') ||
        p.endsWith('.bmp');
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _camCtrl?.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _disposeCameraSilently();
        break;
      case AppLifecycleState.resumed:
        if (_tab == _Tab.story && _images.isEmpty && !_camPermDenied) {
          _initCamera();
        }
        break;
      default:
        break;
    }
  }

  /// True when [CameraController] exists and is safe to show in [CameraPreview].
  bool _cameraHealthy() {
    final c = _camCtrl;
    if (c == null) return false;
    try {
      return c.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  void _disposeCameraSilently() {
    final c = _camCtrl;
    _camCtrl = null;
    if (c == null) return;
    try {
      c.dispose();
    } catch (_) {}
    if (mounted) {
      setState(() => _camReady = false);
    }
  }

  int _defaultCameraIndex() {
    if (_cameras.isEmpty) return 0;
    if (_isFront) {
      final i = _cameras.indexWhere((d) => d.lensDirection == CameraLensDirection.front);
      if (i >= 0) return i;
    } else {
      final i = _cameras.indexWhere((d) => d.lensDirection == CameraLensDirection.back);
      if (i >= 0) return i;
    }
    return 0;
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _camPermDenied = true);
      return;
    }
    setState(() => _camPermDenied = false);
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() => _camError = 'No cameras found on this device.');
        }
        return;
      }
      await _setupCamera(_defaultCameraIndex());
    } catch (e) {
      if (mounted) setState(() => _camError = e.toString());
    }
  }

  Future<void> _setupCamera(int index) async {
    final prev = _camCtrl;
    _camCtrl = null;
    if (mounted) {
      setState(() {
        _camReady = false;
        _camError = null;
      });
    }
    if (prev != null) {
      try {
        await prev.dispose();
      } catch (_) {}
    }

    final cam = _cameras[index.clamp(0, _cameras.length - 1)];
    final ctrl = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _camCtrl = ctrl;
    try {
      await ctrl.initialize();
      if (mounted) setState(() => _camReady = true);
    } catch (e) {
      if (mounted) setState(() => _camError = 'Camera error: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    _isFront = !_isFront;
    await _setupCamera(_defaultCameraIndex());
  }

  Future<void> _capturePhoto() async {
    if (!_camReady || _camCtrl == null) return;
    try {
      final xFile = await _camCtrl!.takePicture();
      if (mounted) {
        setState(() {
          _images = [File(xFile.path)];
          _imageEdits = [const _StoryImageEdit()];
          _previewIdx = 0;
        });
      }
    } catch (e) {
      if (mounted) _showSnack('Capture failed: $e');
    }
  }

  /// System picker: **images only** (OS gallery in photo mode — not a video grid in-app).
  Future<void> _pickFromLibrary({required bool append}) async {
    final list = await _picker.pickMultiImage(imageQuality: 85);
    if (!mounted || list.isEmpty) return;

    final maxAdd = append ? (10 - _images.length).clamp(0, 10) : 10;
    if (maxAdd <= 0) {
      _showSnack('You can add up to 10 photos.');
      return;
    }

    final files = <File>[];
    for (final x in list) {
      if (files.length >= maxAdd) break;
      if (!_isImagePath(x.path)) continue;
      files.add(File(x.path));
    }

    if (files.isEmpty) {
      if (mounted) {
        _showSnack('Only photos can be used in stories.');
      }
      return;
    }

    if (mounted) {
      setState(() {
        if (append) {
          final prevLen = _images.length;
          _images = [..._images, ...files];
          _imageEdits = [
            ..._imageEdits,
            ...List<_StoryImageEdit>.generate(
              _images.length - prevLen,
              (_) => const _StoryImageEdit(),
            ),
          ];
          _previewIdx = _images.length - 1;
        } else {
          _images = files;
          _imageEdits = List<_StoryImageEdit>.generate(
            files.length,
            (_) => const _StoryImageEdit(),
          );
          _previewIdx = 0;
        }
      });
    }
  }

  Future<void> _post() async {
    if (_images.isEmpty || _uploading) return;
    setState(() => _uploading = true);
    try {
      final renderedImages = await _buildUploadImages();
      await StoryService().uploadMultipleStories(
        images: renderedImages,
        caption: _captionCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _showSnack('Upload failed: $e');
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _cropCurrentImage() async {
    if (_images.isEmpty) return;
    final source = _images[_previewIdx];
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: source.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop',
            rotateButtonsHidden: false,
            aspectRatioLockEnabled: false,
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
          ),
        ],
      );
      if (!mounted || cropped == null) return;
      setState(() {
        _images[_previewIdx] = File(cropped.path);
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Crop failed: $e');
    }
  }

  Future<void> _pickFilter() async {
    if (_images.isEmpty) return;
    final current = _imageEdits[_previewIdx].filter;
    final picked = await showModalBottomSheet<_StoryFilter>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _StoryFilter.values.map((f) {
            final selected = f == current;
            return ListTile(
              title: Text(
                _filterLabels[f] ?? 'Filter',
                style: TextStyle(
                  color: selected ? const Color(0xFFDE106B) : Colors.white,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check_rounded, color: Color(0xFFDE106B))
                  : null,
              onTap: () => Navigator.of(ctx).pop(f),
            );
          }).toList(),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _imageEdits[_previewIdx] = _imageEdits[_previewIdx].copyWith(filter: picked);
    });
  }

  Future<void> _editOverlayText() async {
    if (_images.isEmpty) return;
    final controller = TextEditingController(
      text: _imageEdits[_previewIdx].overlayText,
    );
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        title: const Text('Add Text', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLength: 60,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Type your story text',
            hintStyle: TextStyle(color: Colors.white54),
            counterStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (!mounted || text == null) return;
    setState(() {
      _imageEdits[_previewIdx] = _imageEdits[_previewIdx].copyWith(overlayText: text);
    });
  }

  ColorFilter? _colorFilterFor(_StoryFilter filter) {
    switch (filter) {
      case _StoryFilter.normal:
        return null;
      case _StoryFilter.warm:
        return const ColorFilter.matrix(<double>[
          1.08, 0.0, 0.0, 0.0, 12,
          0.0, 1.00, 0.0, 0.0, 6,
          0.0, 0.0, 0.90, 0.0, -6,
          0.0, 0.0, 0.0, 1.0, 0,
        ]);
      case _StoryFilter.cool:
        return const ColorFilter.matrix(<double>[
          0.90, 0.0, 0.0, 0.0, -6,
          0.0, 1.00, 0.0, 0.0, 2,
          0.0, 0.0, 1.08, 0.0, 12,
          0.0, 0.0, 0.0, 1.0, 0,
        ]);
      case _StoryFilter.mono:
        return const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0.0, 0,
          0.2126, 0.7152, 0.0722, 0.0, 0,
          0.2126, 0.7152, 0.0722, 0.0, 0,
          0.0, 0.0, 0.0, 1.0, 0,
        ]);
      case _StoryFilter.vivid:
        return const ColorFilter.matrix(<double>[
          1.20, 0.0, 0.0, 0.0, 5,
          0.0, 1.15, 0.0, 0.0, 5,
          0.0, 0.0, 1.10, 0.0, 5,
          0.0, 0.0, 0.0, 1.0, 0,
        ]);
    }
  }

  Widget _buildEditedPreviewImage({
    required File imageFile,
    required _StoryImageEdit edit,
    required BoxFit fit,
  }) {
    final base = Image.file(
      imageFile,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
    );
    final filtered = _colorFilterFor(edit.filter) == null
        ? base
        : ColorFiltered(
            colorFilter: _colorFilterFor(edit.filter)!,
            child: base,
          );
    if (edit.overlayText.trim().isEmpty) return filtered;
    return Stack(
      fit: StackFit.expand,
      children: [
        filtered,
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 54, left: 14, right: 14),
            child: Text(
              edit.overlayText.trim(),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<List<File>> _buildUploadImages() async {
    final hasAnyEdits = _imageEdits.any(
      (e) => e.filter != _StoryFilter.normal || e.overlayText.trim().isNotEmpty,
    );
    if (!hasAnyEdits) return _images;

    final tempDir = await getTemporaryDirectory();
    final output = <File>[];
    for (var i = 0; i < _images.length; i++) {
      final rendered = await _renderEditedImage(
        source: _images[i],
        edit: _imageEdits[i],
        outputDir: tempDir,
        index: i,
      );
      output.add(rendered ?? _images[i]);
    }
    return output;
  }

  Future<File?> _renderEditedImage({
    required File source,
    required _StoryImageEdit edit,
    required Directory outputDir,
    required int index,
  }) async {
    try {
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      _applyFilterToImage(decoded, edit.filter);
      _drawOverlayText(decoded, edit.overlayText.trim());
      final encoded = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
      final path =
          '${outputDir.path}/story_edit_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      final out = File(path);
      await out.writeAsBytes(encoded, flush: true);
      return out;
    } catch (_) {
      return null;
    }
  }

  void _applyFilterToImage(img.Image image, _StoryFilter filter) {
    if (filter == _StoryFilter.normal) return;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        var r = p.r;
        var g = p.g;
        var b = p.b;
        switch (filter) {
          case _StoryFilter.normal:
            break;
          case _StoryFilter.warm:
            r = _clampColor(r * 1.12 + 12);
            g = _clampColor(g * 1.03 + 4);
            b = _clampColor(b * 0.90 - 8);
            break;
          case _StoryFilter.cool:
            r = _clampColor(r * 0.92 - 6);
            g = _clampColor(g * 1.00 + 2);
            b = _clampColor(b * 1.10 + 12);
            break;
          case _StoryFilter.mono:
            final luma = _clampColor(0.2126 * r + 0.7152 * g + 0.0722 * b);
            r = luma;
            g = luma;
            b = luma;
            break;
          case _StoryFilter.vivid:
            r = _clampColor((r - 128) * 1.16 + 128 + 5);
            g = _clampColor((g - 128) * 1.16 + 128 + 5);
            b = _clampColor((b - 128) * 1.16 + 128 + 5);
            break;
        }
        image.setPixelRgba(x, y, r.round(), g.round(), b.round(), p.a.round());
      }
    }
  }

  double _clampColor(num value) => value.clamp(0, 255).toDouble();

  void _drawOverlayText(img.Image image, String text) {
    if (text.isEmpty) return;
    final lines = _splitTextLines(text, maxCharsPerLine: 16, maxLines: 3);
    if (lines.isEmpty) return;
    final font = img.arial48;
    final lineHeight = font.lineHeight + 10;
    var y = math.max(20, (image.height * 0.08).round());
    for (final line in lines) {
      final estimatedWidth = (line.length * (font.lineHeight * 0.55)).round();
      final x = math.max(16, ((image.width - estimatedWidth) / 2).round());
      img.drawString(
        image,
        line,
        font: font,
        x: x + 2,
        y: y + 2,
        color: img.ColorRgb8(0, 0, 0),
      );
      img.drawString(
        image,
        line,
        font: font,
        x: x,
        y: y,
        color: img.ColorRgb8(255, 255, 255),
      );
      y += lineHeight;
    }
  }

  List<String> _splitTextLines(
    String text, {
    required int maxCharsPerLine,
    required int maxLines,
  }) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const <String>[];
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      final next = current.isEmpty ? word : '$current $word';
      if (next.length <= maxCharsPerLine) {
        current = next;
        continue;
      }
      if (current.isNotEmpty) lines.add(current);
      current = word;
      if (lines.length >= maxLines - 1) break;
    }
    if (lines.length < maxLines && current.isNotEmpty) {
      lines.add(current);
    }
    if (lines.length > maxLines) {
      return lines.take(maxLines).toList();
    }
    return lines;
  }

  void _onTabChanged(_Tab tab) {
    if (tab == _Tab.live) {
      openCreatorLiveScreen(context);
      return;
    }
    setState(() => _tab = tab);
    if (tab == _Tab.gallery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tab == _Tab.gallery && _images.isEmpty) {
          _pickFromLibrary(append: false);
        }
      });
    } else if (tab == _Tab.story && _images.isEmpty && !_camPermDenied) {
      // Picker / app switch disposes the camera; resume + tab switch must reopen preview.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tab != _Tab.story || _images.isNotEmpty) return;
        if (!_cameraHealthy()) _initCamera();
      });
    }
  }

  void _showSnack(String msg) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomPadding),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isNotEmpty) return _buildPreview();
    if (_tab == _Tab.gallery) return _buildGalleryPickerChrome();
    return _buildCameraView();
  }

  // ── Gallery = story chrome + system picker (no grid) ────────────────────

  Widget _buildGalleryPickerChrome() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Image.asset(
                      'assets/vyooO_icons/Home/chevron_left.png',
                      width: 22,
                      height: 22,
                      color: Colors.white,
                    ),
                    onPressed: () => setState(() => _tab = _Tab.story),
                  ),
                  const Expanded(
                    child: Text(
                      'Photos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/vyooO_icons/Upload_Story_Live/gallery.png',
                      width: 72,
                      height: 72,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Choose photos for your story',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Opens your photo library — still images only, up to 10. No video strip.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDE106B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: () => _pickFromLibrary(append: false),
                        child: const Text(
                          'Open photo library',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 8, 56, 20),
              child: _buildTabBar(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  Widget _buildCameraView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_camPermDenied)
            Container(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_rounded, color: Colors.white38, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera access is required to take photos for your story.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: openAppSettings,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            'Open Settings',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_camError != null)
            Container(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white38, size: 56),
                      const SizedBox(height: 14),
                      const Text(
                        'Could not start camera.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => _pickFromLibrary(append: false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            'Choose from library',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_cameraHealthy())
            CameraPreview(_camCtrl!)
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Image.asset(
                          'assets/vyooO_icons/Home/chevron_left.png',
                          width: 22,
                          height: 22,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SmallCircleBtn(
                        iconPath: 'assets/vyooO_icons/Upload_Story_Live/gallery.png',
                        onTap: () => _pickFromLibrary(append: false),
                      ),
                      GestureDetector(
                        onTap: _capturePhoto,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          padding: const EdgeInsets.all(5),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      _SmallCircleBtn(
                        iconPath: 'assets/vyooO_icons/Upload_Story_Live/camera_switch.png',
                        onTap: _flipCamera,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(56, 0, 56, 20),
                  child: _buildTabBar(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Preview (caption + strip + Post) ───────────────────────────────────────

  Widget _buildPreview() {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: _buildEditedPreviewImage(
                imageFile: _images[_previewIdx],
                edit: _imageEdits[_previewIdx],
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.92), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Image.asset(
                        'assets/vyooO_icons/Home/chevron_left.png',
                        width: 22,
                        height: 22,
                        color: Colors.white,
                      ),
                      onPressed: () => setState(() {
                        _images.clear();
                        _imageEdits.clear();
                        _previewIdx = 0;
                        _captionCtrl.clear();
                      }),
                    ),
                  ],
                ),
                const Spacer(),
                if (_images.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          if (i == _images.length) {
                            return GestureDetector(
                              onTap: () => _pickFromLibrary(append: true),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white.withValues(alpha: 0.12),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Image.asset(
                                  'assets/vyooO_icons/Upload_Story_Live/gallery_camera.png',
                                  width: 28,
                                  height: 28,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }
                          return GestureDetector(
                            onTap: () => setState(() => _previewIdx = i),
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _previewIdx == i ? const Color(0xFFDE106B) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildEditedPreviewImage(
                                imageFile: _images[i],
                                edit: _imageEdits[i],
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _editActionButton(
                        icon: Icons.crop_rounded,
                        label: 'Crop',
                        onTap: _cropCurrentImage,
                      ),
                      const SizedBox(width: 10),
                      _editActionButton(
                        icon: Icons.filter_rounded,
                        label: _filterLabels[_imageEdits[_previewIdx].filter] ?? 'Filter',
                        onTap: _pickFilter,
                      ),
                      const SizedBox(width: 10),
                      _editActionButton(
                        icon: Icons.text_fields_rounded,
                        label: 'Text',
                        onTap: _editOverlayText,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: TextField(
                            controller: _captionCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Add a caption…',
                              hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            minLines: 1,
                            maxLines: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _iconBtn(iconPath: 'assets/vyooO_icons/Upload_Story_Live/gallery.png', onTap: () => _pickFromLibrary(append: true)),
                      const SizedBox(width: 8),
                      _iconBtn(
                        iconPath: 'assets/vyooO_icons/Home/nav_bar_icons/create.png',
                        onTap: () => setState(() {
                          _images.clear();
                          _imageEdits.clear();
                          _previewIdx = 0;
                          _captionCtrl.clear();
                          _tab = _Tab.story;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _uploading
                          ? const SizedBox(
                              width: 56,
                              height: 36,
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap: _post,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Post',
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
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

  Widget _buildTabBar() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _tabItem('Story', _Tab.story),
          _tabItem('Gallery', _Tab.gallery),
          _tabItem('Live', _Tab.live),
        ],
      ),
    );
  }

  Widget _tabItem(String label, _Tab tab) {
    final isSelected = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFDE106B) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({required String iconPath, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black45,
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: Image.asset(
            iconPath,
            width: 20,
            height: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _editActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallCircleBtn extends StatelessWidget {
  const _SmallCircleBtn({required this.iconPath, required this.onTap});
  final String iconPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Center(
          child: Image.asset(
            iconPath,
            width: 24,
            height: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
