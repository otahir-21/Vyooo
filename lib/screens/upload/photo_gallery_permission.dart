import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';

/// [PhotoManager] request shape for the upload / story grids (images + videos).
const PermissionRequestOption kGalleryReadPermissionOption =
    PermissionRequestOption(
  androidPermission: AndroidPermission(
    type: RequestType.common,
    mediaLocation: false,
  ),
);

/// Opens the host OS screen where the user can enable Photos / media access.
Future<void> openGalleryRelatedAppSettings() => openAppSettings();

/// Requests read access for in-app gallery grids.
///
/// Uses [PhotoManager.requestPermissionExtend] first. On Android, some devices
/// mis-handle or skip the dialog when only the plugin path is used; we then
/// invoke [Permission.photos] and re-read state via [PhotoManager.getPermissionState].
Future<PermissionState> requestGalleryReadAccess() async {
  var state = await PhotoManager.requestPermissionExtend(
    requestOption: kGalleryReadPermissionOption,
  );
  if (state.hasAccess) return state;

  if (!kIsWeb && Platform.isAndroid) {
    final photos = await Permission.photos.status;
    if (photos.isGranted || photos.isLimited) {
      state = await PhotoManager.getPermissionState(
        requestOption: kGalleryReadPermissionOption,
      );
      return state;
    }
    if (photos.isPermanentlyDenied) {
      return state;
    }
    final after = await Permission.photos.request();
    if (after.isGranted || after.isLimited) {
      state = await PhotoManager.getPermissionState(
        requestOption: kGalleryReadPermissionOption,
      );
    }
  }
  return state;
}
