import 'package:flutter/material.dart';

/// Severity tier for a reel/post based on how many distinct users have
/// reported it. Counts are aggregated server-side into `reportCount`.
enum ReportSeverity { none, yellow, orange, red }

/// Absolute report-count thresholds that drive the status bar color.
/// Kept in one place so product can tune the bands easily.
class ReportStatusThresholds {
  const ReportStatusThresholds._();

  /// Below this many reports we show nothing (avoids flagging on a single
  /// disgruntled viewer).
  static const int yellowMin = 5;
  static const int orangeMin = 15;
  static const int redMin = 30;

  static ReportSeverity severityFor(int reportCount) {
    if (reportCount >= redMin) return ReportSeverity.red;
    if (reportCount >= orangeMin) return ReportSeverity.orange;
    if (reportCount >= yellowMin) return ReportSeverity.yellow;
    return ReportSeverity.none;
  }
}

/// Compact "community reports" status bar shown on a post.
///
/// Visible to everyone; color escalates yellow -> orange -> red as the raw
/// report count grows. Renders nothing below [ReportStatusThresholds.yellowMin].
class ReportStatusBar extends StatelessWidget {
  const ReportStatusBar({super.key, required this.reportCount});

  /// Builds from a reel map (the `Map<String, dynamic>` used across feeds).
  factory ReportStatusBar.fromReel(Map<String, dynamic> reel, {Key? key}) {
    final raw = reel['reportCount'];
    final count = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}') ?? 0;
    return ReportStatusBar(key: key, reportCount: count);
  }

  final int reportCount;

  @override
  Widget build(BuildContext context) {
    final severity = ReportStatusThresholds.severityFor(reportCount);
    if (severity == ReportSeverity.none) return const SizedBox.shrink();

    final color = _colorFor(severity);
    final label = reportCount == 1 ? '1 report' : '$reportCount reports';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Color _colorFor(ReportSeverity severity) {
    switch (severity) {
      case ReportSeverity.red:
        return const Color(0xFFEF4444);
      case ReportSeverity.orange:
        return const Color(0xFFF97316);
      case ReportSeverity.yellow:
        return const Color(0xFFFACC15);
      case ReportSeverity.none:
        return Colors.transparent;
    }
  }
}
