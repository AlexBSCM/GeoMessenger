import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_messenger/models/message_model.dart';
import 'package:geo_messenger/services/database_service.dart';
import 'package:geo_messenger/services/message_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDb implements DatabaseService {
  final controller = StreamController<List<GeoMessage>>.broadcast();
  final deliveredIds = <String>[];
  final markDeliveredCalls = <String>[];
  final hiddenIds = <String, List<String>>{};
  bool failDeliveries = false;
  bool failHides = false;
  String? failWithCode;

  @override
  Stream<List<GeoMessage>> getIncomingMessages(String userId) =>
      controller.stream;

  @override
  Future<void> markDelivered(String messageId) async {
    markDeliveredCalls.add(messageId);
    if (failWithCode != null) {
      throw FirebaseException(
        plugin: 'firestore',
        code: failWithCode!,
        message: 'simulated',
      );
    }
    if (failDeliveries) throw Exception('offline');
    deliveredIds.add(messageId);
  }

  @override
  Future<void> hideForRecipient(String messageId, String userId) async {
    if (failHides) throw Exception('offline');
    hiddenIds.putIfAbsent(messageId, () => []).add(userId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

GeoMessage _msg(String id,
    {String status = 'pending', List<String> deletedBy = const []}) =>
    GeoMessage(
      id: id,
      senderId: 'sender',
      senderName: 'Sender',
      recipientIds: ['u1'],
      recipientName: 'Recipient',
      text: 'text-$id',
      latitude: 57.99,
      longitude: 56.26,
      status: status,
      deletedBy: deletedBy,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDb db;
  late MessageStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = _FakeDb();
    store = MessageStore.forTest(db);
    await store.init('u1');
  });

  tearDown(() {
    db.controller.close();
  });

  test('cloud pending message lands in pendingMessages', () async {
    db.controller.add([_msg('m1')]);
    await Future.delayed(Duration.zero);

    expect(store.pendingMessages.map((m) => m.id), ['m1']);
    expect(store.visibleMessages, isEmpty);
  });

  test('revealLocally works offline and queues the delivery', () async {
    db.controller.add([_msg('m1')]);
    await Future.delayed(Duration.zero);

    await store.revealLocally('m1');

    expect(store.visibleMessages.map((m) => m.id), ['m1']);
    expect(db.deliveredIds, isEmpty); // not synced yet

    // The queue survives a reload from cache.
    final reloaded = MessageStore.forTest(db);
    await reloaded.init('u1');
    expect(reloaded.visibleMessages.map((m) => m.id), ['m1']);
  });

  test('cloud snapshot does not overwrite a locally revealed message',
      () async {
    db.controller.add([_msg('m1')]);
    await Future.delayed(Duration.zero);
    await store.revealLocally('m1');

    // Stale cloud state still says pending.
    db.controller.add([_msg('m1')]);
    await Future.delayed(Duration.zero);

    expect(store.visibleMessages.map((m) => m.id), ['m1']);
  });

  test('flushPendingSync pushes the delivery and accepts cloud state',
      () async {
    db.controller.add([_msg('m1')]);
    await Future.delayed(Duration.zero);
    await store.revealLocally('m1');

    await store.flushPendingSync();
    expect(db.deliveredIds, ['m1']);

    // Now a cloud pending snapshot means the delivery write was lost —
    // the store follows the cloud again.
    db.controller.add([_msg('m1')]);
    await Future.delayed(Duration.zero);
    expect(store.pendingMessages.map((m) => m.id), ['m1']);
  });

  test('failed sync keeps the message delivered locally', () async {
    db.failDeliveries = true;
    db.controller.add([_msg('m1')]);
    await Future.delayed(Duration.zero);
    await store.revealLocally('m1');

    await store.flushPendingSync();
    expect(store.visibleMessages.map((m) => m.id), ['m1']);
    expect(db.deliveredIds, isEmpty);
  });

  test('permanent rejection drops the doomed delivery from the queue',
      () async {
    db.controller.add([_msg('gone')]);
    await Future.delayed(Duration.zero);
    await store.revealLocally('gone');

    db.failWithCode = 'permission-denied';
    await store.flushPendingSync();
    expect(store.visibleMessages.map((m) => m.id), ['gone']);

    // No more doomed retries: the next flush does not attempt the write.
    final callsAfterFirstFlush = List.of(db.markDeliveredCalls);
    await store.flushPendingSync();
    expect(db.markDeliveredCalls, callsAfterFirstFlush);
  });

test('deleteForMe hides immediately and syncs', () async {
    db.controller.add([_msg('m1'), _msg('m2')]);
    await Future.delayed(Duration.zero);

    await store.deleteForMe('m1');
    expect(store.pendingMessages.map((m) => m.id), ['m2']);
    expect(db.hiddenIds['m1'], ['u1']); // pushed to Firestore

    // Once the flag is in the cloud, the message stays hidden.
    db.controller.add([
      _msg('m1', deletedBy: ['u1']),
      _msg('m2'),
    ]);
    await Future.delayed(Duration.zero);
    expect(store.pendingMessages.map((m) => m.id), ['m2']);
  });

  test('offline delete stays hidden until synced', () async {
    db.failHides = true;
    db.controller.add([_msg('m1'), _msg('m2')]);
    await Future.delayed(Duration.zero);

    await store.deleteForMe('m1');
    expect(db.hiddenIds['m1'], isNull); // not synced yet

    // Cloud snapshot without the delete flag must not resurrect it.
    db.controller.add([_msg('m1'), _msg('m2')]);
    await Future.delayed(Duration.zero);
    expect(store.pendingMessages.map((m) => m.id), ['m2']);

    // Back online: the queued delete goes through.
    db.failHides = false;
    await store.flushPendingDeletes();
    expect(db.hiddenIds['m1'], ['u1']);
  });

  test('clear resets state', () async {
    db.controller.add([_msg('m1')]);
    await Future.delayed(Duration.zero);

    await store.clear();
    expect(store.visibleMessages, isEmpty);
    expect(store.pendingMessages, isEmpty);
  });
}
