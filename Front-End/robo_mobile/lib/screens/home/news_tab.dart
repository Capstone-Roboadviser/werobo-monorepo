import 'package:flutter/material.dart';

import '../../app/pressable.dart';
import '../../app/theme.dart';

class NewsTab extends StatelessWidget {
  const NewsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return SafeArea(
      key: const Key('news_tab'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            '뉴스',
            style: WeRoboTypography.heading2.copyWith(
              color: tc.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _NewsHeroCard(tc: tc),
          const SizedBox(height: 18),
          Text(
            '관심 자산',
            style: WeRoboTypography.heading3.copyWith(
              color: tc.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const _NewsCard(
            icon: Icons.trending_up_rounded,
            title: '미국 성장주 흐름 점검',
            body: '최근 변동성이 커진 성장 섹터를 포트폴리오 비중 관점에서 살펴봅니다.',
            tag: '성장주',
          ),
          const _NewsCard(
            icon: Icons.account_balance_rounded,
            title: '채권과 현금성 자산 체크',
            body: '금리 민감도가 큰 구간에서 방어 자산이 어떤 역할을 하는지 정리합니다.',
            tag: '방어자산',
          ),
          const _NewsCard(
            icon: Icons.public_rounded,
            title: '글로벌 지수 주요 이슈',
            body: '시장 전반의 움직임을 포트폴리오 리스크 신호와 함께 확인합니다.',
            tag: '시장',
          ),
        ],
      ),
    );
  }
}

class _NewsHeroCard extends StatelessWidget {
  final WeRoboThemeColors tc;

  const _NewsHeroCard({required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: WeRoboColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.article_rounded,
              color: WeRoboColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '포트폴리오 뉴스 브리핑',
                  style: WeRoboTypography.body.copyWith(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '내 자산 배분과 연결되는 시장 소식을 모아봅니다.',
                  style: WeRoboTypography.caption.copyWith(
                    color: tc.textSecondary,
                    height: 1.35,
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

class _NewsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String tag;

  const _NewsCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tc.border, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: WeRoboColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag,
                    style: WeRoboTypography.caption.copyWith(
                      color: WeRoboColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
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
      ),
    );
  }
}
