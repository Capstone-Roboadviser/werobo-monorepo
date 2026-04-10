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
  debugPrint('[WeRobo.Page] enter $pageName${_suffix(details)}');
}

void logPageExit(String pageName, [Map<String, Object?> details = const {}]) {
  debugPrint('[WeRobo.Page] exit $pageName${_suffix(details)}');
}

void logAction(String action, [Map<String, Object?> details = const {}]) {
  debugPrint('[WeRobo.Action] $action${_suffix(details)}');
}

void logApi(String phase, String operation,
    [Map<String, Object?> details = const {}]) {
  debugPrint('[WeRobo.Api] $phase $operation${_suffix(details)}');
}
