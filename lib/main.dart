import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'core/services/foreground_service.dart';

/// Check if running on desktop platform
bool get isDesktop {
  if (kIsWeb) return false;
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

/// Check if running on mobile platform
bool get isMobile {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Initialize FlutterGemma for on-device AI
  try {
    await FlutterGemma.initialize();
  } catch (e) {
    debugPrint('FlutterGemma initialization failed (may not be supported on this platform): $e');
  }

  // Platform-specific initialization
  if (isMobile) {
    // Mobile-specific setup
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0F172A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // Lock to portrait mode on mobile
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Initialize notifications (mobile only)
    await NotificationService.initialize();

    // Initialize foreground service (mobile only)
    await ForegroundService.initialize();
  }

  if (isDesktop) {
    // Desktop-specific setup
    // Initialize notifications for desktop
    await NotificationService.initialize();
    
    // Window manager initialization will be done in app.dart
  }

  runApp(
    const ProviderScope(
      child: VividNotesApp(),
    ),
  );
}
