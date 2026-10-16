// web_notification_helper_stub.dart
// Stub implementation of Web notifications for non-web platforms.

void requestNotificationPermission() {
  // No-op on native platforms
}

void showWebNotification(
  String title,
  String body, {
  String priority = 'normal',
  void Function()? onTap,
}) {
  // No-op on native platforms
}
