import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Step 6 visual: a central navy `AI` chip with a subtle pulse and four
/// dash-marching dotted connectors radiating to four small satellite icons
/// (defense/global, commodities, world economy, rising market).
///
/// The whole graphic fades + lifts + scales in off [entrance]; on top of that
/// a looping controller drives the chip pulse and the marching-dash offset so
/// the connectors feel like live data flowing into the AI.
class AiManagementView extends StatefulWidget {
  /// 0→1 entrance animation, driven by the orchestrator when this page is
  /// active.
  final Animation<double> entrance;

  const AiManagementView({
    super.key,
    required this.entrance,
  });

  @override
  State<AiManagementView> createState() => _AiManagementViewState();
}

class _AiManagementViewState extends State<AiManagementView>
    with SingleTickerProviderStateMixin {
  /// Continuously looping driver for the dash-march + chip pulse. Independent
  /// of [AiManagementView.entrance] so the ambient motion keeps going after the
  /// reveal settles.
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    // Drive on both the entrance reveal and the ambient loop.
    final driver = Listenable.merge([widget.entrance, _loop]);

    return LayoutBuilder(
      builder: (context, constraints) {
        // A centered square keeps the radial layout balanced regardless of the
        // Expanded box's aspect ratio.
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: AnimatedBuilder(
              animation: driver,
              builder: (context, _) {
                final reveal = widget.entrance.value;
                // Eased reveal for the lift/scale of the whole graphic.
                final lift = (1 - reveal) * 24.0;
                final scale = 0.92 + 0.08 * reveal;

                return Opacity(
                  opacity: reveal.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, lift),
                    child: Transform.scale(
                      scale: scale,
                      child: _AiRadialGraphic(
                        reveal: reveal,
                        loop: _loop.value,
                        connectorColor: WeRoboColors.assetShortBond,
                        chipColor: WeRoboColors.primary,
                        glowColor: WeRoboColors.assetTier5,
                        cardColor: tc.surface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// The square radial composition: a [CustomPaint] for the marching-dash
/// connectors + the glowing AI chip, with four positioned satellite icons and
/// the `AI` label overlaid as real widgets (crisp text/icons, easy to test).
class _AiRadialGraphic extends StatelessWidget {
  /// 0→1 entrance reveal; gates how far each connector has "drawn" outward and
  /// staggers the satellite fade-in.
  final double reveal;

  /// 0→1 ambient loop phase for the dash march + chip pulse.
  final double loop;

  final Color connectorColor;
  final Color chipColor;
  final Color glowColor;
  final Color cardColor;

  const _AiRadialGraphic({
    required this.reveal,
    required this.loop,
    required this.connectorColor,
    required this.chipColor,
    required this.glowColor,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        final center = Offset(side / 2, side / 2);

        // Chip size scales with the box; the satellites sit on a ring.
        final chipSize = side * 0.26;
        final satelliteSize = side * 0.15;
        final ringRadius = side * 0.34;

        final satellites = _satelliteLayout(center, ringRadius);

        return Stack(
          children: [
            // Connectors + chip glow/fill, painted beneath the overlays.
            Positioned.fill(
              child: CustomPaint(
                painter: _AiManagementPainter(
                  center: center,
                  chipSize: chipSize,
                  satellites: satellites
                      .map((s) => s.center)
                      .toList(growable: false),
                  reveal: reveal,
                  loop: loop,
                  connectorColor: connectorColor,
                  chipColor: chipColor,
                  glowColor: glowColor,
                ),
              ),
            ),

            // Center AI chip label (overlaid so text stays crisp).
            Positioned(
              left: center.dx - chipSize / 2,
              top: center.dy - chipSize / 2,
              width: chipSize,
              height: chipSize,
              child: Center(
                child: Text(
                  'AI',
                  style: WeRoboTypography.heading3.copyWith(
                    color: WeRoboColors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Four satellite icons, staggered fade-in after the connectors
            // begin drawing.
            for (var i = 0; i < satellites.length; i++)
              _SatelliteIcon(
                spec: satellites[i],
                size: satelliteSize,
                // Stagger: each satellite eases in over a later slice of the
                // reveal so they "light up" one after another.
                appear: _staggered(reveal, i, satellites.length),
                cardColor: cardColor,
                iconColor: satellites[i].color,
              ),
          ],
        );
      },
    );
  }

  /// Even angular placement of the four satellites at the diagonal corners
  /// (top-left, top-right, bottom-left, bottom-right) so the cross of
  /// connectors reads clearly.
  List<_SatelliteSpec> _satelliteLayout(Offset center, double radius) {
    // Diagonal directions, in screen space (y grows downward).
    const diag = math.sqrt1_2; // cos/sin of 45°.
    return [
      // top-left: global defense — shield.
      _SatelliteSpec(
        center: center + Offset(-radius * diag, -radius * diag),
        icon: Icons.shield,
        color: WeRoboColors.primary,
      ),
      // top-right: commodities — oil barrel.
      _SatelliteSpec(
        center: center + Offset(radius * diag, -radius * diag),
        icon: Icons.oil_barrel,
        color: WeRoboColors.assetGold,
      ),
      // bottom-left: global trade — cargo ship.
      _SatelliteSpec(
        center: center + Offset(-radius * diag, radius * diag),
        icon: Icons.directions_boat_filled,
        color: WeRoboColors.assetUSValue,
      ),
      // bottom-right: rising market — red trend.
      _SatelliteSpec(
        center: center + Offset(radius * diag, radius * diag),
        icon: Icons.trending_up,
        color: WeRoboColors.assetNewGrowth,
      ),
    ];
  }

  /// Maps the global [reveal] to a per-index 0→1 appearance value so the
  /// satellites stagger in after the connectors start drawing.
  double _staggered(double reveal, int index, int count) {
    // Reserve the first 35% of the reveal for the connectors reaching out,
    // then fade satellites across the back 65% with a small per-index offset.
    const start = 0.35;
    final span = (1 - start);
    final step = span / (count + 1);
    final local = (reveal - start - step * index) / step;
    return local.clamp(0.0, 1.0);
  }
}

/// Immutable description of one satellite: where it sits and which glyph +
/// tint it uses.
@immutable
class _SatelliteSpec {
  final Offset center;
  final IconData icon;
  final Color color;

  const _SatelliteSpec({
    required this.center,
    required this.icon,
    required this.color,
  });
}

/// A single round satellite chip (white card + hairline ring + icon), faded +
/// scaled in by [appear].
class _SatelliteIcon extends StatelessWidget {
  final _SatelliteSpec spec;
  final double size;
  final double appear;
  final Color cardColor;
  final Color iconColor;

  const _SatelliteIcon({
    required this.spec,
    required this.size,
    required this.appear,
    required this.cardColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final scale = 0.7 + 0.3 * appear;
    return Positioned(
      left: spec.center.dx - size / 2,
      top: spec.center.dy - size / 2,
      width: size,
      height: size,
      child: Opacity(
        opacity: appear.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              shape: BoxShape.circle,
              boxShadow: WeRoboElevation.medium,
            ),
            child: Icon(
              spec.icon,
              size: size * 0.52,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the four marching-dash connectors from the satellites toward the
/// central chip, plus the chip's pulsing glow and rounded-square fill.
class _AiManagementPainter extends CustomPainter {
  final Offset center;
  final double chipSize;
  final List<Offset> satellites;

  /// 0→1 entrance reveal; connectors draw from the chip outward as this grows.
  final double reveal;

  /// 0→1 ambient loop phase (dash march + pulse).
  final double loop;

  final Color connectorColor;
  final Color chipColor;
  final Color glowColor;

  _AiManagementPainter({
    required this.center,
    required this.chipSize,
    required this.satellites,
    required this.reveal,
    required this.loop,
    required this.connectorColor,
    required this.chipColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintConnectors(canvas);
    _paintChip(canvas);
  }

  void _paintConnectors(Canvas canvas) {
    final chipHalf = chipSize / 2;
    // Round dots marching outward from the chip toward each satellite.
    const spacing = 9.0;
    const dotRadius = 1.7;
    final phase = (loop * spacing) % spacing; // 0→spacing over one loop.

    final dotPaint = Paint()
      ..color = connectorColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // How far the connectors have "drawn" out from the chip (0→1) over the
    // first 35% of the reveal.
    final drawFrac = (reveal / 0.35).clamp(0.0, 1.0);

    for (final satellite in satellites) {
      final dir = satellite - center;
      final dist = dir.distance;
      if (dist <= 0) continue;
      final unit = dir / dist;

      // Start just outside the chip edge, stop just short of the satellite.
      final startGap = chipHalf + chipSize * 0.10;
      final endGap = chipSize * 0.42;
      final start = center + unit * startGap;
      final fullLen = dist - startGap - endGap;
      if (fullLen <= 0) continue;

      final drawnLen = fullLen * drawFrac;

      // Place dots along the drawn length, offset by the marching phase.
      var d = phase;
      while (d < drawnLen) {
        canvas.drawCircle(start + unit * d, dotRadius, dotPaint);
        d += spacing;
      }
    }
  }

  void _paintChip(Canvas canvas) {
    final chipHalf = chipSize / 2;
    // Pulse: gentle sine in/out for the glow radius + alpha.
    final pulse = 0.5 + 0.5 * math.sin(loop * 2 * math.pi);

    // Outer glow grows with reveal then breathes with the pulse.
    final glowRadius = chipSize * (0.62 + 0.12 * pulse) * reveal;
    if (glowRadius > 0) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.45 * reveal)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          chipSize * 0.20,
        );
      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    // Rounded-square chip fill.
    final rect = Rect.fromCenter(
      center: center,
      width: chipSize,
      height: chipSize,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(chipSize * 0.28),
    );

    final lighter = Color.lerp(chipColor, Colors.white, 0.28) ?? chipColor;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [lighter, chipColor],
      ).createShader(rect);
    canvas.drawRRect(rrect, fillPaint);

    // Subtle highlight ring that brightens with the pulse.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = glowColor.withValues(alpha: 0.35 + 0.25 * pulse);
    final ringRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: chipSize + chipHalf * 0.18,
        height: chipSize + chipHalf * 0.18,
      ),
      Radius.circular(chipSize * 0.32),
    );
    canvas.drawRRect(ringRect, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _AiManagementPainter old) {
    return old.reveal != reveal ||
        old.loop != loop ||
        old.center != center ||
        old.chipSize != chipSize ||
        old.connectorColor != connectorColor ||
        old.chipColor != chipColor ||
        old.glowColor != glowColor;
  }
}
