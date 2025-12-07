import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/home/services/call_detector.dart';
import '../features/home/services/meeting_detector.dart';
import '../features/recording/widgets/global_overlay_manager.dart';
import '../main.dart' show isDesktop;
import 'theme.dart';

class VividNotesApp extends ConsumerStatefulWidget {
  const VividNotesApp({super.key});

  @override
  ConsumerState<VividNotesApp> createState() => _VividNotesAppState();
}

bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

class _VividNotesAppState extends ConsumerState<VividNotesApp> {
  @override
  void initState() {
    super.initState();
    _initPlatformServices();
  }

  Future<void> _initPlatformServices() async {
    if (isDesktop) {
      // Initialize meeting detector for desktop
      await MeetingDetector().initialize();
    } else if (_isMobile) {
      // Initialize call detector for mobile
      await CallDetector().initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vivid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        // Add responsive breakpoints
        return ResponsiveBreakpoints.builder(
          child: child!,
          breakpoints: [
            const Breakpoint(start: 0, end: 450, name: MOBILE),
            const Breakpoint(start: 451, end: 800, name: TABLET),
            const Breakpoint(start: 801, end: 1920, name: DESKTOP),
            const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
          ],
        );
      },
      home: const GlobalOverlayManager(
        child: HomeScreen(),
      ),
    );
  }
}

