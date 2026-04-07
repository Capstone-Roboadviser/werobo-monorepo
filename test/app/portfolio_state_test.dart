import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/models/portfolio_data.dart';

void main() {
  group('PortfolioState', () {
    late PortfolioState state;

    setUp(() {
      state = PortfolioState();
    });

    tearDown(() {
      state.dispose();
    });

    test('defaults to balanced', () {
      expect(state.type, InvestmentType.balanced);
    });

    test('setType updates the type', () {
      state.setType(InvestmentType.safe);
      expect(state.type, InvestmentType.safe);
    });

    test('setType notifies listeners', () {
      var notified = false;
      state.addListener(() => notified = true);
      state.setType(InvestmentType.growth);
      expect(notified, true);
    });

    test('setType does not notify when value unchanged', () {
      var notifyCount = 0;
      state.addListener(() => notifyCount++);
      state.setType(InvestmentType.balanced); // same as default
      expect(notifyCount, 0);
    });

    test('setFromDotT maps correctly', () {
      state.setFromDotT(0.1);
      expect(state.type, InvestmentType.safe);

      state.setFromDotT(0.5);
      expect(state.type, InvestmentType.balanced);

      state.setFromDotT(0.9);
      expect(state.type, InvestmentType.growth);
    });
  });
}
