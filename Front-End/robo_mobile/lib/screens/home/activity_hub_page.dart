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
            // Header: back arrow on left, 알림 설정 link on right.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Pressable(
                    onTap: () => Navigator.of(context).push(
                      WeRoboMotion.fadeRoute<void>(
                        const _NotificationSettingsPage(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Text(
                        '알림 설정',
                        style: WeRoboTypography.bodySmall.copyWith(
                          color: tc.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Filter label — big, left-aligned, with a chevron. Tapping
            // opens a popup menu anchored beneath it.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: _FilterLabel(
                selected: _filter,
                onPick: (picked) => setState(() => _filter = picked),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? _EmptyState(filter: _filter)
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
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

    // Asset news isn't persisted in state — only fetched by the dropdown
    // on open — so this page leaves the category empty.
    return items;
  }
}

class _FilterLabel extends StatelessWidget {
  final NotificationKind? selected;
  final ValueChanged<NotificationKind?> onPick;
  const _FilterLabel({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return PopupMenuButton<NotificationKind?>(
      tooltip: '알림 종류 선택',
      offset: const Offset(0, 36),
      color: tc.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      onSelected: onPick,
      itemBuilder: (ctx) => <PopupMenuEntry<NotificationKind?>>[
        _menuItem(ctx, value: null, label: '전체'),
        ...NotificationKind.values.map(
          (k) => _menuItem(ctx, value: k, label: _notificationLabel(k)),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selected == null ? '알림' : _notificationLabel(selected!),
            style: WeRoboTypography.heading2.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.expand_more_rounded,
            size: 24,
            color: tc.textSecondary,
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<NotificationKind?> _menuItem(
    BuildContext ctx, {
    required NotificationKind? value,
    required String label,
  }) {
    final tc = WeRoboThemeColors.of(ctx);
    return PopupMenuItem<NotificationKind?>(
      value: value,
      height: 44,
      child: Row(
        children: [
          _filterIcon(value, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textPrimary,
              fontWeight: value == selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _filterIcon(NotificationKind? kind, {double size = 20}) {
  if (kind == null) {
    return Icon(
      Icons.menu_rounded,
      size: size,
      color: WeRoboColors.primary,
    );
  }
  return SizedBox(
    width: size,
    height: size,
    child: Image.asset(_notificationIcon(kind), fit: BoxFit.contain),
  );
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              height: 36,
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
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
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
        ? '아직 받은 알림이 없어요'
        : '${_notificationLabel(filter!)} 알림이 없어요';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 56,
            color: tc.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotificationSettingsPage extends StatelessWidget {
  const _NotificationSettingsPage();

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
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
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '알림 설정',
                    style: WeRoboTypography.heading2.themed(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '준비중입니다',
                  style: WeRoboTypography.body.copyWith(
                    color: tc.textTertiary,
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
