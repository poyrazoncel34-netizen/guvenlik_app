import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/rehearsal_record_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a fresh install reports no rehearsal rather than a fake date', () async {
    expect(await RehearsalRecordService.lastRehearsalAt(), isNull);
  });

  test('a completed rehearsal is readable back at second precision', () async {
    final moment = DateTime(2026, 3, 12, 21, 30);
    await RehearsalRecordService.recordCompletedRehearsal(at: moment);

    expect(
      await RehearsalRecordService.lastRehearsalAt(),
      equals(moment),
      reason: 'the home card shows this date as the user-visible record',
    );
  });

  test('a later rehearsal replaces the earlier one', () async {
    await RehearsalRecordService.recordCompletedRehearsal(
      at: DateTime(2026, 1, 1),
    );
    await RehearsalRecordService.recordCompletedRehearsal(
      at: DateTime(2026, 6, 1),
    );

    expect(
      await RehearsalRecordService.lastRehearsalAt(),
      equals(DateTime(2026, 6, 1)),
    );
  });

  test('clearing returns the user to the honest "never rehearsed" state', () async {
    await RehearsalRecordService.recordCompletedRehearsal();
    await RehearsalRecordService.clear();

    expect(await RehearsalRecordService.lastRehearsalAt(), isNull);
  });

  test('the record survives unrelated preference writes', () async {
    final moment = DateTime(2026, 3, 12);
    await RehearsalRecordService.recordCompletedRehearsal(at: moment);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('some_unrelated_flag', true);

    expect(await RehearsalRecordService.lastRehearsalAt(), equals(moment));
  });
}
