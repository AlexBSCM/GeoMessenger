import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geo_messenger/models/message_model.dart';
import 'package:geo_messenger/services/database_service.dart';
import 'package:geo_messenger/services/message_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDb implements DatabaseService {
  final controller = StreamController<List<GeoMessage>>.broadcast();
  final deliveredIds = <String>[];
  bool failDeliveries = false;

  @override
  Stream<List<GeoMessage>> getIncomingMessages(String userId) =>
      controller.stream;

  @override
  Future<void> markDelivered(String messageId) async {
    if (failDeliveries) throw Exception('offline');
    deliveredIds.add(messageId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

GeoMessage _msg(String id, {String status = 'pending'}) => GeoMessage(
      id: id,
      senderId: 'sender',
      senderName: 'Sender',
      recipientIds: ['u1'],
      recipientName: 'Recipient',
      text: 'text-$id',
      latitude: 57.99,
      longitude: 56.26,
      status: status,
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

  test('clear resets state', () async {
    db.controller.add([_msg('m1')]);
    await Future.delayed(Duration.zero);

    await store.clear();
    expect(store.visibleMessages, isEmpty);
    expect(store.pendingMessages, isEmpty);
  });
}
