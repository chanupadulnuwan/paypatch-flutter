import 'package:flutter/material.dart';

class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final length = size.width;
    final verticalOffset = (size.height / 2) - (length / 2);
    final bounds = Offset(0, verticalOffset) & Size.square(length);
    final center = bounds.center;
    final arcThickness = size.width / 4.5;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = arcThickness
      ..strokeCap = StrokeCap.butt;

    void drawArc(double startAngle, double sweepAngle, Color color) {
      canvas.drawArc(bounds, startAngle, sweepAngle, false, paint..color = color);
    }

    // Google Brand Colors:
    // Red: #EA4335
    // Amber/Yellow: #FBBC05
    // Green: #34A853
    // Blue: #4285F4
    drawArc(3.5, 1.9, const Color(0xFFEA4335));       // Red (Top)
    drawArc(2.5, 1.0, const Color(0xFFFBBC05));       // Yellow (Left)
    drawArc(0.9, 1.6, const Color(0xFF34A853));       // Green (Bottom)
    drawArc(-0.18, 1.1, const Color(0xFF4285F4));     // Blue (Right)

    // Draw the horizontal bar to complete the "G"
    // It should extend from the center x to the right edge of the arc
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - (arcThickness / 2),
        bounds.centerRight.dx + (arcThickness / 2) - 4,
        bounds.centerRight.dy + (arcThickness / 2),
      ),
      paint
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill
        ..strokeWidth = 0,
    );
  }
}
