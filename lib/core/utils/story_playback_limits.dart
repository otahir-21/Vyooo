import 'story_video_splitter.dart';

/// Max length of one story “slide” for video or timed image playback (seconds).
int get storyMaxSlideSeconds => StoryVideoSplitter.maxSegmentSeconds;

/// Milliseconds per story slide (video clip or capped image timer).
int get storyMaxSlideMs => storyMaxSlideSeconds * 1000;

/// How many ≤[storyMaxSlideMs] segments cover [totalMs] (minimum 1).
int storySlideCountForDurationMs(int totalMs) {
  if (totalMs <= 0) return 1;
  final cap = storyMaxSlideMs;
  if (totalMs <= cap) return 1;
  return (totalMs + cap - 1) ~/ cap;
}
