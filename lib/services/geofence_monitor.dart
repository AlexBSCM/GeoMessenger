import '../models/message_model.dart';
import 'database_service.dart';
import 'message_store.dart';
import 'notification_service.dart';

/// The reveal pipeline shared by the app isolate (app in use) and the
/// background service isolate (app swiped away, screen locked or device
/// rebooted). Works offline: the local cache is updated first and the
/// delivery is pushed to Firestore when a connection is available.
class GeofenceMonitor {
  GeofenceMonitor._();

  static Future<void> reveal(GeoMessage message) async {
    await MessageStore.instance.revealLocally(message.id);
    await NotificationService().showGeoMessageNotification(message);
    try {
      await DatabaseService().markDelivered(message.id);
      await MessageStore.instance.confirmDelivered(message.id);
    } catch (_) {
      // Offline — the delivery stays queued and syncs later.
    }
  }
}
