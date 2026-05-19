import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PortfolioState.hasSeenStory', () {
    late PortfolioState state;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      state = PortfolioState();
    });

    tearDown(() {
      state.dispose();
    });

    test('defaults to false', () {
      expect(state.hasSeenStory, false);
    });

    test('markStorySeen flips it true and notifies', () async {
      var notified = false;
      state.addListener(() => notified = true);
      await state.markStorySeen();
      expect(state.hasSeenStory, true);
      expect(notified, true);
    });

    test('markStorySeen persists to SharedPreferences', () async {
      await state.markStorySeen();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('werobo.story_seen'), true);
    });

    test('restorePersistedState rehydrates from prefs', () async {
      SharedPreferences.setMockInitialValues({'werobo.story_seen': true});
      final fresh = PortfolioState();
      addTearDown(fresh.dispose);
      await fresh.restorePersistedState();
      expect(fresh.hasSeenStory, true);
    });

    test('survives clearAllPersistedState (device-level preference)', () async {
      await state.markStorySeen();
      expect(state.hasSeenStory, true);
      await state.clearAllPersistedState(notify: false);
      // hasSeenStory is intentionally device-level: the onboarding story
      // plays once per device, not per account. Logging out should not
      // make it replay on the same device.
      expect(state.hasSeenStory, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('werobo.story_seen'), true);
    });
  });
}
