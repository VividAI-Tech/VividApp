import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme.dart';
import '../../../core/services/meeting_detection_service.dart';
import '../../notifications/presentation/notification_screen.dart';
import '../../notifications/services/notification_provider.dart';
import '../../recording/presentation/recording_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../notifications/presentation/notification_screen.dart';
import '../widgets/recording_fab.dart';
import '../widgets/stats_card.dart';
import '../widgets/recent_recordings_list.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  void _onIndexChanged(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Check if we are on a desktop-sized screen
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);

    if (isDesktop) {
      return _DesktopLayout(
        currentIndex: _currentIndex,
        onIndexChanged: _onIndexChanged,
      );
    }

    return _MobileLayout(
      currentIndex: _currentIndex,
      onIndexChanged: _onIndexChanged,
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const _MobileLayout({
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [_HomeTab(), HistoryScreen(), SettingsScreen()],
      ),
      floatingActionButton: const RecordingFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: LucideIcons.home,
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: () => onIndexChanged(0),
              ),
              _NavItem(
                icon: LucideIcons.history,
                label: 'History',
                isSelected: currentIndex == 1,
                onTap: () => onIndexChanged(1),
              ),
              _NavItem(
                icon: LucideIcons.settings,
                label: 'Settings',
                isSelected: currentIndex == 2,
                onTap: () => onIndexChanged(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const _DesktopLayout({
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  State<_DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<_DesktopLayout> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void didUpdateWidget(covariant _DesktopLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // If tab changed, pop to root to show the new tab content
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Row(
        children: [
          // Sidebar
          _DesktopSidebar(
            currentIndex: widget.currentIndex,
            onIndexChanged: widget.onIndexChanged,
          ),
          
          // Vertical Divider
          VerticalDivider(color: AppTheme.border, width: 1),

          // Main Content with Nested Navigator
          Expanded(
            child: Navigator(
              key: _navigatorKey,
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (context) => IndexedStack(
                    index: widget.currentIndex,
                    children: [
                      const _CenteredContent(child: _HomeTab()),
                      const _CenteredContent(child: HistoryScreen()),
                      const _CenteredContent(child: SettingsScreen()),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 32, bottom: 32),
        child: RecordingFAB(
          onCustomNavigate: (screen) {
            _navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => screen),
            );
          },
        ),
      ),
    );
  }
}

class _CenteredContent extends StatelessWidget {
  final Widget child;

  const _CenteredContent({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: child,
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const _DesktopSidebar({
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: AppTheme.bgCard,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Logo/Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 40,
                  height: 40,
                ),
                const SizedBox(width: 12),
                const Text(
                  'VividAI',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Navigation Items
          _SidebarItem(
            icon: LucideIcons.home,
            label: 'Home',
            isSelected: currentIndex == 0,
            onTap: () => onIndexChanged(0),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            icon: LucideIcons.history,
            label: 'History',
            isSelected: currentIndex == 1,
            onTap: () => onIndexChanged(1),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            icon: LucideIcons.settings,
            label: 'Settings',
            isSelected: currentIndex == 2,
            onTap: () => onIndexChanged(2),
          ),
          const Spacer(),
          
          // Notification Item (Desktop)
          Consumer(
            builder: (context, ref, child) {
              final unreadCount = ref.watch(notificationProvider.notifier).unreadCount;
              return _SidebarItem(
                icon: LucideIcons.bell,
                label: 'Notifications',
                isSelected: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                },
                badgeCount: unreadCount,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount; // Add badge count support

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.recordingRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab();

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  bool _showWelcomeBanner = true;

  @override
  void initState() {
    super.initState();
    _loadWelcomeBannerState();
  }

  Future<void> _loadWelcomeBannerState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showWelcomeBanner = prefs.getBool('welcome_banner_dismissed') != true;
    });
  }

  Future<void> _dismissWelcomeBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('welcome_banner_dismissed', true);
    setState(() {
      _showWelcomeBanner = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final meetingState = ref.watch(meetingDetectionServiceProvider);

    return CustomScrollView(
      slivers: [
        if (!isDesktop)
          SliverAppBar(
            floating: true,
            backgroundColor: AppTheme.bgDark,
            // Add leading space for macOS traffic lights
            leadingWidth: 70,
            leading: const SizedBox(width: 70), // Space for macOS close/minimize/maximize
            title: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 32,
                  height: 32,
                ),
                const SizedBox(width: 12),
                const Text(
                  'VividAI',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            actions: [
              Consumer(
                builder: (context, ref, child) {
                  final unreadCount = ref.watch(notificationProvider.notifier).unreadCount;
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.bell),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationScreen(),
                            ),
                          );
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.recordingRed,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Meeting detection is now handled by GlobalOverlayManager at top
              
              // Welcome section (Mobile only)
              if (!isDesktop && _showWelcomeBanner) ...[
                _WelcomeCard(onDismiss: _dismissWelcomeBanner),
                const SizedBox(height: 24),
              ],
              
              // On desktop, add some top padding since we removed the AppBar
              if (isDesktop) const SizedBox(height: 24),

              // Stats
              const StatsCard(),
              const SizedBox(height: 24),

              // Quick actions
              _QuickActions(),
              const SizedBox(height: 24),

              // Recent recordings
              const Text(
                'Recent Recordings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const RecentRecordingsList(),

              // Bottom padding for FAB
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final VoidCallback onDismiss;

  const _WelcomeCard({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record & Transcribe',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Capture calls and get AI-powered summaries with on-device processing',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      LucideIcons.brain,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner shown when meeting/call is detected
class _MeetingDetectedBanner extends StatelessWidget {
  final VoidCallback onStartRecording;

  const _MeetingDetectedBanner({required this.onStartRecording});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.recordingRed.withOpacity(0.9),
            AppTheme.recordingRed.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.recordingRed.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Mic icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.mic,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔴 Audio/Video Call Detected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your microphone is being used by another app',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Start Recording button
          ElevatedButton.icon(
            onPressed: onStartRecording,
            icon: const Icon(LucideIcons.circle, size: 14),
            label: const Text('Record'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.recordingRed,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: LucideIcons.mic,
            title: 'Record',
            subtitle: 'Start recording',
            color: AppTheme.primaryColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecordingScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: LucideIcons.fileAudio,
            title: 'Import',
            subtitle: 'From file',
            color: AppTheme.secondaryColor,
            onTap: () async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.audio,
                );

                if (result != null && result.files.single.path != null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Import functionality ready for: ${result.files.single.name}',
                        ),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error picking file'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
