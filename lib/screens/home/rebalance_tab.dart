import 'package:flutter/material.dart';
import '../../app/theme.dart';

class RebalanceTab extends StatelessWidget {
  const RebalanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text('리밸런싱', style: WeRoboTypography.heading2),
            const SizedBox(height: 8),
            Text('포트폴리오를 최적 상태로 유지합니다',
                style: WeRoboTypography.bodySmall),
            const SizedBox(height: 24),

            // Next rebalance card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: WeRoboColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('다음 리밸런싱',
                      style: WeRoboTypography.caption.copyWith(
                          color: WeRoboColors.primary)),
                  const SizedBox(height: 4),
                  Text('2026-07-01',
                      style: WeRoboTypography.heading3.copyWith(
                          color: WeRoboColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('87일 남음',
                      style: WeRoboTypography.bodySmall.copyWith(
                          color: WeRoboColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('리밸런싱 기록', style: WeRoboTypography.heading3),
            const SizedBox(height: 12),

            _RebalanceRecord(
                date: '2026-04-01', status: '완료', delta: '+1.2%'),
            _RebalanceRecord(
                date: '2026-01-02', status: '완료', delta: '+0.8%'),
            _RebalanceRecord(
                date: '2025-10-01', status: '완료', delta: '+2.1%'),
          ],
        ),
      ),
    );
  }
}

class _RebalanceRecord extends StatelessWidget {
  final String date;
  final String status;
  final String delta;

  const _RebalanceRecord({
    required this.date,
    required this.status,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WeRoboColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: WeRoboColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_rounded,
                size: 20, color: WeRoboColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date,
                    style: WeRoboTypography.bodySmall.copyWith(
                        color: WeRoboColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontFamily: WeRoboFonts.english)),
                Text(status, style: WeRoboTypography.caption),
              ],
            ),
          ),
          Text(delta,
              style: WeRoboTypography.bodySmall.copyWith(
                  color: WeRoboColors.accent,
                  fontWeight: FontWeight.w600,
                  fontFamily: WeRoboFonts.english)),
        ],
      ),
    );
  }
}
