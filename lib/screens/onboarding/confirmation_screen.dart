import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/portfolio_data.dart';
import '../home/home_shell.dart';
import 'widgets/portfolio_charts.dart';
import 'widgets/vestor_pie_chart.dart';

class ConfirmationScreen extends StatefulWidget {
  final InvestmentType investmentType;

  const ConfirmationScreen({super.key, required this.investmentType});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen>
    with SingleTickerProviderStateMixin {
  int? _selectedSector;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  late List<PortfolioCategoryDetail> _details;
  late List<PortfolioCategory> _categories;

  @override
  void initState() {
    super.initState();
    _details = PortfolioData.detailsFor(widget.investmentType);
    _categories = PortfolioData.categoriesFor(widget.investmentType);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Build the center content for the pie chart
  Widget _buildPieCenter() {
    if (_selectedSector == null) {
      return Text(
        key: const ValueKey('default'),
        '포트폴리오\n비중',
        style: WeRoboTypography.heading3
            .copyWith(color: WeRoboColors.textPrimary),
        textAlign: TextAlign.center,
      );
    }

    final detail = _details[_selectedSector!];
    final cat = detail.category;

    return Column(
      key: ValueKey('sector_$_selectedSector'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          cat.name,
          style: WeRoboTypography.caption.copyWith(
            color: WeRoboColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${cat.percentage.toInt()}%',
          style: WeRoboTypography.number.copyWith(
            color: WeRoboColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        // Mini ticker list inside center
        ...detail.tickers.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${t.symbol} ${t.percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontFamily: WeRoboFonts.english,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: WeRoboColors.textSecondary,
                  height: 1.3,
                ),
              ),
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeRoboColors.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_rounded,
                          size: 20, color: WeRoboColors.textPrimary),
                    ),
                    Expanded(
                      child: Text(
                        '${widget.investmentType.label} 포트폴리오 상세',
                        style: WeRoboTypography.heading3,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Pie chart with center detail
              SizedBox(
                height: 260,
                child: VestorPieChart(
                  categories: _categories,
                  size: 260,
                  onSectorSelected: (idx) {
                    setState(() => _selectedSector = idx);
                  },
                  centerBuilder: (_) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildPieCenter(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Charts section
              Expanded(
                child: PortfolioCharts(type: widget.investmentType),
              ),

              // Confirm button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) =>
                              const HomeShell(),
                          transitionsBuilder: (_, anim, __, child) =>
                              FadeTransition(
                                  opacity: anim, child: child),
                          transitionDuration:
                              const Duration(milliseconds: 400),
                        ),
                        (_) => false,
                      );
                    },
                    child: const Text('투자 확정'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

