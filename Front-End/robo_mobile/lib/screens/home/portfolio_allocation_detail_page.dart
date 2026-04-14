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
      backgroundColor: tc.background,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            detail.category.name,
                            style: WeRoboTypography.heading3
                                .themed(context)
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _showAmounts ? '평가 금액' : '총 비중',
                                style: WeRoboTypography.caption.copyWith(
                                  color: tc.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _showAmounts
                                    ? _formatWonValue(
                                        widget.baseValue,
                                        totalPercentage,
                                      )
                                    : _formatPercent(totalPercentage),
                                style: WeRoboTypography.heading3.copyWith(
                                  color: tc.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: WeRoboFonts.english,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '구성 종목 수',
                                style: WeRoboTypography.caption.copyWith(
                                  color: tc.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${tickers.length}개',
                                style: WeRoboTypography.heading3.copyWith(
                                  color: tc.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: WeRoboFonts.english,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(
                      color: tc.border.withValues(alpha: 0.4),
                      height: 1,
                      thickness: 0.5,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '구성 종목',
                      style: WeRoboTypography.body.copyWith(
                        color: tc.textPrimary,
                        fontWeight: FontWeight.w600,
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
                      ...List.generate(tickers.length, (index) {
                        final ticker = tickers[index];
                        return Column(
                          children: [
                            _TickerAllocationRow(
                              ticker: ticker,
                              baseValue: widget.baseValue,
                              showAmounts: _showAmounts,
                            ),
                            if (index != tickers.length - 1)
                              Divider(
                                color: tc.border.withValues(alpha: 0.4),
                                height: 1,
                                thickness: 0.5,
                              ),
                          ],
                        );
                      }),
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

  static const double _chipSize = 36.0;
  static const double _padding = 3.0;

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    const totalWidth = _chipSize * 2 + _padding * 2 + 4;
    return Pressable(
      onTap: () => onChanged(!showAmounts),
      child: Container(
        width: totalWidth,
        height: _chipSize + _padding * 2,
        padding: const EdgeInsets.all(_padding),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: showAmounts
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: _chipSize,
                height: _chipSize,
                decoration: BoxDecoration(
                  color: tc.card,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: _chipSize + 2,
                  child: Center(
                    child: Text(
                      '%',
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: !showAmounts
                            ? tc.textPrimary
                            : tc.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontFamily: WeRoboFonts.english,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: _chipSize + 2,
                  child: Center(
                    child: Text(
                      '₩',
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: showAmounts
                            ? tc.textPrimary
                            : tc.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontFamily: WeRoboFonts.english,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TickerAllocationRow extends StatelessWidget {
  final TickerHolding ticker;
  final double? baseValue;
  final bool showAmounts;

  const _TickerAllocationRow({
    required this.ticker,
    required this.baseValue,
    required this.showAmounts,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
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
                const SizedBox(height: 3),
                Text(
                  ticker.name,
                  style: WeRoboTypography.caption.copyWith(
                    color: tc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            showAmounts
                ? _formatWonValue(baseValue, ticker.percentage)
                : _formatPercent(ticker.percentage),
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w600,
              fontFamily: WeRoboFonts.english,
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
