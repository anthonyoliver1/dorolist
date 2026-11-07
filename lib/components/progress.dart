import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adaptive.dart';

class CircularProgress extends StatelessWidget {
  final double progress;
  final double totalTime;

  const CircularProgress(
      {super.key, required this.progress, required this.totalTime});

  String _convertDoubleTimeToString(double value) {
    int minutes = value.floor();
    int seconds = ((value - minutes) * 60).round();

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fraction =
        totalTime <= 0 ? 0.0 : (progress / totalTime).clamp(0.0, 1.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: usesCupertino(context)
              ? CustomPaint(
                  painter: _ProgressRing(
                      fraction: fraction,
                      color: colors.secondary,
                      background: colors.secondaryContainer))
              : CircularProgressIndicator(
                  value: fraction,
                  strokeWidth: 10,
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.secondary),
                  strokeCap: StrokeCap.round,
                ),
        ),
        Text(
          _convertDoubleTimeToString(progress),
          style: TextStyle(
              fontSize: 32,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface),
        ),
      ],
    );
  }
}

// Cupertino has no determinate circular progress control; keep the timer ring
// as a neutral drawing while all interactive iOS controls use Cupertino.
class _ProgressRing extends CustomPainter {
  const _ProgressRing(
      {required this.fraction, required this.color, required this.background});
  final double fraction;
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(rect, paint..color = background);
    if (fraction > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false,
          paint..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRing oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.color != color ||
      oldDelegate.background != background;
}
