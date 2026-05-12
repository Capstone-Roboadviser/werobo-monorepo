import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Chrome for the AI 요약 modal bottom sheet: rounded top corners, drag
/// handle, X close button, and a slot for the scrollable body.
///
/// No business logic — the parent widget owns state and supplies the body.
class DigestSheetShell extends StatelessWidget {
  final Widget child;

  const DigestSheetShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Material(
      color: tc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      key: const Key('digest_sheet_drag_handle'),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tc.border.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, right: 6),
                    child: IconButton(
                      key: const Key('digest_sheet_close_button'),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 24,
                        color: tc.textSecondary,
                      ),
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}
