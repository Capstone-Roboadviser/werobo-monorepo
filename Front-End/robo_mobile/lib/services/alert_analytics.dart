import 'dart:developer' as dev;

import '../app/portfolio_state.dart';

/// Records alert-event payloads so σ thresholds can be tuned post-launch
/// (DESIGN.md §Alert / Digest System → Post-launch tuning analytics).
///
/// In this MVP, only `recordPreferenceChange` is wired (from settings).
/// `recordShown`/`recordInteraction` will be wired when the deferred home
/// dashboard rework lands the contribution tooltip. Service exists now for
/// forward compatibility.
class AlertAnalytics {
  AlertAnalytics._();
  static final AlertAnalytics instance = AlertAnalytics._();

  /// Called when an alert is shown to the user.
  Future<void> recordShown({
    required double sigma,
    required AlertFrequency userPreference,
  }) async {
    // Backend TODO: POST /api/v1/analytics/alert-shown
    dev.log(
      '[alert] shown sigma=$sigma pref=${userPreference.name}',
      name: 'AlertAnalytics',
    );
  }

  /// Called when the user opens, dismisses, or acts on an alert.
  Future<void> recordInteraction({
    required double sigma,
    required AlertInteraction kind,
  }) async {
    // Backend TODO: POST /api/v1/analytics/alert-interaction
    dev.log(
      '[alert] ${kind.name} sigma=$sigma',
      name: 'AlertAnalytics',
    );
  }

  /// Called when the user changes alert frequency in settings.
  Future<void> recordPreferenceChange(AlertFrequency f) async {
    // Backend TODO: POST /api/v1/analytics/alert-preference
    dev.log(
      '[alert] preference=${f.name}',
      name: 'AlertAnalytics',
    );
  }
}

enum AlertInteraction { opened, dismissed, actedOn }
