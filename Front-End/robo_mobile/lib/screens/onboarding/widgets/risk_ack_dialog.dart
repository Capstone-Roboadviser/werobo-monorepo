import 'package:flutter/material.dart';
import '../../../app/theme.dart';

Future<bool?> showRiskAckDialog({
  required BuildContext context,
  required double marketVolPct,
  required double userVolPct,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RiskAckDialog(
      marketVolPct: marketVolPct,
      userVolPct: userVolPct,
    ),
  );
}

class _RiskAckDialog extends StatefulWidget {
  final double marketVolPct;
  final double userVolPct;

  const _RiskAckDialog({
    required this.marketVolPct,
    required this.userVolPct,
  });

  @override
  State<_RiskAckDialog> createState() => _RiskAckDialogState();
}

class _RiskAckDialogState extends State<_RiskAckDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final excessPp = widget.userVolPct - widget.marketVolPct;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: WeRoboColors.lossBlue,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            '투자 위험 고지',
            style: WeRoboTypography.heading3,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DataTable(
            marketVolPct: widget.marketVolPct,
            userVolPct: widget.userVolPct,
            excessPp: excessPp,
          ),
          const SizedBox(height: 16),
          Text(
            '선택하신 포트폴리오는 시장 평균보다 위험도가 크게 높습니다.\n'
            '단기 손실 가능성을 충분히 인지하셨다면 계속 진행하실 수 있습니다.',
            style: WeRoboTypography.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _acknowledged,
                activeColor: WeRoboColors.primaryDark,
                onChanged: (v) => setState(() => _acknowledged = v ?? false),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  '위험을 충분히 인지하였습니다',
                  style: WeRoboTypography.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('비중 조정하기'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WeRoboColors.primaryDark,
                  foregroundColor: WeRoboColors.white,
                ),
                onPressed: _acknowledged
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: const Text('확인 후 유지'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DataTable extends StatelessWidget {
  final double marketVolPct;
  final double userVolPct;
  final double excessPp;

  const _DataTable({
    required this.marketVolPct,
    required this.userVolPct,
    required this.excessPp,
  });

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.6),
        1: FlexColumnWidth(1),
      },
      children: [
        _row(
          label: '시장 평균 비중',
          value: '${marketVolPct.toStringAsFixed(1)}%',
          valueColor: WeRoboColors.textSecondary,
          bold: false,
        ),
        _row(
          label: '내 포트폴리오 비중',
          value: '${userVolPct.toStringAsFixed(1)}%',
          valueColor: WeRoboColors.lossBlue,
          bold: false,
        ),
        _row(
          label: '초과',
          value: '+${excessPp.toStringAsFixed(1)}pp',
          valueColor: WeRoboColors.lossBlue,
          bold: true,
        ),
      ],
    );
  }

  TableRow _row({
    required String label,
    required String value,
    required Color valueColor,
    required bool bold,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: WeRoboTypography.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            value,
            style: WeRoboTypography.bodySmall.copyWith(
              color: valueColor,
              fontWeight: bold ? FontWeight.w700 : null,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
