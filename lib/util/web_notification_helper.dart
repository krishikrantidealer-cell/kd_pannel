// web_notification_helper.dart
// Unified notification helper using conditional imports.

import 'web_notification_helper_native.dart'
    if (dart.library.js_interop) 'web_notification_helper_web.dart'
    if (dart.library.html) 'web_notification_helper_web.dart' as helper;

/// Requests permission to display browser/system notifications.
void requestNotificationPermission() {
  helper.requestNotificationPermission();
}

/// Displays a desktop system notification and plays a priority-aware sound.
void showWebNotification(
  String title,
  String body, {
  String priority = 'normal',
  void Function()? onTap,
}) {
  helper.showWebNotification(
    title,
    body,
    priority: priority,
    onTap: onTap,
  );
}
