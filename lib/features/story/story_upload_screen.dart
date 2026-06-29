import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../../core/platform/app_system_ui.dart';
import '../../core/models/story_model.dart';
import '../../core/services/story_service.dart';
import '../../core/utils/story_video_splitter.dart';
import '../../screens/upload/creator_live_route.dart';
import '../../screens/upload/upload_screen.dart';
import '../../screens/upload/upload_success_screen.dart';
import '../../screens/upload/widgets/photo_manager_story_gallery_panel.dart';
import '../../screens/upload/widgets/upload_create_bottom_bar.dart';
import 'story_draft_storage.dart';

int _colorToArgb32(Color color) {
  final a = (color.a * 255.0).round() & 0xff;
  final r = (color.r * 255.0).round() & 0xff;
  final g = (color.g * 255.0).round() & 0xff;
  final b = (color.b * 255.0).round() & 0xff;
  return (a << 24) | (r << 16) | (g << 8) | b;
}

Rect _storyImageContentRect(Size layout, Size natural) {
  final iw = natural.width;
  final ih = natural.height;
  if (iw <= 0 || ih <= 0) {
    return Rect.fromLTWH(0, 0, layout.width, layout.height);
  }
  final s = math.min(layout.width / iw, layout.height / ih);
  final dw = iw * s;
  final dh = ih * s;
  final ox = (layout.width - dw) / 2;
  final oy = (layout.height - dh) / 2;
  return Rect.fromLTWH(ox, oy, dw, dh);
}

/// Story camera: still capture vs video recording (same pipeline as gallery video).
enum _StoryCameraMode { photo, video }

enum _StoryFilter { normal, warm, cool, mono, vivid }

/// Single ink stroke in normalized image coordinates (0–1).
class _StoryStroke {
  _StoryStroke({
    required this.points,
    required this.color,
    required this.strokeWidthLogical,
    required this.isEraser,
  });

  final List<Offset> points;
  final Color color;
  /// Reference stroke width at ~360 px min(image width, height).
  final double strokeWidthLogical;
  final bool isEraser;

  Map<String, dynamic> toJson() => {
        'points': points.map((o) => [o.dx, o.dy]).toList(),
        'color': _colorToArgb32(color),
        'width': strokeWidthLogical,
        'isEraser': isEraser,
      };

  static _StoryStroke? fromJson(Map<String, dynamic> m) {
    final raw = m['points'];
    if (raw is! List<dynamic>) return null;
    final pts = <Offset>[];
    for (final p in raw) {
      if (p is List && p.length >= 2) {
        pts.add(Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()));
      }
    }
    if (pts.isEmpty) return null;
    return _StoryStroke(
      points: pts,
      color: Color((m['color'] as num?)?.toInt() ?? 0xFFFFFFFF),
      strokeWidthLogical: (m['width'] as num?)?.toDouble() ?? 6,
      isEraser: m['isEraser'] == true,
    );
  }
}

class _StorySticker {
  _StorySticker({
    required this.emoji,
    required this.nx,
    required this.ny,
  });

  String emoji;
  double nx;
  double ny;

  Map<String, dynamic> toJson() => {'emoji': emoji, 'nx': nx, 'ny': ny};

  static _StorySticker fromJson(Map<String, dynamic> m) => _StorySticker(
        emoji: (m['emoji'] as String?) ?? '❤️',
        nx: (m['nx'] as num?)?.toDouble() ?? 0.5,
        ny: (m['ny'] as num?)?.toDouble() ?? 0.5,
      );
}

class _StoryImageEdit {
  const _StoryImageEdit({
    this.filter = _StoryFilter.normal,
    this.overlayText = '',
    this.textNx = 0.5,
    this.textNy = 0.15,
    this.strokes = const [],
    this.stickers = const [],
  });

  final _StoryFilter filter;
  final String overlayText;
  /// Normalized text anchor (0–1) within the image content rect.
  final double textNx;
  final double textNy;
  final List<_StoryStroke> strokes;
  final List<_StorySticker> stickers;

  _StoryImageEdit copyWith({
    _StoryFilter? filter,
    String? overlayText,
    double? textNx,
    double? textNy,
    List<_StoryStroke>? strokes,
    List<_StorySticker>? stickers,
  }) {
    return _StoryImageEdit(
      filter: filter ?? this.filter,
      overlayText: overlayText ?? this.overlayText,
      textNx: textNx ?? this.textNx,
      textNy: textNy ?? this.textNy,
      strokes: strokes ?? this.strokes,
      stickers: stickers ?? this.stickers,
    );
  }

  Map<String, dynamic> toJson() => {
        'filter': filter.name,
        'overlayText': overlayText,
        'textNx': textNx,
        'textNy': textNy,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'stickers': stickers.map((s) => s.toJson()).toList(),
      };

  static _StoryImageEdit fromJson(Map<String, dynamic> m) {
    final filterName = (m['filter'] as String?) ?? 'normal';
    _StoryFilter filter = _StoryFilter.normal;
    for (final f in _StoryFilter.values) {
      if (f.name == filterName) {
        filter = f;
        break;
      }
    }
    final strokeMaps = m['strokes'] as List<dynamic>? ?? const [];
    final strokes = <_StoryStroke>[];
    for (final s in strokeMaps) {
      if (s is Map<String, dynamic>) {
        final st = _StoryStroke.fromJson(s);
        if (st != null) strokes.add(st);
      }
    }
    final stickerMaps = m['stickers'] as List<dynamic>? ?? const [];
    final stickers = <_StorySticker>[];
    for (final s in stickerMaps) {
      if (s is Map<String, dynamic>) stickers.add(_StorySticker.fromJson(s));
    }
    return _StoryImageEdit(
      filter: filter,
      overlayText: (m['overlayText'] as String?) ?? '',
      textNx: (m['textNx'] as num?)?.toDouble() ?? 0.5,
      textNy: (m['textNy'] as num?)?.toDouble() ?? 0.15,
      strokes: strokes,
      stickers: stickers,
    );
  }
}

/// Story upload: camera + **Story | Post | Live** bottom bar (same as + upload hub),
/// multi-image strip, **Photo / Video** modes, library via in-app [PhotoManager] grid.
class StoryUploadScreen extends StatefulWidget {
  const StoryUploadScreen({
    super.key,
    this.successDismissToRoot = false,
  });

  /// When true (upload hub), success clears back to main nav. When false (home "+"),
  /// success pops once with `true` so the feed can refresh.
  final bool successDismissToRoot;

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
  int _videoUploadDone = 0;
  int _videoUploadTotal = 0;

  /// Natural pixel size per image path (for layout + export).
  final Map<String, Size> _imageNaturalSize = {};

  bool _drawMode = false;
  bool _eraserMode = false;
  bool _overlayTextSelected = false;
  Color _drawColor = Colors.white;
  final List<Offset> _currentStrokePoints = [];
  static const double _defaultStrokeWidth = 6;

  bool _draftOffered = false;

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
    unawaited(AppSystemUi.enterImmersiveFullscreen());
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferDraftResume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(AppSystemUi.exitImmersiveFullscreen());
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
        unawaited(_preloadNaturalSizesForPaths([xFile.path]));
      }
      unawaited(HapticFeedback.lightImpact());
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
        unawaited(HapticFeedback.mediumImpact());
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
        unawaited(HapticFeedback.lightImpact());
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
    unawaited(_preloadNaturalSizesForPaths(picked.map((f) => f.path)));
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

  Future<void> _navigateToStorySuccess() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => UploadSuccessScreen(
          title: 'Story Posted!',
          subtitle: 'Your story is live for 24 hours.',
          primaryButtonLabel: 'View Feed',
          dismissToRoot: widget.successDismissToRoot,
        ),
      ),
    );
  }

  Future<void> _post() async {
    if (_uploading) return;

    if (_videoStorySegments.isNotEmpty) {
      setState(() {
        _uploading = true;
        _videoUploadDone = 0;
        _videoUploadTotal = _videoStorySegments.length;
      });
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
          onProgress: (done, total) {
            if (mounted) {
              setState(() {
                _videoUploadDone = done;
                _videoUploadTotal = total;
              });
            }
          },
        );
        await _deleteTempVideoSegments();
        await StoryDraftStorage.clearDraft();
        if (mounted) await _navigateToStorySuccess();
      } catch (e) {
        if (mounted) {
          _showSnack('Upload failed: $e');
          setState(() {
            _uploading = false;
            _videoUploadDone = 0;
            _videoUploadTotal = 0;
          });
        }
      }
    }

    if (_images.isEmpty) return;
    setState(() => _uploading = true);
    try {
      final renderedImages = await _buildUploadImages();
      await StoryService().uploadMultipleStories(
        images: renderedImages,
        caption: _captionCtrl.text.trim(),
      );
      await StoryDraftStorage.clearDraft();
      if (mounted) await _navigateToStorySuccess();
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
      unawaited(_preloadNaturalSizesForPaths([cropped.path]));
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

  void _removeOverlayText() {
    setState(() {
      _imageEdits[_previewIdx] =
          _imageEdits[_previewIdx].copyWith(overlayText: '');
      _overlayTextSelected = false;
    });
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _editOverlayText() async {
    if (_images.isEmpty) return;
    final existing = _imageEdits[_previewIdx].overlayText;
    final controller = TextEditingController(text: existing);
    final hasText = existing.trim().isNotEmpty;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        title: Text(
          hasText ? 'Edit text' : 'Add text',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Type your story text',
            hintStyle: TextStyle(color: Colors.white54),
            counterStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          if (hasText)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text(
                'Remove text',
                style: TextStyle(color: Color(0xFFFF2D55)),
              ),
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
      _imageEdits[_previewIdx] =
          _imageEdits[_previewIdx].copyWith(overlayText: text);
      _overlayTextSelected = text.isNotEmpty;
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

  TextStyle _overlayTextStyle({double fontSize = 30}) {
    return TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      shadows: const [
        Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
      ],
    );
  }

  Widget _buildStaticOverlayText({
    required String text,
    required double nx,
    required double ny,
    double fontSize = 30,
    double maxWidthFraction = 0.92,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * maxWidthFraction;
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: nx * constraints.maxWidth,
              top: ny * constraints.maxHeight,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: _overlayTextStyle(fontSize: fontSize),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditedPreviewImage({
    required File imageFile,
    required _StoryImageEdit edit,
    required BoxFit fit,
    bool includeTextOverlay = true,
    double overlayTextFontSize = 30,
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
    if (!includeTextOverlay || edit.overlayText.trim().isEmpty) return filtered;
    return Stack(
      fit: StackFit.expand,
      children: [
        filtered,
        _buildStaticOverlayText(
          text: edit.overlayText.trim(),
          nx: edit.textNx,
          ny: edit.textNy,
          fontSize: overlayTextFontSize,
        ),
      ],
    );
  }

  Future<List<File>> _buildUploadImages() async {
    final hasAnyEdits = _imageEdits.any(
      (e) =>
          e.filter != _StoryFilter.normal ||
          e.overlayText.trim().isNotEmpty ||
          e.strokes.isNotEmpty ||
          e.stickers.isNotEmpty,
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
      final codec = await ui.instantiateImageCodec(bytes);
      final fi = await codec.getNextFrame();
      final uiImage = fi.image;
      final w = uiImage.width;
      final h = uiImage.height;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final cf = _colorFilterFor(edit.filter);
      canvas.drawImageRect(
        uiImage,
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..colorFilter = cf,
      );

      _paintStoryOverlayTextForExport(
        canvas,
        edit.overlayText.trim(),
        w,
        h,
        textNx: edit.textNx,
        textNy: edit.textNy,
      );

      canvas.saveLayer(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint());
      final scaleRef = math.min(w, h) / 360.0;
      for (final stroke in edit.strokes) {
        final pw = math.max(1.0, stroke.strokeWidthLogical * scaleRef);
        if (stroke.points.isEmpty) continue;
        if (stroke.points.length == 1) {
          final o = stroke.points.first;
          final cx = o.dx * w;
          final cy = o.dy * h;
          final sp = Paint()
            ..strokeWidth = pw
            ..style = PaintingStyle.fill;
          if (stroke.isEraser) {
            sp.blendMode = BlendMode.clear;
          } else {
            sp.color = stroke.color;
          }
          canvas.drawCircle(Offset(cx, cy), pw / 2, sp);
          continue;
        }
        final path = Path()
          ..moveTo(stroke.points.first.dx * w, stroke.points.first.dy * h);
        for (var i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx * w, stroke.points[i].dy * h);
        }
        final sp = Paint()
          ..color = stroke.isEraser ? Colors.white : stroke.color
          ..strokeWidth = pw
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;
        if (stroke.isEraser) {
          sp.blendMode = BlendMode.clear;
        }
        canvas.drawPath(path, sp);
      }
      canvas.restore();

      final stickerFont = 40 * scaleRef;
      for (final st in edit.stickers) {
        final tp = TextPainter(
          text: TextSpan(
            text: st.emoji,
            style: TextStyle(fontSize: stickerFont * 1.35),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final cx = st.nx * w - tp.width / 2;
        final cy = st.ny * h - tp.height / 2;
        tp.paint(canvas, Offset(cx, cy));
      }

      final picture = recorder.endRecording();
      final outUi = await picture.toImage(w, h);
      uiImage.dispose();

      final bd = await outUi.toByteData(format: ui.ImageByteFormat.png);
      outUi.dispose();
      if (bd == null) return null;
      final decoded = img.decodePng(bd.buffer.asUint8List());
      if (decoded == null) return null;
      final encoded = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
      final path =
          '${outputDir.path}/story_edit_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      final out = File(path);
      await out.writeAsBytes(encoded, flush: true);
      return out;
    } catch (e, st) {
      debugPrint('_renderEditedImage: $e $st');
      return null;
    }
  }

  void _paintStoryOverlayTextForExport(
    Canvas canvas,
    String text,
    int imageWidth,
    int imageHeight, {
    double textNx = 0.5,
    double textNy = 0.15,
  }) {
    if (text.isEmpty) return;
    final lines = _splitTextLines(text, maxCharsPerLine: 16, maxLines: 3);
    if (lines.isEmpty) return;
    final scale = math.min(imageWidth, imageHeight) / 360.0;
    final style = TextStyle(
      color: Colors.white,
      fontSize: 28 * scale,
      fontWeight: FontWeight.w800,
      height: 1.15,
      shadows: const [
        Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1.5)),
      ],
    );
    final maxWidth = imageWidth - 28.0;
    final painters = <TextPainter>[];
    var totalHeight = 0.0;
    for (var i = 0; i < lines.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: lines[i], style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: maxWidth);
      painters.add(tp);
      if (i > 0) totalHeight += 6 * scale;
      totalHeight += tp.height;
    }
    final anchorX = textNx * imageWidth;
    final anchorY = textNy * imageHeight;
    var y = anchorY - totalHeight / 2;
    for (final tp in painters) {
      final x = anchorX - tp.width / 2;
      tp.paint(canvas, Offset(x, y));
      y += tp.height + 6 * scale;
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

  Rect _contentRectForImage(Size layout, Size natural) =>
      _storyImageContentRect(layout, natural);

  Offset? _touchToImageNorm(Offset local, Rect content, Size natural) {
    if (!content.contains(local)) return null;
    final ix = (local.dx - content.left) / content.width * natural.width;
    final iy = (local.dy - content.top) / content.height * natural.height;
    return Offset(ix / natural.width, iy / natural.height);
  }

  Future<void> _preloadNaturalSizesForPaths(Iterable<String> paths) async {
    var changed = false;
    for (final path in paths) {
      if (_imageNaturalSize.containsKey(path)) continue;
      try {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final im = frame.image;
        _imageNaturalSize[path] = Size(im.width.toDouble(), im.height.toDouble());
        changed = true;
        im.dispose();
      } catch (_) {}
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _maybeOfferDraftResume() async {
    if (!mounted || _draftOffered) return;
    _draftOffered = true;
    final has = await StoryDraftStorage.hasDraft();
    if (!mounted || !has) return;
    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        title: const Text('Resume draft?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You have an unfinished story draft.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Start fresh'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (restore == false) {
      await StoryDraftStorage.clearDraft();
      return;
    }
    if (restore != true) return;
    final data = await StoryDraftStorage.loadDraft();
    if (!mounted || data == null) return;
    final edits = <_StoryImageEdit>[];
    for (final m in data.editsJson) {
      edits.add(_StoryImageEdit.fromJson(m));
    }
    while (edits.length < data.imageFiles.length) {
      edits.add(const _StoryImageEdit());
    }
    setState(() {
      _images
        ..clear()
        ..addAll(data.imageFiles);
      _imageEdits
        ..clear()
        ..addAll(edits.take(data.imageFiles.length));
      _previewIdx = 0;
      _captionCtrl.text = data.caption;
      _drawMode = false;
      _eraserMode = false;
      _currentStrokePoints.clear();
    });
    unawaited(_preloadNaturalSizesForPaths(data.imageFiles.map((f) => f.path)));
  }

  Future<void> _persistDraftFromCurrent() async {
    if (_images.isEmpty) return;
    try {
      final editsJson =
          _imageEdits.take(_images.length).map((e) => e.toJson()).toList();
      await StoryDraftStorage.saveDraft(
        imageFiles: _images,
        caption: _captionCtrl.text,
        editsJson: editsJson,
      );
      if (mounted) _showSnack('Draft saved');
    } catch (e) {
      debugPrint('_persistDraftFromCurrent: $e');
      if (mounted) _showSnack('Could not save draft.');
    }
  }

  void _endCurrentStroke() {
    if (_currentStrokePoints.isEmpty) return;
    final idx = _previewIdx;
    final stroke = _StoryStroke(
      points: List<Offset>.from(_currentStrokePoints),
      color: _eraserMode ? Colors.white : _drawColor,
      strokeWidthLogical: _defaultStrokeWidth,
      isEraser: _eraserMode,
    );
    _currentStrokePoints.clear();
    setState(() {
      final prev = _imageEdits[idx];
      _imageEdits[idx] = prev.copyWith(strokes: [...prev.strokes, stroke]);
    });
  }

  Future<void> _confirmLeavePreview() async {
    if (_images.isEmpty) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        title: const Text('Leave story?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Save a draft to finish later, or discard.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'cancel') return;
    if (choice == 'save') {
      await _persistDraftFromCurrent();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (choice == 'discard') {
      await StoryDraftStorage.clearDraft();
      if (mounted) {
        setState(() {
          _images.clear();
          _imageEdits.clear();
          _previewIdx = 0;
          _captionCtrl.clear();
          _drawMode = false;
          _eraserMode = false;
          _currentStrokePoints.clear();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _images.isEmpty) _initCamera();
        });
      }
    }
  }

  Future<void> _openStickerPicker() async {
    const emojis = <String>[
      '❤️',
      '😂',
      '😍',
      '🔥',
      '👏',
      '🎉',
      '💯',
      '✨',
      '😮',
      '😭',
      '🙌',
      '💪',
      '⭐',
      '🥳',
      '😎',
      '🤩',
      '💖',
      '👀',
      '✅',
      '🎵',
      '☀️',
      '🌙',
      '📍',
      '🏷️',
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: emojis.length,
            itemBuilder: (_, i) {
              final e = emojis[i];
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, e),
                child: Center(
                  child: Text(e, style: const TextStyle(fontSize: 32)),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    final idx = _previewIdx;
    setState(() {
      final prev = _imageEdits[idx];
      _imageEdits[idx] = prev.copyWith(
        stickers: [...prev.stickers, _StorySticker(emoji: picked, nx: 0.5, ny: 0.45)],
      );
    });
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _onVideoPopInvoked(bool didPop) async {
    if (didPop || !mounted) return;
    if (_uploading) return;
    if (_videoStorySegments.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        title: const Text('Discard video?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your clips will be removed.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    if (!mounted || discard != true) return;
    setState(() {
      _videoStorySegments = [];
      _videoUploadDone = 0;
      _videoUploadTotal = 0;
    });
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

  /// Same **Story | Gallery | Live** row as [UploadScreen] (+ hub).
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
    return PopScope(
      canPop: _videoStorySegments.isEmpty && !_uploading,
      onPopInvokedWithResult: (didPop, _) async {
        await _onVideoPopInvoked(didPop);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          bottom: false,
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
                        _videoUploadDone = 0;
                        _videoUploadTotal = 0;
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
                    if (_uploading && _videoUploadTotal > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _videoUploadDone / _videoUploadTotal,
                            minHeight: 6,
                            backgroundColor: Colors.white24,
                            color: const Color(0xFFDE106B),
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
            _buildUploadCreateBottomBar(),
          ],
        ),
      ),
    ),
    );
  }

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
            bottom: false,
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
                _buildUploadCreateBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Preview (caption + strip + Post) ───────────────────────────────────────

  List<Widget> _textOverlayWidgets(Rect content, int frameIdx) {
    final edit = _imageEdits[frameIdx];
    final text = edit.overlayText.trim();
    if (text.isEmpty) return const [];

    final isSelected =
        frameIdx == _previewIdx && _overlayTextSelected && !_drawMode;

    return [
      Positioned(
        left: content.left,
        top: content.top,
        width: content.width,
        height: content.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (isSelected)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _overlayTextSelected = false),
                ),
              ),
            Positioned(
              left: edit.textNx * content.width,
              top: edit.textNy * content.height,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onTap: !_drawMode
                          ? () {
                              if (isSelected) {
                                _editOverlayText();
                              } else {
                                setState(() => _overlayTextSelected = true);
                                unawaited(HapticFeedback.selectionClick());
                              }
                            }
                          : null,
                      onPanUpdate: !_drawMode
                          ? (details) {
                              setState(() {
                                _overlayTextSelected = true;
                                final current = _imageEdits[frameIdx];
                                final cx = content.left +
                                    current.textNx * content.width +
                                    details.delta.dx;
                                final cy = content.top +
                                    current.textNy * content.height +
                                    details.delta.dy;
                                final nx =
                                    ((cx - content.left) / content.width)
                                        .clamp(0.05, 0.95);
                                final ny =
                                    ((cy - content.top) / content.height)
                                        .clamp(0.05, 0.95);
                                _imageEdits[frameIdx] =
                                    current.copyWith(textNx: nx, textNy: ny);
                              });
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: isSelected
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              )
                            : null,
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: content.width * 0.92),
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: _overlayTextStyle(),
                          ),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: -22,
                        right: -22,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _removeOverlayText();
                          },
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0xFFFF2D55),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _stickerOverlayWidgets(Rect content, int frameIdx) {
    final stickers = _imageEdits[frameIdx].stickers;
    return List<Widget>.generate(stickers.length, (si) {
      final st = stickers[si];
      return Positioned(
        left: content.left + st.nx * content.width - 30,
        top: content.top + st.ny * content.height - 30,
        child: GestureDetector(
          onLongPress: () {
            setState(() {
              final prev = _imageEdits[frameIdx];
              final next = List<_StorySticker>.from(prev.stickers)..removeAt(si);
              _imageEdits[frameIdx] = prev.copyWith(stickers: next);
            });
            unawaited(HapticFeedback.selectionClick());
          },
          onPanUpdate: !_drawMode
              ? (details) {
                  setState(() {
                    final cx =
                        content.left + st.nx * content.width + details.delta.dx;
                    final cy =
                        content.top + st.ny * content.height + details.delta.dy;
                    st.nx =
                        ((cx - content.left) / content.width).clamp(0.05, 0.95);
                    st.ny =
                        ((cy - content.top) / content.height).clamp(0.05, 0.95);
                  });
                }
              : null,
          child: Text(st.emoji, style: const TextStyle(fontSize: 48)),
        ),
      );
    });
  }

  Widget _buildPreview() {
    return PopScope(
      canPop: _images.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmLeavePreview();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final idx = _previewIdx;
                  final path = _images[idx].path;
                  final natural = _imageNaturalSize[path] ?? const Size(1080, 1920);
                  final layoutSize = Size(constraints.maxWidth, constraints.maxHeight);
                  final content = _contentRectForImage(layoutSize, natural);
                  final edit = _imageEdits[idx];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: _buildEditedPreviewImage(
                            imageFile: _images[idx],
                            edit: edit,
                            fit: BoxFit.contain,
                            includeTextOverlay: false,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _StoryInkLayerPainter(
                            strokes: edit.strokes,
                            naturalSize: natural,
                            inProgressPoints:
                                _drawMode && _currentStrokePoints.isNotEmpty
                                    ? _currentStrokePoints
                                    : null,
                            inProgressIsEraser: _eraserMode,
                            inProgressColor: _drawColor,
                          ),
                        ),
                      ),
                      ..._textOverlayWidgets(content, idx),
                      ..._stickerOverlayWidgets(content, idx),
                      if (_drawMode)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (d) {
                              final n = _touchToImageNorm(
                                d.localPosition,
                                content,
                                natural,
                              );
                              if (n == null) return;
                              _currentStrokePoints
                                ..clear()
                                ..add(n);
                              setState(() {});
                            },
                            onPanUpdate: (d) {
                              final n = _touchToImageNorm(
                                d.localPosition,
                                content,
                                natural,
                              );
                              if (n == null) return;
                              _currentStrokePoints.add(n);
                              setState(() {});
                            },
                            onPanEnd: (_) => _endCurrentStroke(),
                            onPanCancel: _currentStrokePoints.clear,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 380,
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
              bottom: false,
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
                        onPressed: () => _confirmLeavePreview(),
                      ),
                    ],
                  ),
                  const Expanded(
                    child: IgnorePointer(
                      child: SizedBox.expand(),
                    ),
                  ),
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
                              onTap: () => setState(() {
                                _previewIdx = i;
                                _currentStrokePoints.clear();
                                _overlayTextSelected = false;
                              }),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _previewIdx == i
                                        ? const Color(0xFFDE106B)
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _buildEditedPreviewImage(
                                  imageFile: _images[i],
                                  edit: _imageEdits[i],
                                  fit: BoxFit.cover,
                                  overlayTextFontSize: 9,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _editActionButton(
                            icon: Icons.crop_rounded,
                            label: 'Crop',
                            onTap: _cropCurrentImage,
                          ),
                          const SizedBox(width: 8),
                          _editActionButton(
                            icon: Icons.filter_rounded,
                            label: _filterLabels[_imageEdits[_previewIdx].filter] ??
                                'Filter',
                            onTap: _pickFilter,
                          ),
                          const SizedBox(width: 8),
                          _editActionButton(
                            icon: Icons.text_fields_rounded,
                            label: _imageEdits[_previewIdx].overlayText
                                    .trim()
                                    .isNotEmpty
                                ? 'Edit text'
                                : 'Text',
                            onTap: _editOverlayText,
                          ),
                          if (_imageEdits[_previewIdx].overlayText
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _editActionButton(
                              icon: Icons.delete_outline_rounded,
                              label: 'Remove text',
                              onTap: _removeOverlayText,
                            ),
                          ],
                          const SizedBox(width: 8),
                          _editActionButton(
                            icon: Icons.brush_rounded,
                            label: _drawMode ? 'Draw ✓' : 'Draw',
                            onTap: () => setState(() {
                              _drawMode = !_drawMode;
                              if (!_drawMode) {
                                _currentStrokePoints.clear();
                              } else {
                                _overlayTextSelected = false;
                              }
                            }),
                          ),
                          const SizedBox(width: 8),
                          _editActionButton(
                            icon: Icons.emoji_emotions_outlined,
                            label: 'Sticker',
                            onTap: _openStickerPicker,
                          ),
                          const SizedBox(width: 8),
                          _editActionButton(
                            icon: Icons.undo_rounded,
                            label: 'Undo',
                            onTap: _imageEdits[_previewIdx].strokes.isEmpty
                                ? () {}
                                : () {
                                    setState(() {
                                      final prev = _imageEdits[_previewIdx];
                                      final next = List<_StoryStroke>.from(prev.strokes)
                                        ..removeLast();
                                      _imageEdits[_previewIdx] =
                                          prev.copyWith(strokes: next);
                                    });
                                    unawaited(HapticFeedback.selectionClick());
                                  },
                          ),
                          const SizedBox(width: 8),
                          _editActionButton(
                            icon: Icons.layers_clear_rounded,
                            label: 'Clear ink',
                            onTap: _imageEdits[_previewIdx].strokes.isEmpty
                                ? () {}
                                : () {
                                    setState(() {
                                      final prev = _imageEdits[_previewIdx];
                                      _imageEdits[_previewIdx] =
                                          prev.copyWith(strokes: []);
                                    });
                                  },
                          ),
                          const SizedBox(width: 8),
                          _editActionButton(
                            icon: Icons.save_outlined,
                            label: 'Draft',
                            onTap: () => _persistDraftFromCurrent(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_drawMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Pen'),
                            selected: !_eraserMode,
                            onSelected: (_) =>
                                setState(() => _eraserMode = false),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Eraser'),
                            selected: _eraserMode,
                            onSelected: (_) => setState(() => _eraserMode = true),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final c in const [
                                    Colors.white,
                                    Color(0xFFFFD60A),
                                    Color(0xFFFF375F),
                                    Color(0xFF34C759),
                                    Color(0xFF0A84FF),
                                    Colors.black,
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          _drawColor = c;
                                          _eraserMode = false;
                                        }),
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: c,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _drawColor == c && !_eraserMode
                                                  ? const Color(0xFFDE106B)
                                                  : Colors.white38,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
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
                        _iconBtn(
                          iconPath: 'assets/vyooO_icons/Upload_Story_Live/gallery.png',
                          onTap: () => _pickFromLibrary(append: true),
                        ),
                        const SizedBox(width: 8),
                        _iconBtn(
                          iconPath: 'assets/vyooO_icons/Home/nav_bar_icons/create.png',
                          onTap: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF171717),
                                title: const Text(
                                  'Start over?',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: const Text(
                                  'Remove all photos from this story.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && mounted) {
                              setState(() {
                                _images.clear();
                                _imageEdits.clear();
                                _previewIdx = 0;
                                _captionCtrl.clear();
                                _drawMode = false;
                                _eraserMode = false;
                                _currentStrokePoints.clear();
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && _images.isEmpty) _initCamera();
                              });
                            }
                          },
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: _post,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(0xFFDE106B),
                                        Color(0xFFF81945),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Post',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                  _buildUploadCreateBottomBar(),
                ],
              ),
            ),
          ],
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

class _StoryInkLayerPainter extends CustomPainter {
  _StoryInkLayerPainter({
    required this.strokes,
    required this.naturalSize,
    this.inProgressPoints,
    this.inProgressIsEraser = false,
    this.inProgressColor = Colors.white,
  });

  final List<_StoryStroke> strokes;
  final Size naturalSize;
  final List<Offset>? inProgressPoints;
  final bool inProgressIsEraser;
  final Color inProgressColor;

  void _paintOne(Canvas canvas, _StoryStroke stroke, double iw, double ih) {
    final scaleRef = math.min(iw, ih) / 360.0;
    final pw = math.max(1.0, stroke.strokeWidthLogical * scaleRef);
    if (stroke.points.isEmpty) return;
    if (stroke.points.length == 1) {
      final o = stroke.points.first;
      final cx = o.dx * iw;
      final cy = o.dy * ih;
      final sp = Paint()
        ..strokeWidth = pw
        ..style = PaintingStyle.fill;
      if (stroke.isEraser) {
        sp.blendMode = BlendMode.clear;
      } else {
        sp.color = stroke.color;
      }
      canvas.drawCircle(Offset(cx, cy), pw / 2, sp);
      return;
    }
    final path = Path()
      ..moveTo(stroke.points.first.dx * iw, stroke.points.first.dy * ih);
    for (var i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx * iw, stroke.points[i].dy * ih);
    }
    final sp = Paint()
      ..color = stroke.isEraser ? Colors.white : stroke.color
      ..strokeWidth = pw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    if (stroke.isEraser) {
      sp.blendMode = BlendMode.clear;
    }
    canvas.drawPath(path, sp);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final content = _storyImageContentRect(size, naturalSize);
    final iw = naturalSize.width;
    final ih = naturalSize.height;
    if (iw <= 0 || ih <= 0) return;
    canvas.save();
    canvas.translate(content.left, content.top);
    canvas.scale(content.width / iw, content.height / ih);
    canvas.saveLayer(Rect.fromLTWH(0, 0, iw, ih), Paint());
    for (final s in strokes) {
      _paintOne(canvas, s, iw, ih);
    }
    if (inProgressPoints != null && inProgressPoints!.isNotEmpty) {
      _paintOne(
        canvas,
        _StoryStroke(
          points: inProgressPoints!,
          color: inProgressColor,
          strokeWidthLogical: 6,
          isEraser: inProgressIsEraser,
        ),
        iw,
        ih,
      );
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StoryInkLayerPainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.inProgressPoints != inProgressPoints ||
      oldDelegate.inProgressIsEraser != inProgressIsEraser ||
      oldDelegate.inProgressColor != inProgressColor ||
      oldDelegate.naturalSize != naturalSize;
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
