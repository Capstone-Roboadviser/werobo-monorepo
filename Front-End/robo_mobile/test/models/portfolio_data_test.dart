import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/portfolio_data.dart';

void main() {
  group('InvestmentType.fromDotT', () {
    test('returns safe for dotT < 0.33', () {
      expect(InvestmentType.fromDotT(0.0), InvestmentType.safe);
      expect(InvestmentType.fromDotT(0.1), InvestmentType.safe);
      expect(InvestmentType.fromDotT(0.32), InvestmentType.safe);
    });

    test('returns balanced for 0.33 <= dotT < 0.66', () {
      expect(InvestmentType.fromDotT(0.33), InvestmentType.balanced);
      expect(InvestmentType.fromDotT(0.5), InvestmentType.balanced);
      expect(InvestmentType.fromDotT(0.65), InvestmentType.balanced);
    });

    test('returns growth for dotT >= 0.66', () {
      expect(InvestmentType.fromDotT(0.66), InvestmentType.growth);
      expect(InvestmentType.fromDotT(0.8), InvestmentType.growth);
      expect(InvestmentType.fromDotT(1.0), InvestmentType.growth);
    });

    test('handles edge boundaries precisely', () {
      // Just below 0.33
      expect(InvestmentType.fromDotT(0.329), InvestmentType.safe);
      // Exactly 0.33
      expect(InvestmentType.fromDotT(0.33), InvestmentType.balanced);
      // Just below 0.66
      expect(InvestmentType.fromDotT(0.659), InvestmentType.balanced);
      // Exactly 0.66
      expect(InvestmentType.fromDotT(0.66), InvestmentType.growth);
    });
  });

  group('PortfolioData.categoriesFor', () {
    test('safe percentages sum to 100', () {
      final cats = PortfolioData.categoriesFor(InvestmentType.safe);
      final sum = cats.fold<double>(0, (s, c) => s + c.percentage);
      expect(sum, 100.0);
    });

    test('balanced percentages sum to 100', () {
      final cats = PortfolioData.categoriesFor(InvestmentType.balanced);
      final sum = cats.fold<double>(0, (s, c) => s + c.percentage);
      expect(sum, 100.0);
    });

    test('growth percentages sum to 100', () {
      final cats = PortfolioData.categoriesFor(InvestmentType.growth);
      final sum = cats.fold<double>(0, (s, c) => s + c.percentage);
      expect(sum, 100.0);
    });

    test('each type has 7 categories', () {
      for (final type in InvestmentType.values) {
        expect(
          PortfolioData.categoriesFor(type).length,
          7,
          reason: '${type.label} should have 7 categories',
        );
      }
    });

    test('all percentages are positive', () {
      for (final type in InvestmentType.values) {
        for (final cat in PortfolioData.categoriesFor(type)) {
          expect(cat.percentage, greaterThan(0),
              reason: '${type.label} ${cat.name} should be > 0');
        }
      }
    });
  });

  group('PortfolioData.detailsFor', () {
    test('detail categories match summary categories', () {
      for (final type in InvestmentType.values) {
        final cats = PortfolioData.categoriesFor(type);
        final details = PortfolioData.detailsFor(type);
        expect(details.length, cats.length,
            reason: '${type.label} detail count should match');

        for (int i = 0; i < cats.length; i++) {
          expect(details[i].category.name, cats[i].name,
              reason: '${type.label} detail[$i] name mismatch');
          expect(details[i].category.percentage, cats[i].percentage,
              reason: '${type.label} detail[$i] percentage mismatch');
        }
      }
    });

    test('each category has at least one ticker', () {
      for (final type in InvestmentType.values) {
        for (final detail in PortfolioData.detailsFor(type)) {
          expect(detail.tickers.isNotEmpty, true,
              reason:
                  '${type.label} ${detail.category.name} has no tickers');
        }
      }
    });

    test('ticker percentages within each category are positive', () {
      for (final type in InvestmentType.values) {
        for (final detail in PortfolioData.detailsFor(type)) {
          for (final ticker in detail.tickers) {
            expect(ticker.percentage, greaterThan(0),
                reason:
                    '${type.label} ${detail.category.name} ${ticker.symbol}');
          }
        }
      }
    });
  });

  group('PortfolioData.statsFor', () {
    test('returns risk and return for each type', () {
      for (final type in InvestmentType.values) {
        final (risk, returnRate) = PortfolioData.statsFor(type);
        expect(risk.endsWith('%'), true);
        expect(returnRate.endsWith('%'), true);
      }
    });

    test('growth has higher risk than safe', () {
      final (safeRisk, _) = PortfolioData.statsFor(InvestmentType.safe);
      final (growthRisk, _) = PortfolioData.statsFor(InvestmentType.growth);
      final sr = double.parse(safeRisk.replaceAll('%', ''));
      final gr = double.parse(growthRisk.replaceAll('%', ''));
      expect(gr, greaterThan(sr));
    });

    test('growth has higher return than safe', () {
      final (_, safeReturn) = PortfolioData.statsFor(InvestmentType.safe);
      final (_, growthReturn) =
          PortfolioData.statsFor(InvestmentType.growth);
      final sr = double.parse(safeReturn.replaceAll('%', ''));
      final gr = double.parse(growthReturn.replaceAll('%', ''));
      expect(gr, greaterThan(sr));
    });
  });

  group('InvestmentType enum', () {
    test('all types have non-empty labels', () {
      for (final type in InvestmentType.values) {
        expect(type.label.isNotEmpty, true);
        expect(type.description.isNotEmpty, true);
      }
    });

    test('there are 5 types (3 base + 2 variants)', () {
      expect(InvestmentType.values.length, 5);
    });
  });
}
