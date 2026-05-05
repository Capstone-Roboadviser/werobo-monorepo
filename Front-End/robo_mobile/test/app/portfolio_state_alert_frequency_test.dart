import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to normal', () {
    final state = PortfolioState();
    expect(state.alertFrequency, AlertFrequency.normal);
  });

  test('setAlertFrequency persists across restore', () async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    await state.setAlertFrequency(AlertFrequency.important);
    expect(state.alertFrequency, AlertFrequency.important);

    final freshState = PortfolioState();
    await freshState.restorePersistedState();
    expect(freshState.alertFrequency, AlertFrequency.important);
  });

  test('sigma thresholds match spec', () {
    expect(AlertFrequency.often.sigmaThreshold, 1.5);
    expect(AlertFrequency.normal.sigmaThreshold, 2.0);
    expect(AlertFrequency.important.sigmaThreshold, 3.0);
  });
}
