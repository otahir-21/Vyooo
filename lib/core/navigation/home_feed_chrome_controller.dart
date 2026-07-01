import 'package:flutter/foundation.dart';

/// Bridges home reel playback progress into [AppBottomNavigation] feed chrome.
class HomeFeedChromeController {
  HomeFeedChromeController();

  /// `null` hides the chrome progress bar; otherwise 0–1 playback position.
  final ValueNotifier<double?> progress = ValueNotifier<double?>(null);

  /// Seek requests from the chrome progress bar scrubber.
  final ValueNotifier<double?> seekFraction = ValueNotifier<double?>(null);

  void dispose() {
    progress.dispose();
    seekFraction.dispose();
  }
}
