import 'package:flutter/material.dart';

import '../app_theme.dart';

class PrimaryGradientButton extends StatefulWidget {
  const PrimaryGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient = AppColors.ctaGradient,
    this.shadowColor = AppColors.orange500,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
    this.borderRadius = 16,
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Gradient gradient;
  final Color shadowColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool enabled;

  @override
  State<PrimaryGradientButton> createState() => _PrimaryGradientButtonState();
}

class _PrimaryGradientButtonState extends State<PrimaryGradientButton> {
  bool _pressed = false;

  bool get _disabled => !widget.enabled || widget.onPressed == null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: _disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: _disabled ? null : () => setState(() => _pressed = false),
      onTap: _disabled ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Opacity(
          opacity: _disabled ? 0.6 : 1.0,
          child: Container(
            width: double.infinity,
            padding: widget.padding,
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: widget.shadowColor.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              child: IconTheme(
                data: const IconThemeData(color: Colors.white, size: 18),
                child: Center(child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
