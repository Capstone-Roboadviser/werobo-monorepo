import 'package:flutter/foundation.dart';

String _suffix(Map<String, Object?> details) {
  if (details.isEmpty) {
    return '';
  }
  final pairs = details.entries
      .where((entry) => entry.value != null)
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' ');
  return pairs.isEmpty ? '' : ' $pairs';
}

void logPageEnter(String pageName, [Map<String, Object?> details = const {}]) {
  debugPrint('[ALFIN.Page] enter $pageName${_suffix(details)}');
}

void logPageExit(String pageName, [Map<String, Object?> details = const {}]) {
  debugPrint('[ALFIN.Page] exit $pageName${_suffix(details)}');
}

void logAction(String action, [Map<String, Object?> details = const {}]) {
  debugPrint('[ALFIN.Action] $action${_suffix(details)}');
}

void logApi(String phase, String operation,
    [Map<String, Object?> details = const {}]) {
  debugPrint('[ALFIN.Api] $phase $operation${_suffix(details)}');
}
