import 'dart:convert';
import 'offline_store.dart';

class RestoredFormDraft {
  final Map<String, dynamic> data;
  final bool alreadyQueued;
  const RestoredFormDraft(this.data, {this.alreadyQueued = false});
}

/// Serializes writes and persists submission identity BEFORE enqueue/network.
/// This closes the reload window between a durable outbox write and clearing UI.
class OfflineFormDraft {
  final Future<OfflineStore> store;
  final OfflineScope scope;
  final String slot;
  final String kind;
  Future<void> _writes = Future.value();
  Map<String, dynamic>? _submission;
  String? _lastData;
  int _revision = 0;
  OfflineFormDraft({
    required this.store,
    required this.scope,
    required this.slot,
    required this.kind,
  });

  Future<RestoredFormDraft?> restore() async {
    final revision = _revision;
    final db = await store;
    final row = await db.draft(scope, slot);
    if (row == null || revision != _revision) return null;
    final payload = Map<String, dynamic>.from(row['payload'] as Map);
    if (row['kind'] != kind ||
        payload['version'] != 1 ||
        payload['data'] is! Map) {
      throw const FormatException('Bản nháp không đúng định dạng.');
    }
    final submission = payload['submission'] is Map
        ? Map<String, dynamic>.from(payload['submission'] as Map)
        : null;
    final operationId = submission?['operationId'];
    if (operationId is String) {
      final operation = await db.operation(scope, operationId);
      if (revision != _revision) return null;
      if (operation != null &&
          operation.kind == kind &&
          const [
            'pending',
            'sending',
            'confirmed',
            'reviewRequired',
          ].contains(operation.status)) {
        return const RestoredFormDraft({}, alreadyQueued: true);
      }
    }
    final data = Map<String, dynamic>.from(payload['data'] as Map);
    _submission = submission;
    _lastData = jsonEncode(data);
    return RestoredFormDraft(data);
  }

  Future<void> save(Map<String, dynamic> data, {bool force = false}) {
    final encoded = jsonEncode(data);
    if (!force && _lastData == encoded) return _writes;
    _lastData = encoded;
    _revision++;
    final snapshot = {
      'version': 1,
      'data': jsonDecode(encoded),
      if (_submission != null)
        'submission': Map<String, dynamic>.from(_submission!),
    };
    // A failed save is visible to its caller, but must not poison later edits.
    final write = _writes.catchError((Object _) {}).then((_) async {
      await (await store).saveDraft(scope, slot, kind, snapshot);
    });
    _writes = write;
    return write;
  }

  Future<String> prepareSubmission(
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
  ) async {
    final fingerprint = jsonEncode(payload);
    if (_submission?['fingerprint'] != fingerprint) {
      _submission = {
        'fingerprint': fingerprint,
        'operationId': newOperationId(),
      };
    }
    final operationId = _submission!['operationId'] as String;
    await save(data, force: true);
    return operationId;
  }

  Future<void> flush() => _writes;
  Future<void> clear() async {
    _revision++;
    _submission = null;
    _lastData = null;
    final write = _writes.catchError((Object _) {}).then((_) async {
      await (await store).deleteDraft(scope, slot);
    });
    _writes = write;
    await write;
  }
}
