import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// A tiny singleton that can be armed / disarmed from the UI.
/// When armed, it listens to the accelerometer and triggers a loud
/// alarm if movement exceeds [_threshold].
class AntiTheftService {
  // --- singleton boiler-plate -------------------------------------------------
  AntiTheftService._internal();
  static final AntiTheftService _instance = AntiTheftService._internal();
  factory AntiTheftService() => _instance;

  // --- public API -------------------------------------------------------------
  bool get isArmed => _armed;

  Future<void> arm() async {
    if (_armed) return;
    _armed = true;
    _movementSub = accelerometerEventStream().listen(_onEvent);
    // Keep the device awake so alarm keeps sounding.
    await WakelockPlus.enable();
  }

  Future<void> disarm() async {
    if (!_armed) return;
    _armed = false;
    await _movementSub?.cancel();
    await _player.stop();
    _alarming = false;
    await WakelockPlus.disable();
  }

  // --- internals --------------------------------------------------------------
  static const double _threshold = 12.0; // m/s², adjust for sensitivity
  static const Duration _cooldown = Duration(seconds: 2);

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<AccelerometerEvent>? _movementSub;
  DateTime _lastTrigger = DateTime.fromMillisecondsSinceEpoch(0);
  bool _armed = false;
  bool _alarming = false;

  void _onEvent(AccelerometerEvent e) async {
    if (!_armed) return;

    final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (magnitude < _threshold) return;

    // Avoid spamming the alarm for continuous movement.
    final now = DateTime.now();
    if (now.difference(_lastTrigger) < _cooldown) return;
    _lastTrigger = now;

    if (_alarming) return;
    _alarming = true;

    // Play the alarm sound from bundled assets.
    await _player.play(AssetSource('sounds/alarm.wav'), volume: 1.0);

    // When playback ends, allow retriggering.
    _player.onPlayerComplete.listen((_) => _alarming = false);
  }
}
