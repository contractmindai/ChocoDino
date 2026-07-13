import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // for VoidCallback

/// Central sound/music controller with persistent mute state.
class SoundManager {
  SoundManager._();

  static bool _muted = false;
  static bool _initialized = false;

  static final AudioPlayer _bgPlayer = AudioPlayer();
  static final AudioPlayer _sfxPlayer = AudioPlayer();
  static bool _bgStarted = false;

  static final List<VoidCallback> _listeners = [];

  /// Load mute state from SharedPreferences.
  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool('sound_muted') ?? false;
    _initialized = true;
    if (_muted) {
      await _bgPlayer.stop();
      _bgStarted = false;
    }
  }

  /// Toggle mute state (both music and SFX).
  static Future<void> toggleMute() async {
    _muted = !_muted;
    await _saveState();
    if (_muted) {
      await stopBg();
      await _sfxPlayer.stop();
    } else {
      await playBg();
    }
    _notifyListeners();
  }

  static bool get muted => _muted;

  /// Set mute explicitly.
  static Future<void> setMuted(bool value) async {
    if (_muted == value) return;
    _muted = value;
    await _saveState();
    if (_muted) {
      await stopBg();
      await _sfxPlayer.stop();
    } else {
      await playBg();
    }
    _notifyListeners();
  }

  static Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_muted', _muted);
  }

  /// Register a listener that gets called when mute state changes.
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  static void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  // ----- Background music -----
  static Future<void> playBg() async {
    if (_muted || _bgStarted) return;
    _bgStarted = true;
    try {
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.play(AssetSource('sounds/bg.mp3'), volume: 0.25);
    } catch (_) {
      _bgStarted = false;
    }
  }

  static Future<void> stopBg() async {
    _bgStarted = false;
    try {
      await _bgPlayer.stop();
    } catch (_) {}
  }

  // ----- Sound effects -----
  static Future<void> _safePlaySfx(String asset, {double volume = 1.0}) async {
    if (_muted) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource(asset), volume: volume);
    } catch (_) {
      // ignore
    }
  }

  static Future<void> playEat() => _safePlaySfx('sounds/eat.mp3', volume: 0.6);
  static Future<void> playWin() => _safePlaySfx('sounds/win.mp3', volume: 0.7);
  static Future<void> playHit() => _safePlaySfx('sounds/hit.mp3', volume: 0.6);
  static Future<void> playTreeBlock() => _safePlaySfx('sounds/tree_block.mp3', volume: 0.4);
  static Future<void> playButtonTap() => _safePlaySfx('sounds/button_tap.mp3', volume: 0.4);
  static Future<void> playStageClear() => _safePlaySfx('sounds/stage_clear.mp3', volume: 0.7);

  static Future<void> dispose() async {
    await _bgPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}