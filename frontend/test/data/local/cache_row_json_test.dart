import 'package:filo/data/local/cache_row_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renames keys without changing unrelated values or the input', () {
    final nested = {'nested_key': 'keep'};
    final list = ['keep'];
    final row = <String, dynamic>{
      'display_name': 'Name',
      'points': 25,
      'accept_late': false,
      'unknown_field': nested,
      'items': list,
      'alreadyCamelCase': 'keep',
      'field_2': 'keep',
    };

    final result = cacheRowJson(row);

    expect(result, {
      'displayName': 'Name',
      'points': 25,
      'acceptLate': false,
      'unknownField': nested,
      'items': list,
      'alreadyCamelCase': 'keep',
      'field_2': 'keep',
    });
    expect(result['unknownField'], same(nested));
    expect(result['items'], same(list));
    expect(row['display_name'], 'Name');
    expect(row.containsKey('displayName'), false);
    expect(result, isNot(same(row)));
  });

  test('converts timestamps to epoch milliseconds with original precision', () {
    expect(
      cacheRowJson({
        'created_at': '1970-01-01T00:00:00.123456Z',
        'updated_at': '1970-01-01T08:00:01.987654+08:00',
        'due_at': '1970-01-01T00:00:02Z',
      }),
      {'createdAt': 123, 'updatedAt': 1987, 'dueAt': 2000},
    );
  });

  test('preserves null date fields under both existing policies', () {
    for (final fields in [
      <String>{},
      {'unsubmit_until'},
    ]) {
      expect(
        cacheRowJson({
          'deleted_at': null,
          'unsubmit_until': null,
        }, extraDateFields: fields),
        {'deletedAt': null, 'unsubmitUntil': null},
      );
    }
  });

  test('only submission and sync policy converts unsubmit_until', () {
    const stamp = '1970-01-01T00:00:01Z';
    final row = {'unsubmit_until': stamp, 'other_date': stamp};
    expect(cacheRowJson(row), {'unsubmitUntil': stamp, 'otherDate': stamp});
    expect(cacheRowJson(row, extraDateFields: const {'unsubmit_until'}), {
      'unsubmitUntil': 1000,
      'otherDate': stamp,
    });
  });

  test('invalid timestamps keep failing instead of silently becoming null', () {
    expect(
      () => cacheRowJson({'created_at': 'invalid'}),
      throwsFormatException,
    );
    expect(
      () => cacheRowJson(
        {'unsubmit_until': 'invalid'},
        extraDateFields: const {'unsubmit_until'},
      ),
      throwsFormatException,
    );
    expect(cacheRowJson({'unsubmit_until': 'invalid'}), {
      'unsubmitUntil': 'invalid',
    });
  });

  test('non-string dates retain the original type failure', () {
    expect(() => cacheRowJson({'created_at': 123}), throwsA(isA<TypeError>()));
  });
}
