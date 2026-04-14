import 'package:flutter/material.dart';

import '../../app/debug_page_logger.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/portfolio_data.dart';

class PortfolioAllocationDetailPage extends StatefulWidget {
  final PortfolioCategoryDetail detail;
  final double? baseValue;
  final bool initialShowAmounts;

  const PortfolioAllocationDetailPage({
    super.key,
    required this.detail,
    required this.baseValue,
    required this.initialShowAmounts,
  });

  @override
  State<PortfolioAllocationDetailPage> createState() =>
      _PortfolioAllocationDetailPageState();
}

class _PortfolioAllocationDetailPageState
    extends State<PortfolioAllocationDetailPage> {
  late bool _showAmounts;

  @override
  void initState() {
    super.initState();
    _showAmounts = widget.initialShowAmounts;
    logPageEnter('PortfolioAllocationDetailPage');
  }

  @override
  void dispose() {
    logPageExit('PortfolioAllocationDetailPage');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final detail = widget.detail;
    final tickers = [...detail.tickers]
      ..sort((a, b) => b.percentage.compareTo(a.percentage));
    final totalPercentage = detail.category.percentage;

    return Scaffold(
      backgroundColor: tc.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tc.card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '자산군 상세',
                      style: WeRoboTypography.heading2.themed(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      '현재 포트폴리오 안에서 선택한 자산군이 어떻게 구성되어 있는지 확인할 수 있습니다.',
                      style: WeRoboTypography.body.copyWith(
                        color: tc.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: tc.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: detail.category.color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detail.category.name,
                                      style: WeRoboTypography.heading3
                                          .themed(context)
                                          .copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '포트폴리오 내 비중과 대표 종목을 함께 보여줍니다.',
                                      style:
                                          WeRoboTypography.bodySmall.copyWith(
                                        color: tc.textSecondary,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _DetailValueToggle(
                                showAmounts: _showAmounts,
                                onChanged: (showAmounts) {
                                  setState(() => _showAmounts = showAmounts);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryMetricCard(
                                  label: _showAmounts ? '평가 금액' : '총 비중',
                                  value: _showAmounts
                                      ? _formatWonValue(
                                          widget.baseValue,
                                          totalPercentage,
                                        )
                                      : _formatPercent(totalPercentage),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SummaryMetricCard(
                                  label: '구성 종목 수',
                                  value: '${tickers.length}개',
                                ),
                              ),
                            ],
                          ),
                          if (tickers.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              '대표 종목',
                              style: WeRoboTypography.caption.copyWith(
                                color: tc.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: tickers
                                  .take(3)
                                  .map(
                                    (ticker) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tc.surface,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        ticker.symbol,
                                        style:
                                            WeRoboTypography.caption.copyWith(
                                          color: tc.textPrimary,
                                          fontFamily: WeRoboFonts.english,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '구성 종목',
                      style: WeRoboTypography.heading3.themed(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _showAmounts
                          ? '각 종목의 현재 평가 금액 기준 배분을 보여줍니다.'
                          : '각 종목이 포트폴리오 전체에서 차지하는 비중을 보여줍니다.',
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: tc.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (tickers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            '세부 종목 데이터가 없습니다.',
                            style: WeRoboTypography.bodySmall.copyWith(
                              color: tc.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...tickers.map(
                        (ticker) => _TickerAllocationCard(
                          ticker: ticker,
                          categoryPercentage: totalPercentage,
                          baseValue: widget.baseValue,
                          showAmounts: _showAmounts,
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailValueToggle extends StatelessWidget {
  final bool showAmounts;
  final ValueChanged<bool> onChanged;

  const _DetailValueToggle({
    required this.showAmounts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tc.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DetailValueToggleChip(
            label: '%',
            isActive: !showAmounts,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 6),
          _DetailValueToggleChip(
            label: '₩',
            isActive: showAmounts,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _DetailValueToggleChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _DetailValueToggleChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? tc.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: WeRoboTypography.bodySmall.copyWith(
            color: tc.textPrimary.withValues(alpha: isActive ? 1 : 0.58),
            fontWeight: FontWeight.w700,
            fontFamily: WeRoboFonts.english,
          ),
        ),
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetricCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: WeRoboTypography.caption.copyWith(
              color: tc.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: WeRoboTypography.heading3.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w700,
              fontFamily: WeRoboFonts.english,
            ),
          ),
        ],
      ),
    );
  }
}

class _TickerAllocationCard extends StatelessWidget {
  final TickerHolding ticker;
  final double categoryPercentage;
  final double? baseValue;
  final bool showAmounts;

  const _TickerAllocationCard({
    required this.ticker,
    required this.categoryPercentage,
    required this.baseValue,
    required this.showAmounts,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final portfolioRatio = ticker.percentage;
    final withinCategoryRatio = categoryPercentage <= 0
        ? 0.0
        : (portfolioRatio / categoryPercentage).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticker.symbol,
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: tc.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontFamily: WeRoboFonts.english,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticker.name,
                      style: WeRoboTypography.caption.copyWith(
                        color: tc.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    showAmounts
                        ? _formatWonValue(baseValue, portfolioRatio)
                        : _formatPercent(portfolioRatio),
                    style: WeRoboTypography.heading3.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontFamily: WeRoboFonts.english,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '포트폴리오 기준 ${_formatPercent(portfolioRatio)}',
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                      fontFamily: WeRoboFonts.english,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: withinCategoryRatio,
              minHeight: 8,
              backgroundColor: tc.surface,
              valueColor: AlwaysStoppedAnimation<Color>(WeRoboColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '자산군 내 ${(withinCategoryRatio * 100).toStringAsFixed(1)}%',
              style: WeRoboTypography.caption.copyWith(
                color: tc.textSecondary,
                fontFamily: WeRoboFonts.english,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPercent(double value) {
  return '${value.toStringAsFixed(2)}%';
}

String _formatWonValue(double? baseValue, double percentage) {
  if (baseValue == null || baseValue <= 0) {
    return '-';
  }
  final amount = (baseValue * percentage / 100).round();
  return '₩${_formatCurrency(amount)}';
}

String _formatCurrency(int amount) {
  final str = amount.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buf.write(',');
    }
    buf.write(str[i]);
  }
  return buf.toString();
}
