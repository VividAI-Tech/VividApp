import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_item_model.dart'; 

class NotificationNotifier extends StateNotifier<List<NotificationItemModel>> {
  NotificationNotifier() : super([]) {
    _loadNotifications();
  }

  static const String _storageKey = 'notifications_list';
  static const String _checkWelcomeKey = 'welcome_notification_shown';

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check for first-time welcome notification
    final welcomeShown = prefs.getBool(_checkWelcomeKey) ?? false;
    if (!welcomeShown) {
      // Add welcome notification
      state = [
        NotificationItemModel(
          title: 'Welcome to VividAI',
          message: 'Start recording your meetings to get AI summaries.',
          time: DateTime.now().toIso8601String(), 
          isRead: false,
        )
      ];
      await prefs.setBool(_checkWelcomeKey, true);
      _saveNotifications();
    } else {
      // Load persisted notifications
      final String? stored = prefs.getString(_storageKey);
      if (stored != null) {
        try {
          final List<dynamic> jsonList = jsonDecode(stored);
          state = jsonList.map((e) => NotificationItemModel.fromJson(e)).toList();
        } catch (e) {
          state = [];
        }
      }
    }
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  void addNotification(String title, String message) {
    final newNotification = NotificationItemModel(
      title: title,
      message: message,
      time: DateTime.now().toIso8601String(),
      isRead: false,
    );
    state = [newNotification, ...state];
    _saveNotifications();
  }

  void markAsRead(int index) {
    if (index < 0 || index >= state.length) return;
    
    final item = state[index];
    final updatedItem = NotificationItemModel(
      title: item.title,
      message: item.message,
      time: item.time,
      isRead: true,
    );
    
    final newState = [...state];
    newState[index] = updatedItem;
    state = newState;
    _saveNotifications();
  }

  void removeNotification(int index) {
    if (index < 0 || index >= state.length) return;
    final newState = [...state];
    newState.removeAt(index);
    state = newState;
    _saveNotifications();
  }

  void clearAll() {
    state = [];
    _saveNotifications();
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<NotificationItemModel>>((ref) {
  return NotificationNotifier();
});
