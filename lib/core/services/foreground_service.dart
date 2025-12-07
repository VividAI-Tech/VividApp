import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundService {
  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'vivid_foreground',
        channelName: 'VividAI Recording Service',
        channelDescription: 'Keeps recording running in background',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        isSticky: true,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 1000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    return await FlutterForegroundTask.startService(
      notificationTitle: 'VividAI Recording',
      notificationText: 'Recording in progress...',
      callback: startCallback,
    );
  }

  static Future<bool> stopService() async {
    return await FlutterForegroundTask.stopService();
  }

  static Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }
}

// This must be a top-level function
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

class RecordingTaskHandler extends TaskHandler {
  int _seconds = 0;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _seconds = 0;
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    _seconds++;

    final hours = _seconds ~/ 3600;
    final minutes = (_seconds % 3600) ~/ 60;
    final secs = _seconds % 60;

    final timeStr =
        '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';

    await FlutterForegroundTask.updateService(
      notificationTitle: 'VividAI Recording',
      notificationText: 'Recording: $timeStr',
    );

    sendPort?.send(_seconds);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // Cleanup
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Handle notification button press
  }

  @override
  void onNotificationPressed() {
    // Handle notification tap
    FlutterForegroundTask.launchApp();
  }
}
