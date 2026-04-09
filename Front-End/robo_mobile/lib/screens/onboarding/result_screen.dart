import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/portfolio_data.dart';
import 'login_screen.dart';
import 'widgets/vestor_pie_chart.dart';

class PortfolioResultScreen extends StatefulWidget {
  final MobileRecommendationResponse recommendation;
  final String selectedPortfolioCode;

  const PortfolioResultScreen({
    super.key,
    required this.recommendation,
    required this.selectedPortfolioCode,
  });

  @override
  State<PortfolioResultScreen> createState() => _PortfolioResultScreenState();
}

class _PortfolioResultScreenState extends State<PortfolioResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Widget _stagger(int index, Widget child) {
    final start = (index * 0.1).clamp(0.0, 0.5);
    final end = (start + 0.5).clamp(0.0, 1.0);
    final fade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(fade);
    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: fade, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final portfolio = widget.recommendation
        .portfolioByCodeOrRecommended(widget.selectedPortfolioCode);
    final categories = portfolio.toCategories();

    return Scaffold(
      backgroundColor: tc.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _stagger(
                      0,
                      _ResultTypeCard(
                        recommendation: widget.recommendation,
                        portfolio: portfolio,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _stagger(
                        1,
                        VestorPieChart(categories: categories),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _stagger(
                      2,
                      _BlurredTickerSection(
                        holdings: portfolio.topTickerHoldings(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Pressable(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => LoginScreen(
                        recommendation: widget.recommendation,
                        selectedPortfolioCode: portfolio.code,
                      ),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 400),
                    ),
                  );
                },
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WeRoboColors.primary,
                      foregroundColor: WeRoboColors.white,
                      disabledBackgroundColor: WeRoboColors.primary,
                      disabledForegroundColor: WeRoboColors.white,
                    ),
                    child: const Text('투자 시작하기'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTypeCard extends StatelessWidget {
  final MobileRecommendationResponse recommendation;
  final MobilePortfolioRecommendation portfolio;

  const _ResultTypeCard({
    required this.recommendation,
    required this.portfolio,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '당신에겐 ${portfolio.label} 포트폴리오가 잘 맞아요',
            style: WeRoboTypography.heading3.themed(context),
          ),
          const SizedBox(height: 6),
          Text(
            '${recommendation.resolvedProfile.label} 성향을 반영했어요.',
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _StatCard(
            label: '예상 수익률',
            value: portfolio.expectedReturnLabel,
            color: tc.accent,
          ),
        ],
      ),
    );
  }
}

class _BlurredTickerSection extends StatelessWidget {
  final List<TickerHolding> holdings;

  const _BlurredTickerSection({required this.holdings});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final preview = holdings.isEmpty
        ? const [
            TickerHolding(
                symbol: 'ETF', name: 'Portfolio Holding', percentage: 0),
            TickerHolding(
                symbol: 'BOND', name: 'Portfolio Holding', percentage: 0),
            TickerHolding(
                symbol: 'GLD', name: 'Portfolio Holding', percentage: 0),
          ]
        : holdings;

    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final holding in preview)
                    _holdingRow(
                      context,
                      holding.symbol,
                      '${holding.percentage.toStringAsFixed(1)}%',
                    ),
                ],
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    color: WeRoboColors.white.withValues(alpha: 0.3),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '블러처리',
                            style: WeRoboTypography.bodySmall.copyWith(
                              color: tc.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(로그인/회원가입 후 자세히 공개)',
                            style: WeRoboTypography.caption.copyWith(
                              color: tc.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _holdingRow(BuildContext context, String ticker, String pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(ticker,
              style: WeRoboTypography.bodySmall.themed(context)),
          const Spacer(),
          Text(pct,
              style: WeRoboTypography.bodySmall.themed(context)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: WeRoboTypography.caption.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: WeRoboTypography.heading3.copyWith(
              fontFamily: WeRoboFonts.english,
              color: tc.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
