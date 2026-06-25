// web_notification_helper.dart
// Unified notification helper using conditional imports.

import 'web_notification_helper_stub.dart'
    if (dart.library.html) 'web_notification_helper_web.dart' as helper;

/// Requests permission to display browser/system notifications.
void requestNotificationPermission() {
  helper.requestNotificationPermission();
}

/// Displays a desktop system notification and plays a sound.
void showWebNotification(String title, String body) {
  helper.showWebNotification(title, body);
}
