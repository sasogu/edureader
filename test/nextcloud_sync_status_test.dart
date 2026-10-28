import 'dart:io';

import 'package:edureader/features/reader/data/nextcloud_sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'records a failed sync and clears the warning after a success',
    () async {
      final store = NextcloudSyncStatusStore();
      final change = store.changes.first;
      await store.recordFailure(const SocketException('offline'));
      await change;

      final failed = await store.load();
      expect(failed.hasUnresolvedFailure, isTrue);
      expect(failed.issue, NextcloudSyncIssue.network);
      expect(failed.lastFailure, isNotNull);

      await store.recordSuccess();
      final recovered = await store.load();
      expect(recovered.hasUnresolvedFailure, isFalse);
      expect(recovered.lastSuccess, isNotNull);
    },
  );

  test('stores an error category without saving exception text', () async {
    final store = NextcloudSyncStatusStore();
    await store.recordFailure(StateError('HTTP 401 private server address'));

    final preferences = await SharedPreferences.getInstance();
    expect((await store.load()).issue, NextcloudSyncIssue.authentication);
    expect(
      preferences.getString('nextcloud_last_failure_kind'),
      'authentication',
    );
    expect(
      preferences.getKeys().any(
        (key) =>
            preferences
                .get(key)
                ?.toString()
                .contains('private server address') ??
            false,
      ),
      isFalse,
    );
  });

  test('clears old account status when the connection changes', () async {
    final store = NextcloudSyncStatusStore();
    await store.recordSuccess();
    await store.clear();
    final status = await store.load();
    expect(status.lastSuccess, isNull);
    expect(status.lastFailure, isNull);
  });
}
