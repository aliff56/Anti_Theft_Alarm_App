import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'audio_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';
// If you see an error about shared_preferences, run:
// flutter pub add shared_preferences

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anti-Theft',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF181A20),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181A20),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.tealAccent),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Color(0xFF181A20),
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        cardColor: const Color(0xFF23263A),
        colorScheme: ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.teal,
          surface: Color(0xFF23263A),
          background: Color(0xFF181A20),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(color: Colors.white),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.all(Colors.tealAccent),
          trackColor: MaterialStateProperty.all(Colors.teal),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.all(Colors.tealAccent),
        ),
      ),
      home: const MyHomePage(title: 'Anti-Theft'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('antitheft_service');
  bool _armed = false;
  String? _appliedAudio;
  String? _appliedLoop;
  bool _appliedVibrate = false;

  @override
  void initState() {
    super.initState();
    _loadAppliedAudio();
    _requestNotificationPermission();
    platform.setMethodCallHandler((call) async {
      if (call.method == 'disarmedByNotification') {
        setState(() {
          _armed = false;
        });
      }
    });
  }

  Future<void> _loadAppliedAudio() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appliedAudio = prefs.getString('selected_audio') ?? 'alarm.wav';
      _appliedLoop = prefs.getString('selected_loop') ?? 'infinite';
      _appliedVibrate = prefs.getBool('selected_vibrate') ?? false;
    });
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        await Permission.notification.request();
      }
    }
  }

  Future<void> _toggleArm() async {
    if (_armed) {
      await platform.invokeMethod('disarm');
      await platform.invokeMethod('stopService');
    } else {
      await platform.invokeMethod('startService');
      await platform.invokeMethod('arm');
    }
    setState(() => _armed = !_armed);
  }

  Future<void> _setSelectedAudio(
    String fileName,
    String loop,
    bool vibrate,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_audio', fileName);
    await prefs.setString('selected_loop', loop);
    await prefs.setBool('selected_vibrate', vibrate);
    await platform.invokeMethod('setAudio', {
      'fileName': fileName,
      'loop': loop,
      'vibrate': vibrate,
    });
    await _loadAppliedAudio(); // Refresh state after applying
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Request Notification Permission',
            onPressed: _handleNotificationPermissionButton,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 32),
          Center(
            child: _AnimatedArmButton(armed: _armed, onToggle: _toggleArm),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: AudioSelectionGrid(
              appliedAudio: _appliedAudio,
              appliedLoop: _appliedLoop,
              appliedVibrate: _appliedVibrate,
              onApply: (option, loop, vibrate) {
                _setSelectedAudio(option.fileName, loop, vibrate);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNotificationPermissionButton() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.notification.status;
        if (status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification permission is already granted.'),
              ),
            );
          }
        } else {
          final result = await Permission.notification.request();
          if (mounted) {
            if (result.isGranted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification permission granted!'),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification permission not granted.'),
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notification permission not required on this Android version.',
              ),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission not required on this platform.',
            ),
          ),
        );
      }
    }
  }
}

// Animated arm/disarm button widget
class _AnimatedArmButton extends StatefulWidget {
  final bool armed;
  final VoidCallback onToggle;
  const _AnimatedArmButton({required this.armed, required this.onToggle});

  @override
  State<_AnimatedArmButton> createState() => _AnimatedArmButtonState();
}

class _AnimatedArmButtonState extends State<_AnimatedArmButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnim;
  late Animation<double> _iconAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: widget.armed ? 1.0 : 0.0,
    );
    _colorAnim = ColorTween(
      begin: Colors.grey[800],
      end: Colors.tealAccent,
    ).animate(_controller);
    _iconAnim = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _AnimatedArmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.armed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _colorAnim.value,
              shape: BoxShape.circle,
              boxShadow: [
                if (widget.armed)
                  BoxShadow(
                    color: Colors.tealAccent.withOpacity(0.4),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: widget.armed
                    ? Icon(
                        Icons.lock_open,
                        key: const ValueKey('armed'),
                        color: Colors.black,
                        size: 48,
                      )
                    : Icon(
                        Icons.lock,
                        key: const ValueKey('disarmed'),
                        color: Colors.white,
                        size: 48,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
