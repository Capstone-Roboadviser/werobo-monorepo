import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/screens/onboarding/widgets/story_canvas.dart';

void main() {
  group('storyGaugeOpacity', () {
    test('0 before fade-in window', () {
      expect(storyGaugeOpacity(0), 0);
      expect(storyGaugeOpacity(0.7), 0);
    });

    test('eases 0 → 1 across [0.7, 1.0]', () {
      expect(storyGaugeOpacity(0.85), closeTo(0.5, 1e-9));
      expect(storyGaugeOpacity(1.0), closeTo(1.0, 1e-9));
    });

    test('full opacity across pages 2-3', () {
      expect(storyGaugeOpacity(1.0), 1.0);
      expect(storyGaugeOpacity(2.0), 1.0);
    });

    test('eases 1 → 0 across [2.0, 2.5]', () {
      expect(storyGaugeOpacity(2.25), closeTo(0.5, 1e-9));
      expect(storyGaugeOpacity(2.5), closeTo(0, 1e-9));
    });

    test('0 after fade-out', () {
      expect(storyGaugeOpacity(3.0), 0);
      expect(storyGaugeOpacity(6.0), 0);
    });
  });

  group('storyGaugeValue', () {
    test('40 on page 2 (progress 1.0)', () {
      expect(storyGaugeValue(1.0), 40);
      expect(storyGaugeValue(0.5), 40);
    });

    test('eases 40 → 30 across [1.0, 2.0]', () {
      expect(storyGaugeValue(1.5), closeTo(35, 1e-9));
      expect(storyGaugeValue(2.0), 30);
    });

    test('30 after page 3', () {
      expect(storyGaugeValue(3.0), 30);
    });
  });

  group('storyCtaOpacity', () {
    test('0 before fade-in', () {
      expect(storyCtaOpacity(5.6), 0);
    });

    test('fades in across [5.7, 6.0]', () {
      expect(storyCtaOpacity(5.7), 0);
      expect(storyCtaOpacity(5.85), closeTo(0.5, 1e-9));
      expect(storyCtaOpacity(6.0), 1.0);
    });

    test('full opacity at and past page 7', () {
      expect(storyCtaOpacity(6.0), 1.0);
      expect(storyCtaOpacity(7.0), 1.0);
    });
  });

  group('storyCurveDrawProgress', () {
    test('0 before page 5 fade-in', () {
      expect(storyCurveDrawProgress(3.4), 0);
    });

    test('draws 0 → 1 across [3.5, 4.0]', () {
      expect(storyCurveDrawProgress(3.5), 0);
      expect(storyCurveDrawProgress(3.75), closeTo(0.5, 1e-9));
      expect(storyCurveDrawProgress(4.0), 1.0);
    });

    test('1 across [4.0, 4.5]', () {
      expect(storyCurveDrawProgress(4.25), 1.0);
    });

    test('fades back to 0 across [4.5, 5.0]', () {
      expect(storyCurveDrawProgress(4.75), closeTo(0.5, 1e-9));
      expect(storyCurveDrawProgress(5.0), 0);
    });
  });

  group('storyDotOpacity', () {
    test('all 4 dots visible at page 1 (progress 0)', () {
      for (var i = 0; i < 4; i++) {
        expect(storyDotOpacity(i, 0), 1.0);
      }
    });

    test('red dot (index 0) stays opaque through morph window then snaps off at 1.0', () {
      expect(storyDotOpacity(0, 0.7), 1.0);
      expect(storyDotOpacity(0, 0.85), 1.0);
      expect(storyDotOpacity(0, 0.999), 1.0);
      expect(storyDotOpacity(0, 1.0), 0);
    });

    test('dots 1-3 fade out across [0.3, 0.8]', () {
      expect(storyDotOpacity(1, 0.3), 1.0);
      expect(storyDotOpacity(1, 0.55), closeTo(0.5, 1e-9));
      expect(storyDotOpacity(1, 0.8), 0);
      expect(storyDotOpacity(3, 0.8), 0);
    });

    test('all 4 dots reappear at page 5 (progress 4)', () {
      for (var i = 0; i < 4; i++) {
        expect(storyDotOpacity(i, 4.0), 1.0);
      }
    });

    test('dots fade out across [4.7, 5.0]', () {
      expect(storyDotOpacity(0, 4.85), closeTo(0.5, 1e-9));
      expect(storyDotOpacity(0, 5.0), 0);
    });
  });

  group('storyChipOpacity', () {
    test('0 before stagger window starts', () {
      expect(storyChipOpacity(0, 4.4), 0);
      expect(storyChipOpacity(3, 4.4), 0);
    });

    test('staggered fade-in: chip 0 leads, chip 3 has not yet started at 4.6', () {
      expect(storyChipOpacity(0, 4.6), closeTo(0.5, 1e-9));
      expect(storyChipOpacity(3, 4.6), 0);
    });

    test('all chips fully visible at page 6 (progress 5.0)', () {
      for (var i = 0; i < 4; i++) {
        expect(storyChipOpacity(i, 5.0), 1.0);
      }
    });

    test('fades out across [5.5, 6.0]', () {
      expect(storyChipOpacity(0, 5.75), closeTo(0.5, 1e-9));
      expect(storyChipOpacity(0, 6.0), 0);
    });
  });

  group('storyWobbleScale', () {
    test('full amplitude across the intro window [0, 0.3]', () {
      expect(storyWobbleScale(0), 1.0);
      expect(storyWobbleScale(0.3), 1.0);
    });

    test('settles 1 → 0 across [0.3, 0.7] before the red-dot morph begins', () {
      expect(storyWobbleScale(0.5), closeTo(0.5, 1e-9));
      expect(storyWobbleScale(0.7), 0);
    });

    test('stays at 0 past 0.7 so morph + later pages are still', () {
      expect(storyWobbleScale(1.0), 0);
      expect(storyWobbleScale(4.0), 0);
    });
  });
}
