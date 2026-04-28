import 'package:flutter/material.dart';

import '../../features/story/story_upload_screen.dart';

/// Legacy compatibility route kept so older navigations continue to work.
/// The actual story camera/upload flow now lives in [StoryUploadScreen].
class StoryCaptureScreen extends StatelessWidget {
  const StoryCaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StoryUploadScreen();
  }
}
