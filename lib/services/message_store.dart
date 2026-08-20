import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import 'database_service.dart';

/// Single source of truth for the recipient's messages.
///
/// Keeps a local cache on disk so geofence detection and message reveal keep
/// working without internet: pending messages downloaded while online are
/// revealed locally as soon as the user enters the point, and the delivery is
/// pushed to Firestore later when a connection is available again.
class MessageStore extends ChangeNotifier {
  MessageStore._();
  static final MessageStore instance = MessageStore._();

  final DatabaseService _db = DatabaseService();

  String? _userId;
  StreamSubscription<List<GeoMessage>>? _sub;
  final Map<String, GeoMessage> _messages = {};
  final Set<String> _pendingSync = {}; // delivered locally, not yet in Firestore

  String get _cacheKey => 'msg_cache_$_userId';

  /// Revealed messages, newest first.
  List<GeoMessage> get visibleMessages => _messages.values
      .where((m) => m.status == 'delivered')
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Messages waiting for the recipient to enter the geo-zone.
  List<GeoMessage> get pendingMessages =>
      _messages.values.where((m) => m.status == 'pending').toList();

  Future<void> init(String userId) async {
    if (_userId == userId && _sub != null) return;
    await clear();
    _userId = userId;
    await _load();
    _sub = _db.getIncomingMessages(userId).listen(
      _applyCloud,
      onError: (_) {
        // Offline — the local cache keeps the last known state.
      },
    );
  }

  Future<void> clear() async {
    _sub?.cancel();
    _sub = null;
    _userId = null;
    _messages.clear();
    _pendingSync.clear();
    notifyListeners();
  }

  void _applyCloud(List<GeoMessage> cloud) {
    for (final m in cloud) {
      final existing = _messages[m.id];
      if (existing != null &&
          existing.status == 'delivered' &&
          m.status == 'pending' &&
          _pendingSync.contains(m.id)) {
        continue; // revealed locally while offline; keep until synced
      }
      _messages[m.id] = m;
    }
    notifyListeners();
    _persist();
    flushPendingSync();
  }

  /// Marks a pending message as revealed locally (works offline). The delivery
  /// is queued and pushed to Firestore as soon as a connection is available.
  Future<void> revealLocally(String messageId) async {
    final m = _messages[messageId];
    if (m == null || m.status == 'delivered') return;
    _messages[messageId] = m.copyWith(status: 'delivered');
    _pendingSync.add(messageId);
    notifyListeners();
    await _persist();
  }

  /// Delivery was written to Firestore successfully.
  Future<void> confirmDelivered(String messageId) async {
    if (_pendingSync.remove(messageId)) {
      await _persist();
    }
  }

  /// Pushes queued local deliveries to Firestore (best effort, online only).
  Future<void> flushPendingSync() async {
    if (_pendingSync.isEmpty) return;
    for (final id in _pendingSync.toList()) {
      try {
        await _db.markDelivered(id);
        _pendingSync.remove(id);
      } catch (_) {
        return; // still offline
      }
    }
    await _persist();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      for (final item in (data['messages'] as List? ?? [])) {
        final m = GeoMessage.fromMap((item as Map).cast<String, dynamic>());
        _messages[m.id] = m;
      }
      _pendingSync
        ..clear()
        ..addAll((data['pendingSync'] as List? ?? []).cast<String>());
    } catch (_) {
      // Corrupt cache — ignore.
    }
  }

  Future<void> _persist() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode({
        'messages': _messages.values.map((m) => m.toMap()).toList(),
        'pendingSync': _pendingSync.toList(),
      }),
    );
  }
}