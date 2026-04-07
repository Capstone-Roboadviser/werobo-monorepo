import 'package:flutter/material.dart';
import 'theme.dart';

/// Shimmer loading placeholder that pulses softly.
/// Use instead of spinners for content-area loading.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.04 + (_controller.value * 0.08);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: WeRoboColors.textPrimary.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// A shimmer placeholder for a card-shaped loading area.
class ShimmerCard extends StatelessWidget {
  final double height;

  const ShimmerCard({super.key, this.height = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      child: ShimmerBox(
        width: double.infinity,
        height: height,
        borderRadius: 12,
      ),
    );
  }
}

/// Full loading skeleton for home dashboard.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Asset hero placeholder
          const ShimmerBox(width: 80, height: 14),
          const SizedBox(height: 8),
          const ShimmerBox(width: 200, height: 36),
          const SizedBox(height: 8),
          const ShimmerBox(width: 140, height: 28, borderRadius: 8),
          const SizedBox(height: 28),
          // Quick stats
          Row(
            children: [
              Expanded(child: ShimmerBox(width: double.infinity, height: 56)),
              const SizedBox(width: 16),
              Expanded(child: ShimmerBox(width: double.infinity, height: 56)),
            ],
          ),
          const SizedBox(height: 28),
          // Pie chart placeholder
          const Center(
            child: ShimmerBox(width: 200, height: 200, borderRadius: 100),
          ),
          const SizedBox(height: 28),
          // Trend chart placeholder
          const ShimmerCard(height: 160),
          const SizedBox(height: 12),
          // Activity cards
          const ShimmerCard(height: 68),
          const ShimmerCard(height: 68),
        ],
      ),
    );
  }
}
