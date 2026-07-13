import 'package:flutter/material.dart';
import '../widgets/logo.dart';
import 'game_home_screen.dart';

class NameEntryScreen extends StatefulWidget {
  @override
  _NameEntryScreenState createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const ChocoDinoLogo(fontSize: 28),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ---- Dino image with bounce animation ----
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: -20, end: 0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) => Transform.translate(
                      offset: Offset(0, value),
                      child: child,
                    ),
                    child: Image.asset(
                      'assets/dino/idle.png', // reuse the same idle dino
                      height: 80,
                      width: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to emoji if image missing
                        return const Text('🦕', style: TextStyle(fontSize: 80));
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  const Text(
                    'CHOCOLATE EATER',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Text(
                    'DINOSAUR',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF795548),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ---- Name input ----
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'What\'s your dino\'s name?',
                      labelStyle: const TextStyle(
                        color: Color(0xFFA1887F),
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.edit, color: Color(0xFF8D6E63)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    style: const TextStyle(fontSize: 18, color: Color(0xFF4E342E)),
                  ),
                  const SizedBox(height: 32),
                  // ---- Start button ----
                  ElevatedButton(
                    onPressed: () {
                      String name = _nameController.text.trim();
                      if (name.isEmpty) name = 'Rex';
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => GameHomeScreen(dinoName: name)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB74D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      shape: const StadiumBorder(),
                      elevation: 8,
                      shadowColor: Colors.orange.shade300,
                    ),
                    child: TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.9, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                      child: const Text(
                        'START ADVENTURE',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '🦕 Let’s go!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}