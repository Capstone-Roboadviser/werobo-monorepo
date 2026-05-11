import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';

void main() {
  test('MobileAssetClassNewsResponse parses JSON', () {
    final json = {
      'title': 'Growth stocks rally on earnings beat',
      'link': 'https://finance.yahoo.com/news/vug-rally',
      'published': '2026-05-12T14:00:00+00:00',
      'source': 'Yahoo Finance',
    };
    final parsed = MobileAssetClassNewsResponse.fromJson(json);
    expect(parsed.title, 'Growth stocks rally on earnings beat');
    expect(parsed.link, 'https://finance.yahoo.com/news/vug-rally');
    expect(parsed.published.year, 2026);
    expect(parsed.source, 'Yahoo Finance');
  });
}
