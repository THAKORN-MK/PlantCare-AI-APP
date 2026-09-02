import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/constants/api_constants.dart';
import 'package:plantcare_ai/services/api_service.dart';

void main() {
  test('uses the OpenRouter free models router by default', () {
    expect(openRouterFreeModel, 'openrouter/free');
    expect(ApiService.defaultModel, openRouterFreeModel);
  });

  test('detects common image MIME types from the selected file', () {
    expect(ApiService.mimeTypeForPath('leaf.png'), 'image/png');
    expect(ApiService.mimeTypeForPath('leaf.webp'), 'image/webp');
    expect(ApiService.mimeTypeForPath('leaf.jpg'), 'image/jpeg');
  });

  test('replaces an English reasoning response with Thai advice', () {
    final advice = ApiService.formatAdviceResponse(
      diseaseName: 'โรคราน้ำค้าง (Downy mildew)',
      response: '''
Here's a thinking process:
1. Analyze User Request
2. Provide 3 tips in Thai language
3. Constraints
''',
    );

    final lines = advice.split('\n');
    expect(lines, hasLength(3));
    expect(advice, isNot(contains('thinking process')));
    expect(advice, contains('โรคราน้ำค้าง'));
    expect(lines, everyElement(matches(RegExp(r'^- '))));
  });
}
