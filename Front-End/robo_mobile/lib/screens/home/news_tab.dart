import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../services/mobile_backend_api.dart';

typedef WeeklyMarketReportApiOverride = Future<MobileWeeklyMarketReportResponse>
    Function();

WeeklyMarketReportApiOverride? _weeklyMarketReportApiOverride;

void debugSetWeeklyMarketReportApiOverride(
  WeeklyMarketReportApiOverride? override,
) {
  _weeklyMarketReportApiOverride = override;
}

class NewsTab extends StatefulWidget {
  const NewsTab({super.key});

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> {
  MobileWeeklyMarketReportResponse? _report;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final report = await (_weeklyMarketReportApiOverride?.call() ??
          MobileBackendApi.instance.fetchWeeklyMarketReport());
      if (!mounted) return;
      setState(() => _report = report);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return SafeArea(
      key: const Key('news_tab'),
      child: RefreshIndicator(
        color: WeRoboColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            _Header(report: report, loading: _loading, onRefresh: _load),
            const SizedBox(height: 18),
            if (_loading && report == null)
              const _LoadingReport()
            else if (_error != null && report == null)
              _ErrorReport(onRetry: _load)
            else if (report != null)
              ..._buildReport(context, report),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReport(
    BuildContext context,
    MobileWeeklyMarketReportResponse report,
  ) {
    final articleByTitle = <String, MobileMarketArticle>{
      for (final article in report.sources) article.title: article,
    };
    return [
      _IntroNotice(text: report.introduction),
      const SizedBox(height: 16),
      const _SectionBand(title: '이번 주, 한 줄로'),
      const SizedBox(height: 10),
      _OneLineCard(text: report.oneLine),
      const SizedBox(height: 10),
      _KeyFiguresCard(figures: report.keyFigures),
      const SizedBox(height: 22),
      const _SectionBand(title: '이번 주 큰 사건 다섯 가지'),
      const SizedBox(height: 10),
      _EditorialNote(text: report.editorialNote),
      const SizedBox(height: 10),
      for (final event in report.events) ...[
        _EventCard(event: event, articleByTitle: articleByTitle),
        const SizedBox(height: 10),
      ],
      if (report.otherItems.isNotEmpty) ...[
        const SizedBox(height: 4),
        const _SectionBand(title: '그 밖에'),
        const SizedBox(height: 10),
        _BulletCard(items: report.otherItems),
      ],
      const SizedBox(height: 22),
      const _SectionBand(title: '돈이 어느 업종으로 가고 있나'),
      const SizedBox(height: 6),
      const _SectionCaption(
        text: '실제 자금 유입액이 아닌 업종 ETF의 마감 가격 흐름입니다.',
      ),
      const SizedBox(height: 10),
      _SectorFlowCard(flows: report.sectorFlows),
      const SizedBox(height: 10),
      _SummaryNote(label: '읽는 법', text: report.flowSummary),
      const SizedBox(height: 22),
      const _SectionBand(title: '경기 신호등'),
      const SizedBox(height: 10),
      _EconomySignalCard(signals: report.economySignals),
      const SizedBox(height: 10),
      _SummaryNote(label: '한마디', text: report.economySummary),
      const SizedBox(height: 22),
      const _SectionBand(title: '다음 주 일정'),
      const SizedBox(height: 10),
      _CalendarCard(items: report.calendar),
      const SizedBox(height: 22),
      const _SectionBand(title: '고객님 업종 한 줄'),
      const SizedBox(height: 10),
      _PersonalSectorCard(text: _personalSectorLine(context, report)),
      const SizedBox(height: 22),
      const _SectionBand(title: '용어 3개만'),
      const SizedBox(height: 10),
      _GlossaryCard(items: report.glossary),
      if (report.sources.isNotEmpty) ...[
        const SizedBox(height: 22),
        const _SectionBand(title: '확인한 출처'),
        const SizedBox(height: 10),
        _SourceCard(articles: report.sources),
      ],
      if (report.skillSources.isNotEmpty) ...[
        const SizedBox(height: 14),
        _SkillCreditCard(urls: report.skillSources),
      ],
      const SizedBox(height: 18),
      _Disclaimer(text: report.disclaimer),
    ];
  }

  String _personalSectorLine(
    BuildContext context,
    MobileWeeklyMarketReportResponse report,
  ) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<PortfolioStateProvider>();
    final stocks = provider?.notifier?.accountSummary?.stockAllocations ??
        const <MobileStockAllocation>[];
    if (stocks.isEmpty) {
      return '포트폴리오를 확정하면 가장 많이 보유한 업종과 이번 주 흐름을 여기에 연결합니다.';
    }

    final weights = <String, double>{};
    for (final stock in stocks) {
      final sector = stock.sectorName.trim();
      if (sector.isEmpty) continue;
      weights.update(sector, (value) => value + stock.weight,
          ifAbsent: () => stock.weight);
    }
    if (weights.isEmpty) {
      return '보유 종목의 업종 정보를 확인하지 못했습니다.';
    }

    final top = weights.entries.reduce(
      (left, right) => left.value >= right.value ? left : right,
    );
    MobileWeeklySectorFlow? flow;
    for (final item in report.sectorFlows) {
      if (item.name == top.key ||
          item.name.contains(top.key) ||
          top.key.contains(item.name)) {
        flow = item;
        break;
      }
    }
    final weight = (top.value * 100).toStringAsFixed(1);
    if (flow == null) {
      return '가장 많이 보유한 업종은 ${top.key}($weight%)입니다. 이번 주 비교 가능한 업종 데이터를 확인하지 못했습니다.';
    }
    return '가장 많이 보유한 업종은 ${top.key}($weight%)입니다. ${flow.note}';
  }
}

class _Header extends StatelessWidget {
  final MobileWeeklyMarketReportResponse? report;
  final bool loading;
  final Future<void> Function() onRefresh;

  const _Header({
    required this.report,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report?.title ?? '이번 주 시장, 5분 요약',
                key: const Key('weekly_report_title'),
                style: WeRoboTypography.heading2.copyWith(
                  color: tc.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                report == null
                    ? '최근 마감 데이터와 뉴스를 확인하고 있어요'
                    : '${_shortDate(report!.periodStart)} ~ ${_shortDate(report!.periodEnd)} · 미국 마감 기준',
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '새로고침',
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          color: WeRoboColors.primary,
        ),
      ],
    );
  }

  static String _shortDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    return '${date.month}월 ${date.day}일';
  }
}

class _IntroNotice extends StatelessWidget {
  final String text;

  const _IntroNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: WeRoboColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: WeRoboColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: WeRoboColors.primary,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: WeRoboTypography.caption.copyWith(
                color: tc.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionBand extends StatelessWidget {
  final String title;

  const _SectionBand({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        title,
        style: WeRoboTypography.heading3.copyWith(
          color: WeRoboThemeColors.of(context).textPrimary,
        ),
      ),
    );
  }
}

class _SectionCaption extends StatelessWidget {
  final String text;

  const _SectionCaption({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: WeRoboTypography.caption.copyWith(
        color: WeRoboThemeColors.of(context).textSecondary,
        height: 1.4,
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _ReportCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: child,
    );
  }
}

class _OneLineCard extends StatelessWidget {
  final String text;

  const _OneLineCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Text(
        text,
        key: const Key('weekly_one_line'),
        style: WeRoboTypography.body.copyWith(
          color: WeRoboThemeColors.of(context).textPrimary,
          fontWeight: FontWeight.w800,
          height: 1.55,
        ),
      ),
    );
  }
}

class _KeyFiguresCard extends StatelessWidget {
  final List<MobileWeeklyKeyFigure> figures;

  const _KeyFiguresCard({required this.figures});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _ReportCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < figures.length; index++) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Text(
                      figures[index].value,
                      textAlign: TextAlign.center,
                      style: WeRoboTypography.heading3.copyWith(
                        color: figures[index].value.startsWith('-')
                            ? WeRoboColors.error
                            : WeRoboColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      figures[index].label,
                      textAlign: TextAlign.center,
                      style: WeRoboTypography.caption.copyWith(
                        color: tc.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (index != figures.length - 1)
              Container(width: 1, height: 48, color: tc.border),
          ],
        ],
      ),
    );
  }
}

class _EditorialNote extends StatelessWidget {
  final String text;

  const _EditorialNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: WeRoboColors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: WeRoboTypography.caption.copyWith(
                color: tc.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final MobileWeeklyEvent event;
  final Map<String, MobileMarketArticle> articleByTitle;

  const _EventCard({required this.event, required this.articleByTitle});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 26,
                decoration: BoxDecoration(
                  color: WeRoboColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${event.rank}위. ${event.title}',
                  style: WeRoboTypography.body.copyWith(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LabeledText(label: '무슨 일', text: event.whatHappened),
          const SizedBox(height: 9),
          _LabeledText(label: '왜', text: event.why),
          const SizedBox(height: 9),
          _LabeledText(label: '고객님께 어떤 의미인가', text: event.meaning),
          if (event.sourceTitles.isNotEmpty) ...[
            const SizedBox(height: 11),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final title in event.sourceTitles)
                  _SourceChip(article: articleByTitle[title], title: title),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledText extends StatelessWidget {
  final String label;
  final String text;

  const _LabeledText({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return RichText(
      text: TextSpan(
        style: WeRoboTypography.bodySmall.copyWith(
          color: tc.textSecondary,
          height: 1.5,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: tc.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final MobileMarketArticle? article;
  final String title;

  const _SourceChip({required this.article, required this.title});

  @override
  Widget build(BuildContext context) {
    final label = article?.source.isNotEmpty == true ? article!.source : '출처';
    return ActionChip(
      avatar: const Icon(Icons.open_in_new_rounded, size: 14),
      label: Text(label),
      tooltip: title,
      onPressed: article == null ? null : () => _openUrl(article!.link),
      backgroundColor: WeRoboColors.primary.withValues(alpha: 0.07),
      side: BorderSide(
        color: WeRoboColors.primary.withValues(alpha: 0.14),
      ),
      labelStyle: WeRoboTypography.caption.copyWith(
        color: WeRoboColors.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  final List<String> items;

  const _BulletCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _ReportCard(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•', style: TextStyle(color: tc.textPrimary)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    items[index],
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (index != items.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _SectorFlowCard extends StatelessWidget {
  final List<MobileWeeklySectorFlow> flows;

  const _SectorFlowCard({required this.flows});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _ReportCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          const _SectorFlowHeader(),
          for (var index = 0; index < flows.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flows[index].name,
                          style: WeRoboTypography.bodySmall.copyWith(
                            color: tc.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${flows[index].etf} · ${flows[index].note}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: WeRoboTypography.caption.copyWith(
                            color: tc.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _PercentText(value: flows[index].recentSixMonthPct),
                  ),
                  Expanded(
                    flex: 2,
                    child: _PercentText(value: flows[index].ytdPct),
                  ),
                ],
              ),
            ),
            if (index != flows.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _SectorFlowHeader extends StatelessWidget {
  const _SectorFlowHeader();

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final style = WeRoboTypography.caption.copyWith(
      color: tc.textTertiary,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('업종', style: style)),
          Expanded(flex: 2, child: Text('최근 6개월', style: style)),
          Expanded(flex: 2, child: Text('연초 이후', style: style)),
        ],
      ),
    );
  }
}

class _PercentText extends StatelessWidget {
  final double value;

  const _PercentText({required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%',
      textAlign: TextAlign.right,
      style: WeRoboTypography.bodySmall.copyWith(
        color: value >= 0 ? WeRoboColors.primary : WeRoboColors.error,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SummaryNote extends StatelessWidget {
  final String label;
  final String text;

  const _SummaryNote({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return RichText(
      text: TextSpan(
        style: WeRoboTypography.bodySmall.copyWith(
          color: tc.textSecondary,
          height: 1.5,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: tc.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
    );
  }
}

class _EconomySignalCard extends StatelessWidget {
  final List<MobileWeeklyEconomySignal> signals;

  const _EconomySignalCard({required this.signals});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _ReportCard(
      child: Column(
        children: [
          for (var index = 0; index < signals.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _signalColor(signals[index].signal),
                    boxShadow: [
                      BoxShadow(
                        color: _signalColor(signals[index].signal)
                            .withValues(alpha: 0.25),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              signals[index].indicator,
                              style: WeRoboTypography.bodySmall.copyWith(
                                color: tc.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            signals[index].level,
                            style: WeRoboTypography.bodySmall.copyWith(
                              color: tc.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        signals[index].meaning,
                        style: WeRoboTypography.caption.copyWith(
                          color: tc.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (index != signals.length - 1) const Divider(height: 25),
          ],
        ],
      ),
    );
  }

  Color _signalColor(String signal) {
    return switch (signal) {
      'green' => const Color(0xFF35C987),
      'red' => const Color(0xFFE83C59),
      _ => const Color(0xFFF2BE32),
    };
  }
}

class _CalendarCard extends StatelessWidget {
  final List<MobileWeeklyCalendarItem> items;

  const _CalendarCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    if (items.isEmpty) {
      return _ReportCard(
        child: Text(
          '출처로 확인된 다음 주 주요 일정이 없습니다. 확인되지 않은 일정은 임의로 넣지 않습니다.',
          style: WeRoboTypography.bodySmall.copyWith(
            color: tc.textSecondary,
            height: 1.5,
          ),
        ),
      );
    }
    return _ReportCard(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 86,
                  child: Text(
                    items[index].whenKst,
                    style: WeRoboTypography.caption.copyWith(
                      color: WeRoboColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[index].what,
                        style: WeRoboTypography.bodySmall.copyWith(
                          color: tc.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[index].why,
                        style: WeRoboTypography.caption.copyWith(
                          color: tc.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (index != items.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _PersonalSectorCard extends StatelessWidget {
  final String text;

  const _PersonalSectorCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _ReportCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: WeRoboColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: WeRoboColors.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlossaryCard extends StatelessWidget {
  final List<MobileWeeklyGlossaryItem> items;

  const _GlossaryCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _LabeledText(
              label: items[index].term,
              text: items[index].description,
            ),
            if (index != items.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final List<MobileMarketArticle> articles;

  const _SourceCard({required this.articles});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _ReportCard(
      child: Column(
        children: [
          for (var index = 0; index < articles.length; index++) ...[
            InkWell(
              onTap: () => _openUrl(articles[index].link),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          articles[index].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: WeRoboTypography.bodySmall.copyWith(
                            color: tc.textPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          articles[index].source,
                          style: WeRoboTypography.caption.copyWith(
                            color: tc.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 17,
                    color: tc.textTertiary,
                  ),
                ],
              ),
            ),
            if (index != articles.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _SkillCreditCard extends StatelessWidget {
  final List<String> urls;

  const _SkillCreditCard({required this.urls});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        '사용한 공개 스킬과 출처',
        style: WeRoboTypography.caption.copyWith(
          color: tc.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      children: [
        for (final url in urls)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              Uri.parse(url).pathSegments.last,
              style: WeRoboTypography.caption.copyWith(
                color: WeRoboColors.primary,
              ),
            ),
            trailing: const Icon(Icons.open_in_new_rounded, size: 15),
            onTap: () => _openUrl(url),
          ),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  final String text;

  const _Disclaimer({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: WeRoboTypography.caption.copyWith(
        color: WeRoboThemeColors.of(context).textTertiary,
        height: 1.5,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _LoadingReport extends StatelessWidget {
  const _LoadingReport();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 120),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: WeRoboColors.primary),
            SizedBox(height: 16),
            Text('이번 주 시장과 주요 사건을 정리하고 있어요'),
          ],
        ),
      ),
    );
  }
}

class _ErrorReport extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ErrorReport({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _ReportCard(
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 38, color: tc.textTertiary),
          const SizedBox(height: 12),
          Text(
            '주간 리포트를 불러오지 못했어요',
            style: WeRoboTypography.body.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 불러오기'),
          ),
        ],
      ),
    );
  }
}

Future<void> _openUrl(String link) async {
  final uri = Uri.tryParse(link);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
