import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/portfolio_data.dart';
import 'login_screen.dart';
import 'widgets/vestor_pie_chart.dart';

class PortfolioResultScreen extends StatelessWidget {
  final double dotT;

  const PortfolioResultScreen({super.key, required this.dotT});

  @override
  Widget build(BuildContext context) {
    final type = InvestmentType.fromDotT(dotT);
    final categories = PortfolioData.categoriesFor(type);

    return Scaffold(
      backgroundColor: WeRoboColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _ResultTypeCard(type: type),
                    const SizedBox(height: 20),
                    Expanded(
                      child: VestorPieChart(categories: categories),
                    ),
                    const SizedBox(height: 16),
                    const _BlurredTickerSection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) =>
                            LoginScreen(investmentType: type),
                        transitionsBuilder: (_, anim, __, child) =>
                            FadeTransition(opacity: anim, child: child),
                        transitionDuration:
                            const Duration(milliseconds: 400),
                      ),
                    );
                  },
                  child: const Text('투자 시작하기'),
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
  final InvestmentType type;
  const _ResultTypeCard({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        color: WeRoboColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('투자 성향 결과', style: WeRoboTypography.heading3,
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('(${type.description})',
              style: WeRoboTypography.bodySmall
                  .copyWith(color: WeRoboColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _BlurredTickerSection extends StatelessWidget {
  const _BlurredTickerSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: WeRoboColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fakeRow('VTV', '8.5%'),
                  _fakeRow('QQQ', '6.8%'),
                  _fakeRow('GLD', '8.0%'),
                ],
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    color: WeRoboColors.white.withValues(alpha: 0.3),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('블러처리',
                              style: WeRoboTypography.heading3
                                  .copyWith(color: WeRoboColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('(로그인/회원가입 후 자세히 공개)',
                              style: WeRoboTypography.bodySmall.copyWith(
                                  color: WeRoboColors.textSecondary)),
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

  static Widget _fakeRow(String ticker, String pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(ticker, style: WeRoboTypography.bodySmall),
          const Spacer(),
          Text(pct, style: WeRoboTypography.bodySmall),
        ],
      ),
    );
  }
}
