import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_padding.dart';
import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';

/// Live stream comment field — Figma: 224×32, rx 8, white 10% + 5px blur,
/// placeholder `Comment..` — DM Sans 400 12/15 @ #EEEEEE.
class LiveCommentInputField extends StatelessWidget {
  const LiveCommentInputField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onSubmitted,
    this.width,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  /// When set, fixes width (Figma 224). Otherwise stretches to parent.
  final double? width;

  static final BorderRadius _radius = BorderRadius.circular(
    AppSizes.liveCommentInputRadius,
  );

  static InputDecoration _decoration() {
    return const InputDecoration(
      hintText: 'Comment..',
      hintStyle: AppTypography.liveCommentInput,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: AppPadding.liveCommentInputContent,
      isDense: true,
    );
  }

  Widget _buildField(BuildContext context) {
    final fieldHeight = AppSizes.liveFeedScaleH(
      context,
      AppSizes.liveCommentInputHeight,
    );
    return ClipRRect(
      borderRadius: _radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.liveCommentInputGlassFill,
            borderRadius: _radius,
          ),
          child: SizedBox(
            height: fieldHeight,
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: AppTypography.liveCommentInput,
              cursorColor: AppColors.liveCommentInputText,
              textInputAction: TextInputAction.send,
              onSubmitted: onSubmitted,
              decoration: _decoration(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = _buildField(context);
    final resolvedWidth = width;
    if (resolvedWidth != null) {
      return SizedBox(width: resolvedWidth, child: field);
    }
    return field;
  }
}
