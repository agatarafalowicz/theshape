import 'dart:ui';
import 'package:flutter/material.dart';

import '../app_theme.dart';

class DecorativeBlobs extends StatelessWidget {
  const DecorativeBlobs({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -144,
            left: -144,
            child: _Blob(color: AppColors.purple500.withValues(alpha: 0.20)),
          ),
          Positioned(
            bottom: -144,
            right: -144,
            child: _Blob(color: AppColors.blue500.withValues(alpha: 0.20)),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(
        width: 288,
        height: 288,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
