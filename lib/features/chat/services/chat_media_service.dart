import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

const int _maxImageBytes = 10 * 1024 * 1024;
const int _maxVideoBytes = 100 * 1024 * 1024;
const int _maxAudioBytes = 25 * 1024 * 1024;

class ChatMediaUploadResult {
  const ChatMediaUploadResult({
    required this.mediaUrl,
    required this.storagePath,
    required this.type,
    required this.fileSize,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.durationMs,
  });

  final String mediaUrl;
  final String storagePath;
  final String type;
  final int fileSize;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int? durationMs;
}

class ChatMediaService {
  ChatMediaService._();
  static final ChatMediaService _instance = ChatMediaService._();
  factory ChatMediaService() => _instance;

  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImageFromGallery() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );
  }

  Future<XFile?> pickVideoFromGallery() async {
    return _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );
  }

  Future<XFile?> captureImageFromCamera() async {
    return _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );
  }

  Future<XFile?> captureVideoFromCamera() async {
    return _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 5),
    );
  }

  Future<ChatMediaUploadResult> uploadImageMessage({
    required String chatId,
    required String senderId,
    required String messageId,
    required XFile file,
    void Function(double progress)? onProgress,
  }) async {
    _validateIds(chatId, senderId, messageId);
    final localFile = File(file.path);
    await _validateFile(localFile, _maxImageBytes, 'image');
    final ext = _extensionFrom(file.path, fallback: 'jpg');
    final storagePath = 'chats/$chatId/$senderId/$messageId/original.$ext';
    final contentType = _imageContentType(ext);
    final mediaUrl = await _upload(
      localFile: localFile,
      storagePath: storagePath,
      contentType: contentType,
      onProgress: onProgress,
    );
    final fileSize = await localFile.length();
    return ChatMediaUploadResult(
      mediaUrl: mediaUrl,
      storagePath: storagePath,
      type: 'image',
      fileSize: fileSize,
    );
  }

  Future<ChatMediaUploadResult> uploadVideoMessage({
    required String chatId,
    required String senderId,
    required String messageId,
    required XFile file,
    void Function(double progress)? onProgress,
  }) async {
    _validateIds(chatId, senderId, messageId);
    final localFile = File(file.path);
    await _validateFile(localFile, _maxVideoBytes, 'video');
    final ext = _extensionFrom(file.path, fallback: 'mp4');
    final storagePath = 'chats/$chatId/$senderId/$messageId/original.$ext';
    final contentType = _videoContentType(ext);
    final mediaUrl = await _upload(
      localFile: localFile,
      storagePath: storagePath,
      contentType: contentType,
      onProgress: onProgress,
    );
    final fileSize = await localFile.length();
    return ChatMediaUploadResult(
      mediaUrl: mediaUrl,
      storagePath: storagePath,
      type: 'video',
      fileSize: fileSize,
    );
  }

  Future<ChatMediaUploadResult> uploadAudioMessage({
    required String chatId,
    required String senderId,
    required String messageId,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    _validateIds(chatId, senderId, messageId);
    await _validateFile(file, _maxAudioBytes, 'audio');
    final ext = _extensionFrom(file.path, fallback: 'aac');
    final storagePath = 'chats/$chatId/$senderId/$messageId/audio.$ext';
    final contentType = _audioContentType(ext);
    final mediaUrl = await _upload(
      localFile: file,
      storagePath: storagePath,
      contentType: contentType,
      onProgress: onProgress,
    );
    final fileSize = await file.length();
    return ChatMediaUploadResult(
      mediaUrl: mediaUrl,
      storagePath: storagePath,
      type: 'audio',
      fileSize: fileSize,
    );
  }

  Future<String> _upload({
    required File localFile,
    required String storagePath,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    final task = ref.putFile(
      localFile,
      SettableMetadata(contentType: contentType),
    );
    if (onProgress != null) {
      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
    }
    await task;
    return await ref.getDownloadURL();
  }

  void _validateIds(String chatId, String senderId, String messageId) {
    if (chatId.isEmpty) throw const ChatMediaException('chatId is empty');
    if (senderId.isEmpty) throw const ChatMediaException('senderId is empty');
    if (messageId.isEmpty) throw const ChatMediaException('messageId is empty');
  }

  Future<void> _validateFile(File file, int maxBytes, String kind) async {
    if (!file.existsSync()) {
      throw ChatMediaException('$kind file does not exist');
    }
    final size = await file.length();
    if (size == 0) {
      throw ChatMediaException('$kind file is empty');
    }
    if (size > maxBytes) {
      final maxMb = maxBytes ~/ (1024 * 1024);
      throw ChatMediaException('$kind exceeds ${maxMb}MB limit');
    }
  }

  String _extensionFrom(String path, {required String fallback}) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return fallback;
    return path.substring(dot + 1).toLowerCase();
  }

  String _imageContentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  String _videoContentType(String ext) {
    switch (ext) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }

  String _audioContentType(String ext) {
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'm4a':
        return 'audio/mp4';
      default:
        return 'audio/aac';
    }
  }
}

class ChatMediaException implements Exception {
  const ChatMediaException(this.message);
  final String message;

  @override
  String toString() => 'ChatMediaException: $message';
}
