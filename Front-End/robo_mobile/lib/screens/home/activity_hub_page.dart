import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import 'insight_detail_page.dart';
import 'notification_settings_page.dart';

/// Categories that can be filtered on the notification history page.
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

DateTime? _parseIsoDate(String iso) {
  if (iso.length < 10) return null;
  final year = int.tryParse(iso.substring(0, 4));
  final month = int.tryParse(iso.substring(5, 7));
  final day = int.tryParse(iso.substring(8, 10));
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

/// Friendly relative timestamp matching the Toss style.
String _relativeTimestamp(DateTime when) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final whenDate = DateTime(when.year, when.month, when.day);
  final diffDays = today.difference(whenDate).inDays;

  if (diffDays == 0) {
    // Same calendar day — show "N시간 전" when the timestamp is itself
    // recent, otherwise just "오늘".
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '오늘';
  }
  if (diffDays == 1) return '어제';
  if (diffDays < 7) return '$diffDays일 전';
  return '${when.month}월 ${when.day}일';
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
  final DateTime timestamp;
  final VoidCallback onTap;
  const _NotificationItem({
    required this.kind,
    required this.title,
    required this.timestamp,
    required this.onTap,
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
            // Header: back chevron + 알림 설정 link.
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
                        const NotificationSettingsPage(),
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
            // Big filter label with chevron.
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
    final now = DateTime.now();

    bool show(NotificationKind k) => filter == null || filter == k;

    void comingSoon(NotificationKind k) => Navigator.of(context).push(
          WeRoboMotion.fadeRoute<void>(
            _ComingSoonPage(title: _notificationLabel(k)),
          ),
        );

    if (show(NotificationKind.monthlySummary)) {
      final monthly = state.trailingMonthReturn;
      if (monthly != null) {
        final sign = monthly >= 0 ? '+' : '−';
        final pct = (monthly.abs() * 100).toStringAsFixed(1);
        items.add(_NotificationItem(
          kind: NotificationKind.monthlySummary,
          title: '지난 30일 포트폴리오 $sign$pct%',
          timestamp: now,
          onTap: () => comingSoon(NotificationKind.monthlySummary),
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
          timestamp: now,
          onTap: () => comingSoon(NotificationKind.contribution),
        ));
      }
    }

    if (show(NotificationKind.algorithmSignal)) {
      for (final insight in state.insights) {
        final rebalDate = _parseIsoDate(insight.rebalanceDate) ?? now;
        items.add(_NotificationItem(
          kind: NotificationKind.algorithmSignal,
          title: _triggerSentence(insight.trigger),
          timestamp: rebalDate,
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
          timestamp: now,
          onTap: () => comingSoon(NotificationKind.volatilityAlert),
        ));
      }
    }

    // Asset news isn't persisted in state — only fetched by the dropdown.
    return items;
  }
}

class _FilterLabel extends StatelessWidget {
  final NotificationKind? selected;
  final ValueChanged<NotificationKind?> onPick;
  const _FilterLabel({required this.selected, required this.onPick});

  // PopupMenuButton.onSelected does NOT fire when the value is null — Flutter
  // intentionally skips the callback in that case. Use String sentinels
  // ('all' for 전체, enum names for specific kinds) so every choice fires.
  static const _allValue = '__all__';

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return PopupMenuButton<String>(
      tooltip: '알림 종류 선택',
      offset: const Offset(0, 36),
      color: tc.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      onSelected: (value) {
        if (value == _allValue) {
          onPick(null);
        } else {
          onPick(NotificationKind.values.firstWhere((k) => k.name == value));
        }
      },
      itemBuilder: (ctx) => <PopupMenuEntry<String>>[
        _menuItem(ctx, value: _allValue, kind: null, label: '전체'),
        ...NotificationKind.values.map(
          (k) => _menuItem(ctx, value: k.name, kind: k, label: _notificationLabel(k)),
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

  PopupMenuEntry<String> _menuItem(
    BuildContext ctx, {
    required String value,
    required NotificationKind? kind,
    required String label,
  }) {
    final tc = WeRoboThemeColors.of(ctx);
    final isSelected = kind == selected;
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          _filterIcon(kind, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textPrimary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

/// Row used on the notification history page and the today dropdown.
/// Toss-style: rounded-square tinted icon container on the left,
/// category caption + title in the middle, timestamp on the right.
class NotificationListRow extends StatelessWidget {
  final NotificationKind kind;
  final String title;
  final DateTime? timestamp;
  final VoidCallback? onTap;

  const NotificationListRow({
    super.key,
    required this.kind,
    required this.title,
    this.timestamp,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tc.card,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(7),
              child: Image.asset(_notificationIcon(kind), fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _notificationLabel(kind),
                          style: WeRoboTypography.bodySmall.copyWith(
                            color: tc.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (timestamp != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _relativeTimestamp(timestamp!),
                          style: WeRoboTypography.caption.copyWith(
                            color: tc.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
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

class _HistoryRow extends StatelessWidget {
  final _NotificationItem item;
  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return NotificationListRow(
      kind: item.kind,
      title: item.title,
      timestamp: item.timestamp,
      onTap: item.onTap,
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

class _ComingSoonPage extends StatelessWidget {
  final String title;
  const _ComingSoonPage({required this.title});

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
                    title,
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

