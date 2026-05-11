import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import 'insight_detail_page.dart';

/// Categories that can be filtered on the notification history page.
/// Mirrors the dropdown sheet's `_NotificationKind` (kept separate so the
/// history page can be edited without touching the sheet).
enum NotificationKind {
  monthlySummary,
  contribution,
  algorithmSignal,
  volatilityAlert,
  assetNews,
}

String _notificationLabel(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.monthlySummary:
      return '월간 요약';
    case NotificationKind.contribution:
      return '기여도 알림';
    case NotificationKind.algorithmSignal:
      return '알고리즘 시그널';
    case NotificationKind.volatilityAlert:
      return '시장 변동성 경고';
    case NotificationKind.assetNews:
      return '자산군별 뉴스';
  }
}

String _notificationIcon(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.monthlySummary:
      return 'assets/icons/calendar.png';
    case NotificationKind.contribution:
      return 'assets/icons/contribution-alarm.png';
    case NotificationKind.algorithmSignal:
      return 'assets/icons/algorithm-signal.png';
    case NotificationKind.volatilityAlert:
      return 'assets/icons/change-alert.png';
    case NotificationKind.assetNews:
      return 'assets/icons/asset-news.png';
  }
}

String? _formatKoreanDate(String iso) {
  if (iso.length < 10) return null;
  final month = int.tryParse(iso.substring(5, 7));
  final day = int.tryParse(iso.substring(8, 10));
  if (month == null || day == null) return null;
  return '$month월 $day일';
}

String _triggerSentence(String? trigger) {
  switch (trigger) {
    case 'scheduled':
      return '정기 리밸런싱이 실행됐어요';
    case 'drift_guard':
      return '드리프트 가드가 작동했어요';
    case 'threshold':
      return '임계치 초과로 조정됐어요';
    case null:
      return '리밸런싱이 실행됐어요';
    default:
      return '리밸런싱이 실행됐어요';
  }
}

class _NotificationItem {
  final NotificationKind kind;
  final String title;
  final VoidCallback? onTap;
  const _NotificationItem({
    required this.kind,
    required this.title,
    this.onTap,
  });
}

class ActivityHubPage extends StatefulWidget {
  const ActivityHubPage({super.key});

  @override
  State<ActivityHubPage> createState() => _ActivityHubPageState();
}

class _ActivityHubPageState extends State<ActivityHubPage> {
  NotificationKind? _filter; // null = 전체

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final items = _buildItems(state, context);

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: back + filter pill
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
                  _FilterPill(
                    selected: _filter,
                    onTap: _showFilterPicker,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? _EmptyState(filter: _filter)
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: tc.card,
                        indent: 20,
                        endIndent: 20,
                      ),
                      itemBuilder: (_, i) => _HistoryRow(item: items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_NotificationItem> _buildItems(
    PortfolioState state,
    BuildContext context,
  ) {
    final filter = _filter;
    final items = <_NotificationItem>[];

    bool show(NotificationKind k) => filter == null || filter == k;

    // Monthly summary — single current item if data is available.
    if (show(NotificationKind.monthlySummary)) {
      final monthly = state.trailingMonthReturn;
      if (monthly != null) {
        final sign = monthly >= 0 ? '+' : '−';
        final pct = (monthly.abs() * 100).toStringAsFixed(1);
        items.add(_NotificationItem(
          kind: NotificationKind.monthlySummary,
          title: '지난 30일 포트폴리오 $sign$pct%',
        ));
      }
    }

    // Contribution — single current item.
    if (show(NotificationKind.contribution)) {
      final c = state.topContributorOver30d;
      if (c != null) {
        final pct = (c.weight * c.assetReturn * 100).abs().round();
        items.add(_NotificationItem(
          kind: NotificationKind.contribution,
          title: '이번 달 ${c.label}이 수익의 $pct%를 기여했어요',
        ));
      }
    }

    // Algorithm signal — full history of insights.
    if (show(NotificationKind.algorithmSignal)) {
      for (final insight in state.insights) {
        final dateLabel = _formatKoreanDate(insight.rebalanceDate);
        final sentence = _triggerSentence(insight.trigger);
        final title = dateLabel == null
            ? sentence
            : '$dateLabel $sentence';
        items.add(_NotificationItem(
          kind: NotificationKind.algorithmSignal,
          title: title,
          onTap: () => Navigator.of(context).push(
            WeRoboMotion.fadeRoute<void>(
              InsightDetailPage(insight: insight),
            ),
          ),
        ));
      }
    }

    // Volatility — single current item if data is in state.
    if (show(NotificationKind.volatilityAlert)) {
      final spike = state.portfolioVolatilitySpike;
      if (spike != null) {
        final pct = (spike.percentAboveAverage * 100).round();
        items.add(_NotificationItem(
          kind: NotificationKind.volatilityAlert,
          title: '포트폴리오 변동성 +$pct% 주의 구간이에요',
        ));
      }
    }

    // Asset news — not persisted in state, so the history page leaves
    // this category empty (the dropdown is the only surface that fetches).
    return items;
  }

  Future<void> _showFilterPicker() async {
    final tc = WeRoboThemeColors.of(context);
    final picked = await showModalBottomSheet<NotificationKind?>(
      context: context,
      backgroundColor: tc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final options = <NotificationKind?>[
          null, // 전체
          ...NotificationKind.values,
        ];
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: tc.card,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              for (final opt in options)
                Pressable(
                  onTap: () => Navigator.of(sheetCtx).pop(opt),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        _filterIcon(opt, size: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            opt == null ? '전체' : _notificationLabel(opt),
                            style: WeRoboTypography.bodySmall.copyWith(
                              color: tc.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (opt == _filter)
                          Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: WeRoboColors.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    // showModalBottomSheet returns null on barrier dismiss too — only
    // overwrite when the user explicitly chose something.
    setState(() => _filter = picked);
  }
}

Widget _filterIcon(NotificationKind? kind, {double size = 20}) {
  if (kind == null) {
    return Icon(
      Icons.notifications_none_rounded,
      size: size,
      color: WeRoboColors.textPrimary,
    );
  }
  return SizedBox(
    width: size,
    height: size,
    child: Image.asset(_notificationIcon(kind), fit: BoxFit.contain),
  );
}

class _FilterPill extends StatelessWidget {
  final NotificationKind? selected;
  final VoidCallback onTap;
  const _FilterPill({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _filterIcon(selected, size: 20),
            const SizedBox(width: 8),
            Text(
              selected == null ? '전체' : _notificationLabel(selected!),
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: tc.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final _NotificationItem item;
  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Image.asset(_notificationIcon(item.kind), fit: BoxFit.contain),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _notificationLabel(item.kind),
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (item.onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: tc.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final NotificationKind? filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final message = filter == null
        ? '아직 지난 알림이 없어요'
        : '${_notificationLabel(filter!)} 알림이 없어요';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: WeRoboTypography.body.copyWith(color: tc.textTertiary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
