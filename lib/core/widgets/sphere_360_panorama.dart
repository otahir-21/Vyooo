import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dchs_motion_sensors/dchs_motion_sensors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:video_player/video_player.dart';

/// Equirectangular 360° sphere using [VideoPlayerController] frames (no WebRTC).
class Sphere360Panorama extends StatefulWidget {
  const Sphere360Panorama({
    super.key,
    required this.controller,
    this.croppedArea = const Rect.fromLTWH(0, 0, 1, 1),
    this.enableGyro = true,
    this.enableTouch = true,
    this.minZoom = 1,
    this.maxZoom = 4,
  });

  final VideoPlayerController controller;
  final Rect croppedArea;
  final bool enableGyro;
  final bool enableTouch;
  final double minZoom;
  final double maxZoom;

  @override
  State<Sphere360Panorama> createState() => _Sphere360PanoramaState();
}

class _Sphere360PanoramaState extends State<Sphere360Panorama>
    with SingleTickerProviderStateMixin {
  static const double _radius = 500;

  Scene? _scene;
  Object? _surface;
  late double _latitude;
  late double _longitude;
  double _latitudeDelta = 0;
  double _longitudeDelta = 0;
  double _zoomDelta = 0;
  late Offset _lastFocalPoint;
  double? _lastZoom;
  late AnimationController _animController;
  double _screenOrientation = 0;
  Vector3 _orientation = Vector3(0, radians(90), 0);
  StreamSubscription<OrientationEvent>? _orientationSubscription;
  StreamSubscription<ScreenOrientationEvent>? _screenOrientSubscription;
  final GlobalKey _videoKey = GlobalKey();
  Timer? _frameTimer;
  ui.Image? _currentFrame;

  @override
  void initState() {
    super.initState();
    _latitude = 0;
    _longitude = 0;
    _animController = AnimationController(
      duration: const Duration(milliseconds: 60000),
      vsync: this,
    )..addListener(_updateView);
    _updateSensorControl();
    _startFrameExtraction();
  }

  @override
  void didUpdateWidget(covariant Sphere360Panorama oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableGyro != widget.enableGyro) {
      _updateSensorControl();
    }
    if (oldWidget.croppedArea != widget.croppedArea && _surface != null) {
      _surface!.mesh = _generateSphereMesh(
        radius: _radius,
        croppedArea: widget.croppedArea,
      );
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _orientationSubscription?.cancel();
    _screenOrientSubscription?.cancel();
    _animController.dispose();
    _currentFrame?.dispose();
    super.dispose();
  }

  void _updateSensorControl() {
    _orientationSubscription?.cancel();
    _screenOrientSubscription?.cancel();
    if (widget.enableGyro) {
      motionSensors.orientationUpdateInterval =
          Duration.microsecondsPerSecond ~/ 60;
      _orientationSubscription =
          motionSensors.orientation.listen((OrientationEvent event) {
        _orientation.setValues(event.yaw, event.pitch, event.roll);
      });
      _screenOrientSubscription =
          motionSensors.screenOrientation.listen((ScreenOrientationEvent event) {
        _screenOrientation = radians(event.angle ?? 0);
      });
      if (!_animController.isAnimating) _animController.repeat();
    } else {
      _orientation = Vector3(0, radians(90), 0);
      _screenOrientation = 0;
    }
  }

  void _startFrameExtraction() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _extractFrame(),
    );
  }

  Future<void> _extractFrame() async {
    final context = _videoKey.currentContext;
    if (context == null) return;
    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    try {
      final image = await boundary.toImage(pixelRatio: 1);
      if (!mounted || image.width <= 0 || image.height <= 0) {
        image.dispose();
        return;
      }
      _currentFrame?.dispose();
      _currentFrame = image;
      if (_surface != null && _scene != null) {
        _surface!.mesh.texture = image;
        _scene!.texture = image;
        _scene!.update();
      }
    } catch (_) {}
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _lastZoom = null;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.enableTouch) return;
    final offset = details.localFocalPoint - _lastFocalPoint;
    _lastFocalPoint = details.localFocalPoint;
    _latitudeDelta +=
        0.5 * math.pi * offset.dy / (_scene?.camera.viewportHeight ?? 1);
    _longitudeDelta -=
        0.5 * math.pi * offset.dx / (_scene?.camera.viewportHeight ?? 1);
    _lastZoom ??= _scene?.camera.zoom;
    _zoomDelta += _lastZoom! * details.scale -
        ((_scene?.camera.zoom ?? 1) + _zoomDelta);
    if (!widget.enableGyro) {
      _animController
        ..reset()
        ..forward();
    }
  }

  void _updateView() {
    if (_scene == null) return;
    _latitude += _latitudeDelta * 0.05;
    _latitudeDelta *= 0.95;
    _longitude += _longitudeDelta * 0.05;
    _longitudeDelta *= 0.95;
    final zoom = (_scene!.camera.zoom + _zoomDelta * 0.05)
        .clamp(widget.minZoom, widget.maxZoom);
    _zoomDelta *= 0.95;
    _scene!.camera.zoom = zoom;

    var q = Quaternion.axisAngle(Vector3(0, 0, 1), _screenOrientation);
    q *= Quaternion.euler(-_orientation.z, -_orientation.y, -_orientation.x);
    q *= Quaternion.axisAngle(Vector3(1, 0, 0), math.pi * 0.5);

    var o = _quaternionToOrientation(q);
    final minLat = radians(-85);
    final maxLat = radians(85);
    final lat = (-o.y).clamp(minLat, maxLat);
    final lon = o.x.clamp(radians(-180), radians(180));
    if (lat + _latitude < minLat) _latitude = minLat - lat;
    if (lat + _latitude > maxLat) _latitude = maxLat - lat;
    o.x = lon;
    o.y = -lat;
    q = _orientationToQuaternion(o);
    q *= Quaternion.axisAngle(Vector3(0, 1, 0), -math.pi * 0.5);
    q *= Quaternion.axisAngle(Vector3(0, 1, 0), _longitude);
    q = Quaternion.axisAngle(Vector3(1, 0, 0), -_latitude) * q;

    q.rotate(_scene!.camera.target..setFrom(Vector3(0, 0, -_radius)));
    q.rotate(_scene!.camera.up..setFrom(Vector3(0, 1, 0)));
    _scene!.update();
  }

  void _onSceneCreated(Scene scene) {
    _scene = scene;
    scene.camera
      ..near = 1
      ..far = _radius + 1
      ..fov = 75
      ..zoom = widget.minZoom
      ..position.setFrom(Vector3(0, 0, 0.1));
    final mesh = _generateSphereMesh(
      radius: _radius,
      croppedArea: widget.croppedArea,
    );
    _surface = Object(
      name: 'surface',
      mesh: mesh,
      backfaceCulling: false,
    );
    scene.world.add(_surface!);
    if (_currentFrame != null) {
      _surface!.mesh.texture = _currentFrame;
      scene.texture = _currentFrame;
      scene.update();
    }
    if (widget.enableGyro) {
      _animController.repeat();
    }
  }

  Widget _hiddenVideoCapture() {
    final size = widget.controller.value.isInitialized
        ? widget.controller.value.size
        : const Size(1920, 1080);
    return Positioned(
      left: -10000,
      top: -10000,
      child: RepaintBoundary(
        key: _videoKey,
        child: SizedBox(
          width: size.width > 0 ? size.width : 1920,
          height: size.height > 0 ? size.height : 1080,
          child: VideoPlayer(widget.controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cube = Cube(interactive: false, onSceneCreated: _onSceneCreated);
    return Stack(
      fit: StackFit.expand,
      children: [
        _hiddenVideoCapture(),
        widget.enableTouch
            ? GestureDetector(
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                child: cube,
              )
            : cube,
      ],
    );
  }
}

Mesh _generateSphereMesh({
  num radius = 1,
  int latSegments = 32,
  int lonSegments = 64,
  ui.Image? texture,
  Rect croppedArea = const Rect.fromLTWH(0, 0, 1, 1),
  double croppedFullWidth = 1,
  double croppedFullHeight = 1,
}) {
  final count = (latSegments + 1) * (lonSegments + 1);
  final vertices = List<Vector3>.filled(count, Vector3.zero());
  final texcoords = List<Offset>.filled(count, Offset.zero);
  final indices = List<Polygon>.filled(latSegments * lonSegments * 2, Polygon(0, 0, 0));

  var i = 0;
  for (var y = 0; y <= latSegments; y++) {
    final tv = y / latSegments;
    final v = (croppedArea.top + croppedArea.height * tv) / croppedFullHeight;
    final sv = math.sin(v * math.pi);
    final cv = math.cos(v * math.pi);
    for (var x = 0; x <= lonSegments; x++) {
      final tu = x / lonSegments;
      final u = (croppedArea.left + croppedArea.width * tu) / croppedFullWidth;
      vertices[i] = Vector3(
        radius * math.cos(u * math.pi * 2) * sv,
        radius * cv,
        radius * math.sin(u * math.pi * 2) * sv,
      );
      texcoords[i] = Offset(tu, 1 - tv);
      i++;
    }
  }

  i = 0;
  for (var y = 0; y < latSegments; y++) {
    final base1 = (lonSegments + 1) * y;
    final base2 = (lonSegments + 1) * (y + 1);
    for (var x = 0; x < lonSegments; x++) {
      indices[i++] = Polygon(base1 + x, base1 + x + 1, base2 + x);
      indices[i++] = Polygon(base1 + x + 1, base2 + x + 1, base2 + x);
    }
  }

  return Mesh(
    vertices: vertices,
    texcoords: texcoords,
    indices: indices,
    texture: texture,
  );
}

Vector3 _quaternionToOrientation(Quaternion q) {
  final storage = q.storage;
  final x = storage[0];
  final y = storage[1];
  final z = storage[2];
  final w = storage[3];
  final roll = math.atan2(-2 * (x * y - w * z), 1 - 2 * (x * x + z * z));
  final pitch = math.asin(2 * (y * z + w * x));
  final yaw = math.atan2(-2 * (x * z - w * y), 1 - 2 * (x * x + y * y));
  return Vector3(yaw, pitch, roll);
}

Quaternion _orientationToQuaternion(Vector3 v) {
  final m = Matrix4.identity();
  m.rotateZ(v.z);
  m.rotateX(v.y);
  m.rotateY(v.x);
  return Quaternion.fromRotation(m.getRotation());
}
