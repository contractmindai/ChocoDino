import 'package:flutter/material.dart';
import 'screens/name_entry_screen.dart';
import 'screens/game_home_screen.dart';
import 'models/player_progress.dart';
import 'utils/sound_manager.dart';
import 'utils/sound_manager.dart';
import 'utils/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SoundManager.init();
  await NotificationService.init();

  // Check for a previously saved name so returning players skip straight
  // to the home screen instead of re-entering their name every launch.
  final progress = await PlayerProgress.load();
  final savedName = progress.dinoName;
  final hasSavedName = savedName != null && savedName.trim().isNotEmpty;

  runApp(ChocolateEaterDinosaur(
    initialDinoName: hasSavedName ? savedName : null,
  ));
}

class ChocolateEaterDinosaur extends StatelessWidget {
  final String? initialDinoName;

  const ChocolateEaterDinosaur({Key? key, this.initialDinoName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChocoDino',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'GameFont', // falls back to Comic Neue if not found
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFF3E0),
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
          elevation: 6,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: initialDinoName != null
          ? GameHomeScreen(dinoName: initialDinoName!)
          : NameEntryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}