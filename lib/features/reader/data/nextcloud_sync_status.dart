import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum NextcloudSyncIssue { network, authentication, server, data, unknown }

class NextcloudSyncStatus {
  const NextcloudSyncStatus({
    this.lastSuccess,
    this.lastFailure,
    this.issue,
    this.lastAttemptFailed = false,
  });

  final DateTime? lastSuccess;
  final DateTime? lastFailure;
  final NextcloudSyncIssue? issue;
  final bool lastAttemptFailed;

  bool get hasUnresolvedFailure => lastAttemptFailed && lastFailure != null;
}

/// Stores only a category and time for failures. Exception text can contain
/// private server addresses, so it is never persisted for the status display.
class NextcloudSyncStatusStore {
  static const _successKey = 'nextcloud_last_success_at';
  static const _failureKey = 'nextcloud_last_failure_at';
  static const _issueKey = 'nextcloud_last_failure_kind';
  static const _resultKey = 'nextcloud_last_attempt_failed';
  static final StreamController<void> _changes =
      StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<NextcloudSyncStatus> load() async {
    final preferences = await SharedPreferences.getInstance();
    final issueName = preferences.getString(_issueKey);
    return NextcloudSyncStatus(
      lastSuccess: DateTime.tryParse(preferences.getString(_successKey) ?? ''),
      lastFailure: DateTime.tryParse(preferences.getString(_failureKey) ?? ''),
      issue: NextcloudSyncIssue.values
          .where((value) => value.name == issueName)
          .firstOrNull,
      lastAttemptFailed: preferences.getBool(_resultKey) ?? false,
    );
  }

  Future<void> recordSuccess() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _successKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    await preferences.setBool(_resultKey, false);
    _changes.add(null);
  }

  Future<void> recordFailure(Object error) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _failureKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    await preferences.setString(_issueKey, _classify(error).name);
    await preferences.setBool(_resultKey, true);
    _changes.add(null);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in const [_successKey, _failureKey, _issueKey, _resultKey]) {
      await preferences.remove(key);
    }
    _changes.add(null);
  }

  NextcloudSyncIssue _classify(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException) {
      return NextcloudSyncIssue.network;
    }
    final description = error.toString();
    if (description.contains('HTTP 401') || description.contains('HTTP 403')) {
      return NextcloudSyncIssue.authentication;
    }
    if (description.contains('HTTP 5')) return NextcloudSyncIssue.server;
    if (error is FormatException) return NextcloudSyncIssue.data;
    return NextcloudSyncIssue.unknown;
  }
}
