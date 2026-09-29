import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/scroll_restoration.dart';
import 'package:guvenlik_app/core/services/timeline_resume_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'process-death resume is single-consume and retains the anchor',
    () async {
      expect(await TimelineResumeService.begin(), isNull);
      const anchor = ScrollAnchor(
        offset: 812,
        topItemId: 'event-42',
        topItemIndex: 4,
      );
      await TimelineResumeService.save(anchor);

      expect(await TimelineResumeService.consumePending(), isTrue);
      expect(await TimelineResumeService.consumePending(), isFalse);
      expect(await TimelineResumeService.begin(), anchor);
    },
  );

  test('normal route exit clears both resume intent and anchor', () async {
    await TimelineResumeService.begin();
    await TimelineResumeService.save(
      const ScrollAnchor(offset: 90, topItemId: 'old', topItemIndex: 1),
    );
    await TimelineResumeService.clear();

    expect(await TimelineResumeService.consumePending(), isFalse);
    expect(await TimelineResumeService.begin(), isNull);
  });
}
