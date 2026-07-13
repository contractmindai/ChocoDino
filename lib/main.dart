import 'package:flutter/material.dart';
import 'screens/name_entry_screen.dart';
import 'utils/sound_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SoundManager.init();
  runApp(ChocolateEaterDinosaur());
}

class ChocolateEaterDinosaur extends StatelessWidget {
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
      home: NameEntryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}