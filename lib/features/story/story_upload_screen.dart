import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../../core/models/story_model.dart';
import '../../core/services/story_service.dart';
import '../../core/utils/story_video_splitter.dart';
import '../../screens/upload/creator_live_route.dart';
import '../../screens/upload/upload_screen.dart';
import '../../screens/upload/widgets/photo_manager_story_gallery_panel.dart';
import '../../screens/upload/widgets/upload_create_bottom_bar.dart';

/// Story camera: still capture vs video recording (same pipeline as gallery video).
enum _StoryCameraMode { photo, video }

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

/// Story upload: camera + **Story | Post | Live** bottom bar (same as + upload hub),
/// multi-image strip, **Photo / Video** modes, library via in-app [PhotoManager] grid.
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
  _StoryCameraMode _cameraMode = _StoryCameraMode.photo;
  bool _isRecordingVideo = false;
  Duration _recordElapsed = Duration.zero;
  Timer? _recordTicker;
  Timer? _recordMaxTimer;

  List<File> _images = [];
  List<_StoryImageEdit> _imageEdits = [];
  int _previewIdx = 0;
  /// FFmpeg output segments or a single picked file (≤60s); excludes temp cleanup until posted.
  List<File> _videoStorySegments = [];
  final _captionCtrl = TextEditingController();
  bool _uploading = false;

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
    _recordTicker?.cancel();
    _recordMaxTimer?.cancel();
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
        if (_isRecordingVideo && _camCtrl != null) {
          unawaited(_stopRecordingThenDisposeCamera());
        } else {
          _disposeCameraSilently();
        }
        break;
      case AppLifecycleState.resumed:
        if (_images.isEmpty &&
            _videoStorySegments.isEmpty &&
            !_camPermDenied) {
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

  Future<void> _stopRecordingThenDisposeCamera() async {
    await _stopCameraRecording(save: true);
    if (mounted) _disposeCameraSilently();
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

  Future<void> _setupCamera(int index, {bool? enableAudio}) async {
    final useAudio = enableAudio ?? (_cameraMode == _StoryCameraMode.video);
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
      enableAudio: useAudio,
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
    if (_cameras.length < 2 || _isRecordingVideo) return;
    _isFront = !_isFront;
    await _setupCamera(_defaultCameraIndex());
  }

  Future<void> _setCameraMode(_StoryCameraMode mode) async {
    if (_isRecordingVideo) {
      _showSnack('Stop recording before switching mode.');
      return;
    }
    if (mode == _cameraMode) return;
    setState(() => _cameraMode = mode);
    await _setupCamera(_defaultCameraIndex());
  }

  Future<void> _onShutterTap() async {
    if (!_camReady || _camCtrl == null) return;
    if (_cameraMode == _StoryCameraMode.photo) {
      await _capturePhoto();
    } else {
      await _toggleCameraVideoRecording();
    }
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

  Future<void> _toggleCameraVideoRecording() async {
    final ctrl = _camCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    if (!ctrl.value.isRecordingVideo) {
      final mic = await Permission.microphone.request();
      if (!mounted) return;
      if (!mic.isGranted) {
        _showSnack('Microphone access is needed to record video with sound.');
        return;
      }
      try {
        await ctrl.startVideoRecording();
        if (!mounted) return;
        setState(() {
          _isRecordingVideo = true;
          _recordElapsed = Duration.zero;
        });
        _recordTicker?.cancel();
        _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || !_isRecordingVideo) return;
          setState(() => _recordElapsed += const Duration(seconds: 1));
        });
        _recordMaxTimer?.cancel();
        _recordMaxTimer = Timer(const Duration(minutes: 10), () {
          if (_isRecordingVideo) {
            unawaited(_stopCameraRecording(save: true));
          }
        });
      } catch (e) {
        if (mounted) _showSnack('Could not start recording: $e');
      }
      return;
    }

    await _stopCameraRecording(save: true);
  }

  Future<void> _stopCameraRecording({required bool save}) async {
    final ctrl = _camCtrl;
    if (ctrl == null || !ctrl.value.isRecordingVideo) {
      _recordTicker?.cancel();
      _recordMaxTimer?.cancel();
      if (mounted) setState(() => _isRecordingVideo = false);
      return;
    }
    _recordTicker?.cancel();
    _recordMaxTimer?.cancel();
    try {
      final xFile = await ctrl.stopVideoRecording();
      if (!mounted) return;
      setState(() => _isRecordingVideo = false);
      if (save) {
        await _ingestVideoFile(File(xFile.path));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRecordingVideo = false);
        _showSnack('Recording failed: $e');
      }
    }
  }

  /// Prepares gallery or camera video for posting (split >60s, then preview screen).
  Future<void> _ingestVideoFile(File file) async {
    setState(() {
      _images = [];
      _imageEdits = [];
      _videoStorySegments = [];
      _uploading = true;
    });

    late Duration dur;
    try {
      final vc = VideoPlayerController.file(file);
      await vc.initialize();
      dur = vc.value.duration;
      await vc.dispose();
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        _showSnack('Could not read video: $e');
      }
      return;
    }

    if (!mounted) return;
    if (dur == Duration.zero) {
      setState(() => _uploading = false);
      _showSnack('Video has no playable duration.');
      return;
    }

    try {
      final segments = await StoryVideoSplitter.splitToSegments(file, dur);
      if (!mounted) return;
      setState(() {
        _videoStorySegments = segments;
        _uploading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        _showSnack('$e');
      }
    }
  }

  /// Same in-app library grid as upload Post (+): [PhotoManagerStoryGalleryPanel].
  Future<void> _pickFromLibrary({required bool append}) async {
    final existing = append ? _images.length : 0;
    if (append && existing >= 10) {
      _showSnack('You can add up to 10 photos.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          body: PhotoManagerStoryGalleryPanel(
            existingPhotoCount: existing,
            onBack: () => Navigator.of(ctx).pop(),
            onImagesPicked: (files) async {
              final ok = await _applyPickedStoryImages(files, append: append);
              if (ctx.mounted && ok) Navigator.of(ctx).pop();
            },
            onVideoPicked: (file) async {
              await _ingestVideoFile(file);
              if (ctx.mounted && _videoStorySegments.isNotEmpty) {
                Navigator.of(ctx).pop();
              }
            },
          ),
        ),
      ),
    );
  }

  Future<bool> _applyPickedStoryImages(
    List<File> files, {
    required bool append,
  }) async {
    if (!mounted) return false;
    final maxAdd = append ? (10 - _images.length).clamp(0, 10) : 10;
    if (maxAdd <= 0) {
      _showSnack('You can add up to 10 photos.');
      return false;
    }

    final picked = <File>[];
    for (final f in files) {
      if (picked.length >= maxAdd) break;
      if (!_isImagePath(f.path)) continue;
      picked.add(f);
    }

    if (picked.isEmpty) {
      _showSnack('Only photos can be used in stories.');
      return false;
    }

    setState(() {
      _videoStorySegments = [];
      if (append) {
        final prevLen = _images.length;
        _images = [..._images, ...picked];
        _imageEdits = [
          ..._imageEdits,
          ...List<_StoryImageEdit>.generate(
            _images.length - prevLen,
            (_) => const _StoryImageEdit(),
          ),
        ];
        _previewIdx = _images.length - 1;
      } else {
        _images = picked;
        _imageEdits = List<_StoryImageEdit>.generate(
          picked.length,
          (_) => const _StoryImageEdit(),
        );
        _previewIdx = 0;
      }
    });
    return true;
  }

  Future<int> _videoDurationMs(File f) async {
    final c = VideoPlayerController.file(f);
    try {
      await c.initialize();
      return c.value.duration.inMilliseconds;
    } finally {
      await c.dispose();
    }
  }

  Future<void> _post() async {
    if (_uploading) return;

    if (_videoStorySegments.isNotEmpty) {
      setState(() => _uploading = true);
      try {
        final caption = _captionCtrl.text.trim();
        final groupId = _videoStorySegments.length > 1
            ? DateTime.now().microsecondsSinceEpoch.toString()
            : '';
        final durs = <int>[];
        for (final f in _videoStorySegments) {
          durs.add(await _videoDurationMs(f));
        }
        await StoryService().uploadStoryMediaBatch(
          files: List<File>.from(_videoStorySegments),
          mediaType: StoryMediaType.video,
          caption: caption,
          durationMsPerFile: durs,
          segmentGroupId: groupId,
        );
        await _deleteTempVideoSegments();
        if (mounted) Navigator.of(context).pop(true);
      } catch (e) {
        if (mounted) {
          _showSnack('Upload failed: $e');
          setState(() => _uploading = false);
        }
      }
      return;
    }

    if (_images.isEmpty) return;
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

  Future<void> _deleteTempVideoSegments() async {
    final tmp = (await getTemporaryDirectory()).path;
    for (final f in _videoStorySegments) {
      try {
        if (f.path.startsWith(tmp) && await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
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

  String _formatRecordDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
    if (_videoStorySegments.isNotEmpty) return _buildVideoPostPreview();
    if (_images.isNotEmpty) return _buildPreview();
    return _buildCameraView();
  }

  /// Same **Story | Post | Live** row as [UploadScreen] (+ hub).
  Widget _buildUploadCreateBottomBar() {
    return UploadCreateBottomBar(
      selectedSegment: 0,
      onStoryTap: () {
        if (_images.isNotEmpty || _videoStorySegments.isNotEmpty) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              _images.isNotEmpty ||
              _videoStorySegments.isNotEmpty) {
            return;
          }
          if (!_cameraHealthy()) _initCamera();
        });
      },
      onPostTap: () => UploadScreen.openPostHub(context),
      onLiveTap: () => openCreatorLiveScreen(context),
    );
  }

  Widget _buildVideoPostPreview() {
    final n = _videoStorySegments.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _videoStorySegments = [];
                        _uploading = false;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Video story',
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.video_collection_outlined,
                        color: Colors.white54, size: 64),
                    const SizedBox(height: 20),
                    Text(
                      n == 1
                          ? '1 clip ready to post (max 60s).'
                          : '$n clips ready (split automatically, 60s each).',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _captionCtrl,
                      maxLength: 60,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a caption (optional)',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                        counterStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _uploading
                          ? null
                          : () => setState(() => _videoStorySegments = []),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _uploading ? null : _post,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDE106B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _uploading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Post'),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: _buildUploadCreateBottomBar(),
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
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SegmentedButton<_StoryCameraMode>(
                          segments: const [
                            ButtonSegment(
                              value: _StoryCameraMode.photo,
                              label: Text('Photo'),
                              icon: Icon(Icons.photo_camera_outlined, size: 18),
                            ),
                            ButtonSegment(
                              value: _StoryCameraMode.video,
                              label: Text('Video'),
                              icon: Icon(Icons.videocam_outlined, size: 18),
                            ),
                          ],
                          selected: {_cameraMode},
                          onSelectionChanged: (s) =>
                              _setCameraMode(s.first),
                          style: ButtonStyle(
                            foregroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_cameraMode == _StoryCameraMode.video && _isRecordingVideo)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _formatRecordDuration(_recordElapsed),
                      style: const TextStyle(
                        color: Color(0xFFFF2D55),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SmallCircleBtn(
                        iconPath: 'assets/vyooO_icons/Upload_Story_Live/gallery.png',
                        onTap: _isRecordingVideo
                            ? () {}
                            : () => _pickFromLibrary(append: false),
                      ),
                      GestureDetector(
                        onTap: (_camReady || _isRecordingVideo)
                            ? _onShutterTap
                            : null,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _cameraMode == _StoryCameraMode.video
                                  ? (_isRecordingVideo
                                      ? const Color(0xFFFF2D55)
                                      : Colors.white70)
                                  : Colors.white,
                              width: 4,
                            ),
                          ),
                          padding: const EdgeInsets.all(5),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _cameraMode == _StoryCameraMode.video
                                  ? (_isRecordingVideo
                                      ? const Color(0xFFFF2D55)
                                      : Colors.transparent)
                                  : Colors.white,
                            ),
                            child: _cameraMode == _StoryCameraMode.video &&
                                    _isRecordingVideo
                                ? const Icon(Icons.stop, color: Colors.white, size: 32)
                                : _cameraMode == _StoryCameraMode.video
                                    ? const Icon(Icons.fiber_manual_record,
                                        color: Color(0xFFFF2D55), size: 36)
                                    : null,
                          ),
                        ),
                      ),
                      _SmallCircleBtn(
                        iconPath: 'assets/vyooO_icons/Upload_Story_Live/camera_switch.png',
                        onTap: _isRecordingVideo ? () {} : _flipCamera,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: SafeArea(
                    top: false,
                    child: _buildUploadCreateBottomBar(),
                  ),
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
                SafeArea(
                  top: false,
                  child: _buildUploadCreateBottomBar(),
                ),
              ],
            ),
          ),
        ],
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
