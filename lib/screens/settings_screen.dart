// lib/screens/settings_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/player_progress.dart';
import '../models/sweet_world.dart';
import '../utils/notification_service.dart';
import '../utils/sound_manager.dart';
import '../dialogs/tutorial_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final PlayerProgress progress;
  final SweetWorld world;
  final VoidCallback onUpdate;

  // NEW: Game-specific parameters
  final bool isPlaying;
  final VoidCallback? onRestart;
  final VoidCallback? onExit;

  const SettingsScreen({
    Key? key,
    required this.progress,
    required this.world,
    required this.onUpdate,
    this.isPlaying = false,
    this.onRestart,
    this.onExit,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SoundManager.addListener(_onSoundChanged);
  }

  @override
  void dispose() {
    SoundManager.removeListener(_onSoundChanged);
    super.dispose();
  }

  void _onSoundChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleNotifications(bool value) async {
    if (kIsWeb) return;
    
    setState(() => _busy = true);
    try {
      if (value) {
        await NotificationService.requestPermission();
        widget.progress.remindersEnabled = true;
        await widget.progress.save();
        await NotificationService.scheduleWeeklyRecap(widget.progress);
        await NotificationService.scheduleWelcomeBack(widget.progress);
      } else {
        widget.progress.remindersEnabled = false;
        await widget.progress.save();
        await NotificationService.cancelAll();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final world = widget.world;
    
    final bgFallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [world.primaryColor, world.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.isPlaying ? 'Game Paused' : 'Settings',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                world.primaryColor.withOpacity(0.9),
                world.secondaryColor.withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              world.backgroundImagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => bgFallback,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.25)),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                // ==========================================
                // IN-GAME CONTROLS (Only if playing)
                // ==========================================
                if (widget.isPlaying) ...[
                  _buildActionCard(
                    icon: Icons.play_arrow,
                    title: 'Resume Game',
                    color: Colors.green.shade600,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.menu_book,
                    title: 'How to Play',
                    color: Colors.blue.shade600,
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => TutorialDialog(
                          onDismiss: () => Navigator.pop(context),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.refresh,
                    title: 'Restart Level',
                    color: Colors.orange.shade700,
                    onTap: () {
                      Navigator.pop(context); // Close settings
                      widget.onRestart?.call(); // Trigger restart
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.exit_to_app,
                    title: 'Exit Level',
                    color: Colors.red.shade600,
                    onTap: () {
                      Navigator.pop(context); // Close settings
                      widget.onExit?.call(); // Trigger exit
                    },
                  ),
                  const SizedBox(height: 32),
                ],

                // ==========================================
                // APP SETTINGS
                // ==========================================
                _buildSectionHeader(world, 'Preferences'),
                const SizedBox(height: 8),
                
                // SOUND TOGGLE
                _buildSettingCard(
                  world: world,
                  icon: SoundManager.muted ? Icons.volume_off : Icons.volume_up,
                  title: 'Sound Effects',
                  subtitle: SoundManager.muted ? 'Muted' : 'On',
                  trailing: Switch(
                    value: !SoundManager.muted,
                    activeColor: world.primaryColor,
                    onChanged: (val) async {
                      await SoundManager.toggleMute();
                    },
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // NOTIFICATIONS TOGGLE
                _buildSettingCard(
                  world: world,
                  icon: widget.progress.remindersEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  title: 'Notifications',
                  subtitle: kIsWeb 
                      ? 'Not available in the web preview.' 
                      : 'A gentle weekly summary.',
                  trailing: Switch(
                    value: widget.progress.remindersEnabled,
                    activeColor: world.primaryColor,
                    onChanged: (kIsWeb || _busy) ? null : _toggleNotifications,
                  ),
                ),
                
                // Only show stats if NOT in-game (to keep pause menu clean)
                if (!widget.isPlaying) ...[
                  const SizedBox(height: 32),
                  _buildSectionHeader(world, 'Progress'),
                  const SizedBox(height: 8),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: world.primaryColor.withOpacity(0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.stars, color: Colors.amber.shade600),
                          title: const Text('Total Stars', style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text(
                            '${widget.progress.totalStars}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: world.primaryColor,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.shopping_bag, color: Colors.brown.shade400),
                          title: const Text('Points', style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text(
                            '${widget.progress.totalPoints}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: world.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Choco Dino v1.0.0',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(SweetWorld world, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 1.5,
          shadows: const [
            Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1))
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required SweetWorld world,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: world.primaryColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: world.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: world.primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: trailing,
      ),
    );
  }
}