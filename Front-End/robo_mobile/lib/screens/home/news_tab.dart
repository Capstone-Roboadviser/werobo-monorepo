import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../services/mobile_backend_api.dart';

typedef MarketBriefingApiOverride = Future<MobileMarketBriefingResponse>
    Function();

MarketBriefingApiOverride? _marketBriefingApiOverride;

void debugSetMarketBriefingApiOverride(MarketBriefingApiOverride? override) {
  _marketBriefingApiOverride = override;
}

class NewsTab extends StatefulWidget {
  const NewsTab({super.key});

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> {
  MobileMarketBriefingResponse? _report;
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
      final report = await (_marketBriefingApiOverride?.call() ??
          MobileBackendApi.instance.fetchMarketBriefing());
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
    final tc = WeRoboThemeColors.of(context);
    return SafeArea(
      key: const Key('news_tab'),
      child: RefreshIndicator(
        color: WeRoboColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 시장',
                        style: WeRoboTypography.heading2.copyWith(
                          color: tc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _report == null
                            ? '미국 마감 데이터를 확인하고 있어요'
                            : '${_formatDate(_report!.asOf)} · ${_report!.statusNote}',
                        style: WeRoboTypography.caption.copyWith(
                          color: tc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '새로고침',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  color: WeRoboColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading && _report == null)
              const _LoadingReport()
            else if (_error != null && _report == null)
              _ErrorReport(onRetry: _load)
            else if (_report != null)
              ..._reportSections(context, _report!),
          ],
        ),
      ),
    );
  }

  List<Widget> _reportSections(
    BuildContext context,
    MobileMarketBriefingResponse report,
  ) {
    final ranked = report.sectors;
    final rising =
        ranked.where((sector) => sector.changePct > 0).take(3).toList();
    final falling = ranked.reversed
        .where((sector) => sector.changePct < 0)
        .take(3)
        .toList();
    return [
      _SummaryCard(report: report),
      const SizedBox(height: 16),
      const _SectionTitle(title: '주요 지수'),
      const SizedBox(height: 10),
      _IndexGrid(indices: report.indices),
      const SizedBox(height: 16),
      _MarketBreadthCard(breadth: report.breadth),
      const SizedBox(height: 16),
      if (report.briefing.isNotEmpty) ...[
        const _SectionTitle(title: '오늘의 브리핑'),
        const SizedBox(height: 10),
        _ReportCard(
          child: Column(
            children: [
              for (var index = 0; index < report.briefing.length; index++) ...[
                _BriefingRow(item: report.briefing[index]),
                if (index != report.briefing.length - 1)
                  const Divider(height: 28),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (rising.isNotEmpty) ...[
        const _SectionTitle(title: '🟢 오른 업종'),
        const SizedBox(height: 10),
        _SectorCard(sectors: rising),
        const SizedBox(height: 16),
      ],
      if (falling.isNotEmpty) ...[
        const _SectionTitle(title: '🔴 내린 업종'),
        const SizedBox(height: 10),
        _SectorCard(sectors: falling),
        const SizedBox(height: 16),
      ],
      const _SectionTitle(title: '시장 지표'),
      const SizedBox(height: 10),
      _IndicatorCard(indicators: report.indicators),
      if (report.articles.isNotEmpty) ...[
        const SizedBox(height: 16),
        const _SectionTitle(title: '확인한 주요 보도'),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '뉴스는 시장 배경을 확인하는 데만 사용하며, 등락률은 마감 데이터로 계산합니다.',
            style: WeRoboTypography.caption.copyWith(
              color: WeRoboThemeColors.of(context).textSecondary,
              height: 1.45,
            ),
          ),
        ),
        _ArticleCard(articles: report.articles),
      ],
      const SizedBox(height: 16),
      const _MethodNotice(),
    ];
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }
}

class _SummaryCard extends StatelessWidget {
  final MobileMarketBriefingResponse report;

  const _SummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('market_briefing_summary'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111DBA), Color(0xFF1769E8)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33111DBA),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 7),
              Text(
                '한 줄로',
                style: WeRoboTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.summary,
            style: WeRoboTypography.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: WeRoboTypography.heading3.copyWith(
        color: WeRoboThemeColors.of(context).textPrimary,
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Widget child;

  const _ReportCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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

class _IndexGrid extends StatelessWidget {
  final List<MobileMarketIndex> indices;

  const _IndexGrid({required this.indices});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < indices.length; index++) ...[
              Expanded(child: _IndexCard(index: indices[index])),
              if (index != indices.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class _IndexCard extends StatelessWidget {
  final MobileMarketIndex index;

  const _IndexCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final changeColor =
        index.changePct >= 0 ? WeRoboColors.primary : WeRoboColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WeRoboTypography.caption.copyWith(
              color: tc.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _formatLevel(index.close),
            maxLines: 1,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${index.changePct >= 0 ? '+' : ''}${index.changePct.toStringAsFixed(2)}%',
            style: WeRoboTypography.caption.copyWith(
              color: changeColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLevel(double value) {
    final whole = value.round().toString();
    final chars = whole.split('').reversed.toList();
    final parts = <String>[];
    for (var i = 0; i < chars.length; i += 3) {
      parts.add(chars.skip(i).take(3).toList().reversed.join());
    }
    return parts.reversed.join(',');
  }
}

class _MarketBreadthCard extends StatelessWidget {
  final MobileMarketBreadth breadth;

  const _MarketBreadthCard({required this.breadth});

  @override
  Widget build(BuildContext context) {
    final down = breadth.sectorsTotal - breadth.sectorsUp;
    return _ReportCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: WeRoboColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.stacked_bar_chart_rounded,
              color: WeRoboColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  breadth.marketTone,
                  style: WeRoboTypography.bodySmall.copyWith(
                    color: WeRoboThemeColors.of(context).textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '상승 ${breadth.sectorsUp}개 · 하락 $down개 · 전체 ${breadth.sectorsTotal}개 업종',
                  style: WeRoboTypography.caption.copyWith(
                    color: WeRoboThemeColors.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BriefingRow extends StatelessWidget {
  final MobileMarketBriefingItem item;

  const _BriefingRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: WeRoboTypography.bodySmall.copyWith(
            color: tc.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item.body,
          style: WeRoboTypography.caption.copyWith(
            color: tc.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SectorCard extends StatelessWidget {
  final List<MobileMarketSector> sectors;

  const _SectorCard({required this.sectors});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _ReportCard(
      child: Column(
        children: [
          for (var index = 0; index < sectors.length; index++) ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sectors[index].changePct >= 0
                        ? WeRoboColors.primary
                        : WeRoboColors.error,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${sectors[index].name} · ${sectors[index].etf}',
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${sectors[index].changePct >= 0 ? '+' : ''}${sectors[index].changePct.toStringAsFixed(2)}%',
                  style: WeRoboTypography.bodySmall.copyWith(
                    color: sectors[index].changePct >= 0
                        ? WeRoboColors.primary
                        : WeRoboColors.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (index != sectors.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  final List<MobileMarketIndicator> indicators;

  const _IndicatorCard({required this.indicators});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _ReportCard(
      child: Column(
        children: [
          for (var index = 0; index < indicators.length; index++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    indicators[index].name,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  indicators[index].level,
                  style: WeRoboTypography.bodySmall.copyWith(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (indicators[index].change != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    indicators[index].change!,
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            if (index != indicators.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final List<MobileMarketArticle> articles;

  const _ArticleCard({required this.articles});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _ReportCard(
      child: Column(
        children: [
          for (var index = 0; index < articles.length; index++) ...[
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _open(articles[index].link),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
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
                          const SizedBox(height: 5),
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
            ),
            if (index != articles.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }

  Future<void> _open(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _MethodNotice extends StatelessWidget {
  const _MethodNotice();

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WeRoboColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: WeRoboColors.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 19,
            color: WeRoboColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '가격과 등락률은 미국 마감 종가로 계산합니다. 뉴스는 배경 설명에만 사용하며, 확인되지 않은 원인과 전망은 작성하지 않습니다.',
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
            Text('마감 데이터와 주요 뉴스를 확인하고 있어요'),
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
            '오늘의 시장을 불러오지 못했어요',
            style: WeRoboTypography.body.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '잠시 후 다시 시도해주세요.',
            style: WeRoboTypography.caption.copyWith(color: tc.textSecondary),
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
