import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../onboarding_step.dart';

/// One selectable asset chip in the `자산 추가하기` card.
class _OnboardingAsset {
  final String label;
  final Color color;

  const _OnboardingAsset(this.label, this.color);
}

/// The four illustrative asset chips, in display order, sharing step 1's
/// palette: 주식 red, 채권 blue, 금 yellow, 부동산 green. (Labels are
/// illustrative, not the [AssetClass] enum.)
const List<_OnboardingAsset> _kAssets = [
  _OnboardingAsset('주식', WeRoboColors.assetNewGrowth),
  _OnboardingAsset('채권', WeRoboColors.assetShortBond),
  _OnboardingAsset('금', WeRoboColors.assetGold),
  _OnboardingAsset('부동산', WeRoboColors.assetInfraBond),
];

/// 주식 is selected by default; the gate opens when a SECOND asset is added.
const int _kDefaultAsset = 0;

/// Headline shown once the portfolio diversifies (a second asset is added).
const OnboardingHeadline _kAddedHeadline = OnboardingHeadline([
  OnboardingHeadlineLine([OnboardingHeadlineSegment('흔들림은 최소로,')]),
  OnboardingHeadlineLine([OnboardingHeadlineSegment('자산은 꾸준히 우상향합니다.')]),
]);

/// Step 3 visual (INTERACTIVE; folds Figma frames 3 + 4).
///
/// 주식 is selected by default, so the chart opens with a SOLID red volatile
/// line (a stock-only portfolio). Adding a SECOND asset diversifies: the bold
/// navy portfolio line draws in (flatter, steadily rising) while the red line
/// fades to a dotted reference. That first diversification also
///  1. sets `readyNotifier.value = true` (the orchestrator enables `계속하기`
///     and unlocks forward swipe), and
///  2. swaps `headlineNotifier.value` to 흔들림은 최소로, / 자산은 꾸준히 우상향합니다.
///
/// Each further add flattens the navy line a little more. State is local and
/// ephemeral; nothing is persisted.
class DiversificationView extends StatefulWidget {
  /// 0→1 entrance animation, driven by the orchestrator when this page is
  /// active.
  final Animation<double> entrance;

  /// Readiness gate. Set `.value = true` when the portfolio first diversifies.
  final ValueNotifier<bool> readyNotifier;

  /// Live headline the scaffold renders for this step. Pre-seeded with the
  /// default (분산투자만으로 / 위험은 크게 줄어듭니다.); reassigned on diversification.
  final ValueNotifier<OnboardingHeadline> headlineNotifier;

  const DiversificationView({
    super.key,
    required this.entrance,
    required this.readyNotifier,
    required this.headlineNotifier,
  });

  @override
  State<DiversificationView> createState() => _DiversificationViewState();
}

class _DiversificationViewState extends State<DiversificationView>
    with TickerProviderStateMixin {
  /// Indices into [_kAssets] that are selected. 주식 starts selected.
  final Set<int> _added = <int>{_kDefaultAsset};

  /// 0 = stock-only (solid red, no navy line); 1 = diversified (navy line in,
  /// red faded to a dotted reference). Animates on the first diversification.
  late final AnimationController _diversify;

  /// Navy line flatness: wavy (0) → flat-and-rising (1) as more assets join.
  late final AnimationController _smoothness;

  @override
  void initState() {
    super.initState();
    _diversify = AnimationController(
      vsync: this,
      duration: WeRoboMotion.chartDraw,
    );
    _smoothness = AnimationController(
      vsync: this,
      duration: WeRoboMotion.long,
    );
  }

  @override
  void dispose() {
    _diversify.dispose();
    _smoothness.dispose();
    super.dispose();
  }

  bool get _diversified => _added.length >= 2;

  /// Target flatness for the navy line: already clearly smoother at two assets,
  /// flattening toward 1 as more join.
  double get _smoothnessTarget {
    if (!_diversified) return 0.0;
    final extra = (_added.length - 2) / math.max(1, _kAssets.length - 2);
    return (0.55 + 0.45 * extra).clamp(0.0, 1.0);
  }

  void _addAsset(int index) {
    if (_added.contains(index)) return;
    final wasDiversified = _diversified;
    setState(() => _added.add(index));

    // First diversification (the second asset) opens the flow + swaps the
    // headline + reveals the navy line / fades the red. Never reset.
    if (!wasDiversified && _diversified) {
      widget.readyNotifier.value = true;
      widget.headlineNotifier.value = _kAddedHeadline;
      _diversify.forward();
    }
    if (_diversified) {
      _smoothness.animateTo(
        _smoothnessTarget,
        duration: WeRoboMotion.long,
        curve: WeRoboMotion.move,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([widget.entrance, _diversify, _smoothness]),
      builder: (context, _) {
        final reveal = widget.entrance.value;
        return Opacity(
          opacity: reveal.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - reveal) * 16),
            child: Column(
              children: [
                const SizedBox(height: WeRoboSpacing.xl),
                Expanded(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _DiversificationChartPainter(
                        // The solid red (stock-only) line draws left→right over
                        // the first ~70% of the entrance.
                        entranceDraw: (reveal / 0.7).clamp(0.0, 1.0).toDouble(),
                        diversifiedT: _diversify.value,
                        smoothness: _smoothness.value,
                        gridColor: tc.border,
                        redColor: WeRoboColors.gainRed,
                        navyColor: WeRoboColors.primary,
                        markerFillColor: tc.surface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: WeRoboSpacing.xl),
                _AssetAddCard(
                  assets: _kAssets,
                  added: _added,
                  onTap: _addAsset,
                ),
                const SizedBox(height: WeRoboSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The `자산 추가하기` card: a small label above a horizontal row of circular
/// chips. Each chip is a colored dot + label; selected chips show a colored
/// ring.
class _AssetAddCard extends StatelessWidget {
  final List<_OnboardingAsset> assets;
  final Set<int> added;
  final ValueChanged<int> onTap;

  const _AssetAddCard({
    required this.assets,
    required this.added,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WeRoboSpacing.lg),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
        border: Border.all(color: tc.border),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '자산 추가하기',
            style: WeRoboTypography.caption.copyWith(
              color: tc.textTertiary,
            ),
          ),
          const SizedBox(height: WeRoboSpacing.md),
          Row(
            children: [
              for (var i = 0; i < assets.length; i++)
                Expanded(
                  child: _AssetChip(
                    asset: assets[i],
                    selected: added.contains(i),
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single circular asset chip: colored dot inside a ring (the ring goes
/// solid-colored when selected), with its label underneath.
class _AssetChip extends StatelessWidget {
  final _OnboardingAsset asset;
  final bool selected;
  final VoidCallback onTap;

  const _AssetChip({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: asset.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WeRoboSpacing.xxs,
            vertical: WeRoboSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: WeRoboMotion.short,
                curve: WeRoboMotion.move,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? asset.color.withValues(alpha: 0.12)
                      : tc.surface,
                  border: Border.all(
                    color: selected ? asset.color : tc.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: asset.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: WeRoboSpacing.xs),
              Text(
                asset.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: WeRoboTypography.caption.copyWith(
                  color: selected ? asset.color : tc.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints the diversification chart across the diversification transition:
/// - faint dashed gridlines (always),
/// - a red volatile line: SOLID + opaque while stock-only ([diversifiedT] 0),
///   crossfading to a faint DOTTED reference as [diversifiedT] → 1,
/// - a bold navy portfolio line that draws in with [diversifiedT] and flattens
///   from wavy toward flat-and-rising as [smoothness] → 1.
class _DiversificationChartPainter extends CustomPainter {
  /// 0→1 left-to-right reveal of the solid red line during the page entrance.
  final double entranceDraw;

  /// 0 = stock-only (solid red, no navy); 1 = diversified (dotted red + navy).
  final double diversifiedT;

  /// 0 = wavy navy line, 1 = flat-and-steadily-rising.
  final double smoothness;

  final Color gridColor;
  final Color redColor;
  final Color navyColor;

  /// Fill color for the navy line's hollow-cored dot markers.
  final Color markerFillColor;

  _DiversificationChartPainter({
    required this.entranceDraw,
    required this.diversifiedT,
    required this.smoothness,
    required this.gridColor,
    required this.redColor,
    required this.navyColor,
    required this.markerFillColor,
  });

  // Vertical insets so lines and markers never clip the box edges.
  static const double _topPad = 0.12;
  static const double _bottomPad = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _drawGrid(canvas, size);

    final red = _redPoints(size);
    final solidAlpha = (1 - diversifiedT).clamp(0.0, 1.0);
    if (solidAlpha > 0.01) {
      _drawSolidLine(canvas, red, entranceDraw, redColor, solidAlpha, 2.4);
    }
    if (diversifiedT > 0.01) {
      _drawDashedReference(canvas, red, redColor, 0.30 * diversifiedT);
      _drawNavyLine(canvas, size);
    }
  }

  /// Five faint horizontal dashed gridlines.
  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    const rows = 4;
    for (var i = 0; i <= rows; i++) {
      final y = size.height * i / rows;
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), paint,
          dash: 4, gap: 4);
    }
  }

  /// The red volatile shape (a decaying-amplitude sine), as sampled points.
  List<Offset> _redPoints(Size size) {
    const samples = 96;
    final top = size.height * _topPad;
    final h = size.height * (1 - _topPad - _bottomPad);
    final mid = top + h / 2;
    final amp = h * 0.46;
    return [
      for (var i = 0; i <= samples; i++)
        Offset(
          size.width * i / samples,
          mid - amp * math.sin(i / samples * 2.4 * 2 * math.pi),
        ),
    ];
  }

  /// Strokes a solid line through [pts], revealed left→right by [reveal].
  void _drawSolidLine(Canvas canvas, List<Offset> pts, double reveal,
      Color color, double alpha, double width) {
    final shown = _takeFraction(pts, reveal.clamp(0.0, 1.0));
    if (shown.length < 2) return;
    final path = Path()..moveTo(shown.first.dx, shown.first.dy);
    for (var i = 1; i < shown.length; i++) {
      path.lineTo(shown[i].dx, shown[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// The faint dotted red reference line (full length).
  void _drawDashedReference(
      Canvas canvas, List<Offset> pts, Color color, double alpha) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    _drawDashedPath(
      canvas,
      path,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
      dash: 5,
      gap: 5,
    );
  }

  /// The bold navy portfolio line, revealed left→right with [diversifiedT] and
  /// flattened by [smoothness], plus hollow-cored dot markers.
  void _drawNavyLine(Canvas canvas, Size size) {
    final points = _portfolioPoints(size);
    if (points.isEmpty) return;
    final alpha = diversifiedT.clamp(0.0, 1.0);
    final revealed = _takeFraction(points, diversifiedT.clamp(0.0, 1.0));
    if (revealed.length >= 2) {
      final path = Path()..moveTo(revealed.first.dx, revealed.first.dy);
      for (var i = 1; i < revealed.length; i++) {
        path.lineTo(revealed[i].dx, revealed[i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = navyColor.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final revealedCount = (points.length * diversifiedT.clamp(0.0, 1.0))
        .ceil()
        .clamp(0, points.length);
    final ringPaint = Paint()
      ..color = navyColor.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fillPaint = Paint()
      ..color = markerFillColor.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < revealedCount; i++) {
      canvas.drawCircle(points[i], 3.5, fillPaint);
      canvas.drawCircle(points[i], 3.5, ringPaint);
    }
  }

  /// The navy line's control points, interpolated between a wavy baseline
  /// (smoothness 0) and a flat-rising target (smoothness 1).
  List<Offset> _portfolioPoints(Size size) {
    const count = 11;
    final usableTop = size.height * _topPad;
    final usableHeight = size.height * (1 - _topPad - _bottomPad);
    final wavyAmp = usableHeight * 0.26;
    const riseTopFrac = 0.16;
    const riseBottomFrac = 0.82;

    final points = <Offset>[];
    for (var i = 0; i < count; i++) {
      final t = i / (count - 1);
      final x = size.width * t;
      final wavyNorm =
          0.5 - (wavyAmp / usableHeight) * math.sin(t * 2.2 * 2 * math.pi);
      final risingRipple =
          0.03 * math.sin(t * 1.5 * 2 * math.pi) * (1 - smoothness);
      final risingNorm =
          riseBottomFrac + (riseTopFrac - riseBottomFrac) * t + risingRipple;
      final norm = wavyNorm + (risingNorm - wavyNorm) * smoothness;
      points.add(Offset(x, usableTop + usableHeight * norm));
    }
    return points;
  }

  /// Returns the leading [fraction] of a polyline by arc length.
  List<Offset> _takeFraction(List<Offset> pts, double fraction) {
    if (fraction <= 0 || pts.length < 2) {
      return fraction <= 0 ? const [] : pts.take(1).toList();
    }
    if (fraction >= 1) return pts;
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      total += (pts[i] - pts[i - 1]).distance;
    }
    final target = total * fraction;
    final out = <Offset>[pts.first];
    var acc = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final seg = (pts[i] - pts[i - 1]).distance;
      if (acc + seg >= target) {
        final remain = target - acc;
        final f = seg == 0 ? 0.0 : remain / seg;
        out.add(Offset.lerp(pts[i - 1], pts[i], f)!);
        break;
      }
      acc += seg;
      out.add(pts[i]);
    }
    return out;
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
      {required double dash, required double gap}) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var dist = 0.0;
    while (dist < total) {
      final start = a + dir * dist;
      final end = a + dir * math.min(dist + dash, total);
      canvas.drawLine(start, end, paint);
      dist += dash + gap;
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {required double dash, required double gap}) {
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = math.min(dist + dash, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DiversificationChartPainter old) {
    return old.entranceDraw != entranceDraw ||
        old.diversifiedT != diversifiedT ||
        old.smoothness != smoothness ||
        old.gridColor != gridColor ||
        old.redColor != redColor ||
        old.navyColor != navyColor ||
        old.markerFillColor != markerFillColor;
  }
}
