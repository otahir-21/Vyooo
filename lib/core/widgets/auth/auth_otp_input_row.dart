import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Row of single-digit OTP boxes (Figma verify-code style).
class AuthOtpInputRow extends StatelessWidget {
  const AuthOtpInputRow({
    super.key,
    required this.length,
    required this.controllers,
    required this.focusNodes,
    this.onChanged,
  });

  final int length;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(length, _buildOtpBox),
    );
  }

  Widget _buildOtpBox(int index) {
    return ListenableBuilder(
      listenable: focusNodes[index],
      builder: (_, _) {
        final hasFocus = focusNodes[index].hasFocus;
        return Container(
          width: AppSizes.authOtpBoxSize,
          height: AppSizes.authOtpBoxSize,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: AppRadius.inputRadius,
            border: hasFocus
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
            maxLength: 1,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onTap: () {
              controllers[index].selection = TextSelection(
                baseOffset: 0,
                extentOffset: controllers[index].text.length,
              );
            },
            onChanged: (value) {
              if (value.isNotEmpty && index < length - 1) {
                focusNodes[index + 1].requestFocus();
              }
              onChanged?.call();
            },
            style: AppTypography.authOtpDigit,
            decoration: InputDecoration(
              hintText: '-',
              hintStyle: AppTypography.authOtpDigit.copyWith(
                color: AppTheme.primary.withValues(alpha: 0.5),
              ),
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
      },
    );
  }
}
