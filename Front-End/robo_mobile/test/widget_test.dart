import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/main.dart';

void main() {
  testWidgets('App launches with splash', (WidgetTester tester) async {
    await tester.pumpWidget(
      WeRoboApp(portfolioState: PortfolioState()),
    );
    expect(find.text('WeRobo'), findsOneWidget);
  });
}
