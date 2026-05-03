import 'package:flutter/material.dart';

enum ShapeId { square, triangle, circle, star, diamond }

class ShapeColors {
  final Color fill;
  final Color glow;
  const ShapeColors({required this.fill, required this.glow});
}

const Map<ShapeId, ShapeColors> shapePalette = {
  ShapeId.square: ShapeColors(
    fill: Color(0xFF60A5FA),
    glow: Color(0x66_60A5FA),
  ),
  ShapeId.triangle: ShapeColors(
    fill: Color(0xFF34D399),
    glow: Color(0x66_34D399),
  ),
  ShapeId.circle: ShapeColors(
    fill: Color(0xFFF87171),
    glow: Color(0x66_F87171),
  ),
  ShapeId.star: ShapeColors(
    fill: Color(0xFFFBBF24),
    glow: Color(0x66_FBBF24),
  ),
  ShapeId.diamond: ShapeColors(
    fill: Color(0xFFA78BFA),
    glow: Color(0x66_A78BFA),
  ),
};

class ShapeWidget extends StatelessWidget {
  const ShapeWidget({super.key, required this.id, this.size = 140});

  final ShapeId id;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ShapePainter(id)),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.id);
  final ShapeId id;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = shapePalette[id]!;

    final scale = size.width / 100;
    Path path = _buildPath(id, scale);

    final glowPaint = Paint()
      ..color = palette.glow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawPath(path, glowPaint);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          palette.fill,
          palette.fill.withValues(alpha: 0.6),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, fillPaint);
  }

  Path _buildPath(ShapeId id, double s) {
    Offset p(double x, double y) => Offset(x * s, y * s);

    switch (id) {
      case ShapeId.square:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(12 * s, 12 * s, 76 * s, 76 * s),
            Radius.circular(6 * s),
          ));
      case ShapeId.triangle:
        return Path()
          ..moveTo(p(50, 8).dx, p(50, 8).dy)
          ..lineTo(p(92, 88).dx, p(92, 88).dy)
          ..lineTo(p(8, 88).dx, p(8, 88).dy)
          ..close();
      case ShapeId.circle:
        return Path()
          ..addOval(Rect.fromCircle(center: p(50, 50), radius: 40 * s));
      case ShapeId.star:
        const pts = [
          [50, 6], [61, 36], [94, 36], [68, 57], [79, 90],
          [50, 68], [21, 90], [32, 57], [6, 36], [39, 36],
        ];
        final path = Path()..moveTo(pts.first[0] * s, pts.first[1] * s);
        for (final pt in pts.skip(1)) {
          path.lineTo(pt[0] * s, pt[1] * s);
        }
        return path..close();
      case ShapeId.diamond:
        return Path()
          ..moveTo(p(50, 6).dx, p(50, 6).dy)
          ..lineTo(p(94, 50).dx, p(94, 50).dy)
          ..lineTo(p(50, 94).dx, p(50, 94).dy)
          ..lineTo(p(6, 50).dx, p(6, 50).dy)
          ..close();
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) =>
      oldDelegate.id != id;
}
