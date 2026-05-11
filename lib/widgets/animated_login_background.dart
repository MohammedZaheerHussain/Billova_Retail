import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Premium animated background for the login screen
/// Creates a professional motion-graphic effect with:
/// - Flowing gradient waves
/// - Floating billing-related icons
/// - Subtle glowing particles
/// - Smooth infinite looping
class AnimatedLoginBackground extends StatefulWidget {
  const AnimatedLoginBackground({super.key});

  @override
  State<AnimatedLoginBackground> createState() => _AnimatedLoginBackgroundState();
}

class _AnimatedLoginBackgroundState extends State<AnimatedLoginBackground>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _floatController;
  late final AnimationController _particleController;
  late final List<_FloatingIcon> _floatingIcons;
  late final List<_GlowParticle> _particles;

  @override
  void initState() {
    super.initState();

    // Wave gradient animation — slow, smooth
    _waveController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    // Floating icons animation
    _floatController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();

    final rng = Random(42);

    // Create floating billing icons
    _floatingIcons = List.generate(12, (i) => _FloatingIcon(
      icon: _billingIcons[i % _billingIcons.length],
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: 18 + rng.nextDouble() * 14,
      speed: 0.3 + rng.nextDouble() * 0.7,
      opacity: 0.04 + rng.nextDouble() * 0.06,
      phase: rng.nextDouble() * 2 * pi,
    ));

    // Create glow particles
    _particles = List.generate(20, (i) => _GlowParticle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: 1.5 + rng.nextDouble() * 2.5,
      speed: 0.2 + rng.nextDouble() * 0.5,
      phase: rng.nextDouble() * 2 * pi,
      color: i % 3 == 0
          ? AppColors.accent
          : i % 3 == 1
              ? AppColors.primary
              : AppColors.primaryLight,
    ));
  }

  static const _billingIcons = [
    Icons.receipt_long_rounded,
    Icons.point_of_sale_rounded,
    Icons.shopping_cart_rounded,
    Icons.inventory_2_rounded,
    Icons.payments_rounded,
    Icons.bar_chart_rounded,
    Icons.qr_code_scanner_rounded,
    Icons.calculate_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.storefront_rounded,
    Icons.local_shipping_rounded,
    Icons.trending_up_rounded,
  ];

  @override
  void dispose() {
    _waveController.dispose();
    _floatController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_waveController, _floatController, _particleController]),
      builder: (context, _) {
        return CustomPaint(
          painter: _BackgroundPainter(
            waveProgress: _waveController.value,
            floatProgress: _floatController.value,
            particleProgress: _particleController.value,
            icons: _floatingIcons,
            particles: _particles,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

// ─── Painter ───

class _BackgroundPainter extends CustomPainter {
  final double waveProgress;
  final double floatProgress;
  final double particleProgress;
  final List<_FloatingIcon> icons;
  final List<_GlowParticle> particles;

  _BackgroundPainter({
    required this.waveProgress,
    required this.floatProgress,
    required this.particleProgress,
    required this.icons,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Deep dark background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF060612),
    );

    // 2. Animated gradient orbs (large, blurred, slow-moving)
    _drawGradientOrbs(canvas, size);

    // 3. Horizontal wave lines
    _drawWaveLines(canvas, size);

    // 4. Grid pattern (subtle)
    _drawGrid(canvas, size);

    // 5. Glow particles
    _drawParticles(canvas, size);
  }

  void _drawGradientOrbs(Canvas canvas, Size size) {
    final phase = waveProgress * 2 * pi;

    // Primary orb (purple) — top-left drift
    final orb1X = size.width * (0.2 + 0.15 * sin(phase));
    final orb1Y = size.height * (0.25 + 0.1 * cos(phase * 0.7));
    canvas.drawCircle(
      Offset(orb1X, orb1Y),
      size.width * 0.35,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(orb1X, orb1Y), radius: size.width * 0.35)),
    );

    // Accent orb (cyan) — bottom-right drift
    final orb2X = size.width * (0.75 + 0.12 * cos(phase * 0.6));
    final orb2Y = size.height * (0.7 + 0.08 * sin(phase * 0.8));
    canvas.drawCircle(
      Offset(orb2X, orb2Y),
      size.width * 0.3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.08),
            AppColors.accent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(orb2X, orb2Y), radius: size.width * 0.3)),
    );

    // Third orb (deep purple) — center drift
    final orb3X = size.width * (0.5 + 0.1 * sin(phase * 1.2));
    final orb3Y = size.height * (0.45 + 0.12 * cos(phase * 0.5));
    canvas.drawCircle(
      Offset(orb3X, orb3Y),
      size.width * 0.25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primaryDark.withValues(alpha: 0.1),
            AppColors.primaryDark.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(orb3X, orb3Y), radius: size.width * 0.25)),
    );
  }

  void _drawWaveLines(Canvas canvas, Size size) {
    final phase = waveProgress * 2 * pi;

    for (int i = 0; i < 5; i++) {
      final yBase = size.height * (0.15 + i * 0.18);
      final path = Path();
      path.moveTo(0, yBase);

      for (double x = 0; x <= size.width; x += 4) {
        final y = yBase +
            sin((x / size.width) * 4 * pi + phase + i * 0.8) * 15 +
            cos((x / size.width) * 2 * pi - phase * 0.5 + i) * 8;
        path.lineTo(x, y);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = (i % 2 == 0 ? AppColors.primary : AppColors.accent)
              .withValues(alpha: 0.03 + (i * 0.008))
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.cardBorderDark.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;

    const spacing = 60.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    for (final p in particles) {
      final phase = particleProgress * 2 * pi;
      final px = (p.x + sin(phase * p.speed + p.phase) * 0.03) * size.width;
      final py = (p.y - particleProgress * p.speed * 0.5 + 0.5) % 1.0 * size.height;
      final opacity = (0.3 + 0.4 * sin(phase * p.speed + p.phase)).clamp(0.1, 0.5);

      canvas.drawCircle(
        Offset(px, py),
        p.radius,
        Paint()..color = p.color.withValues(alpha: opacity),
      );

      // Glow
      canvas.drawCircle(
        Offset(px, py),
        p.radius * 3,
        Paint()..color = p.color.withValues(alpha: opacity * 0.15),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) => true;
}

// ─── Floating Icon Layer (rendered as overlay widget) ───

class FloatingIconsOverlay extends StatelessWidget {
  final double progress;
  final List<IconData> icons;

  const FloatingIconsOverlay({
    super.key,
    required this.progress,
    this.icons = const [
      Icons.receipt_long_rounded,
      Icons.point_of_sale_rounded,
      Icons.shopping_cart_rounded,
      Icons.inventory_2_rounded,
      Icons.payments_rounded,
      Icons.bar_chart_rounded,
      Icons.qr_code_scanner_rounded,
      Icons.calculate_rounded,
      Icons.account_balance_wallet_rounded,
      Icons.storefront_rounded,
      Icons.local_shipping_rounded,
      Icons.trending_up_rounded,
    ],
  });

  @override
  Widget build(BuildContext context) {
    final rng = Random(42);
    return IgnorePointer(
      child: Stack(
        children: List.generate(10, (i) {
          final baseX = rng.nextDouble();
          final baseY = rng.nextDouble();
          final speed = 0.4 + rng.nextDouble() * 0.6;
          final phase = rng.nextDouble() * 2 * pi;
          final size = 18.0 + rng.nextDouble() * 12;
          final opacity = 0.04 + rng.nextDouble() * 0.05;

          final p = progress * 2 * pi;
          final x = baseX + sin(p * speed + phase) * 0.04;
          final y = (baseY - progress * speed * 0.15 + 1.0) % 1.0;
          final rotation = p * speed * 0.3;
          final currentOpacity = (opacity + sin(p * speed + phase) * 0.02).clamp(0.02, 0.1);

          return Positioned(
            left: x * MediaQuery.of(context).size.width,
            top: y * MediaQuery.of(context).size.height,
            child: Transform.rotate(
              angle: rotation,
              child: Icon(
                icons[i % icons.length],
                size: size,
                color: (i % 2 == 0 ? AppColors.primary : AppColors.accent)
                    .withValues(alpha: currentOpacity),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Data Models ───

class _FloatingIcon {
  final IconData icon;
  final double x, y, size, speed, opacity, phase;

  _FloatingIcon({
    required this.icon,
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}

class _GlowParticle {
  final double x, y, radius, speed, phase;
  final Color color;

  _GlowParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.color,
  });
}
