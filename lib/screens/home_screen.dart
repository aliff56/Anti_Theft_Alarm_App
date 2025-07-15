import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import '../audio_selection.dart';
import '../widgets/custom_switch.dart';
import '../screens/settings_screen.dart';
import '../screens/activation_screens.dart' as activation;
import '../screens/wallpapers_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../theme.dart';

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
  bool _appliedFlash = false;
  bool _pickpocketMode = false;
  Timer? _autoDisarmTimer;
  bool _autoCloseApp = false;

  void _showEnabledScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const activation.AlarmEnabledScreen()),
    );
  }

  Future<bool> _isServiceRunning() async {
    if (!Platform.isAndroid) return false;
    const platform = MethodChannel('antitheft_service');
    try {
      return await platform.invokeMethod('serviceIsRunning') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAppliedAudio();
    _loadPickpocketMode();
    _requestNotificationPermission();
    _setupAutoDisarm();
    _loadAutoCloseSetting();
    _syncServiceState();
    platform.setMethodCallHandler((call) async {
      if (call.method == 'disarmedByNotification') {
        setState(() {
          _armed = false;
        });
      }
    });
  }

  Future<void> _syncServiceState() async {
    final running = await _isServiceRunning();
    setState(() {
      _armed = running;
    });
  }

  Future<void> _loadAppliedAudio() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appliedAudio = prefs.getString('selected_audio') ?? 'alarm2.ogg';
      _appliedLoop = prefs.getString('selected_loop') ?? 'infinite';
      _appliedVibrate = prefs.getBool('selected_vibrate') ?? false;
      _appliedFlash = prefs.getBool('selected_flash') ?? false;
    });
  }

  Future<void> _loadPickpocketMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pickpocketMode = prefs.getBool('pickpocket_mode') ?? false;
    });
    await platform.invokeMethod('setPickpocketMode', {
      'enabled': _pickpocketMode,
    });
  }

  Future<void> _setPickpocketMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pickpocket_mode', enabled);
    setState(() => _pickpocketMode = enabled);
    await platform.invokeMethod('setPickpocketMode', {'enabled': enabled});
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        await Permission.notification.request();
      }
    }
  }

  Future<void> _setupAutoDisarm() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('auto_disarm_enabled') ?? false;
    if (!enabled) {
      _autoDisarmTimer?.cancel();
      return;
    }
    final hour = prefs.getInt('auto_disarm_hour') ?? 9;
    final minute = prefs.getInt('auto_disarm_minute') ?? 0;
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    final duration = target.difference(now);
    _autoDisarmTimer?.cancel();
    _autoDisarmTimer = Timer(duration, () async {
      if (_armed) {
        await _toggleArm();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alarm auto-deactivated by timer.')),
          );
        }
      }
    });
  }

  Future<void> _loadAutoCloseSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoCloseApp = prefs.getBool('auto_close_after_activation') ?? false;
    });
  }

  Future<void> _setAutoCloseSetting(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_close_after_activation', enabled);
    setState(() => _autoCloseApp = enabled);
  }

  @override
  void dispose() {
    _autoDisarmTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleArm() async {
    if (_armed) {
      await platform.invokeMethod('disarm');
      await platform.invokeMethod('stopService');
      // Show the deactivation screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => activation.DeactivatedScreen(
              onBackToHome: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        );
      }
    } else {
      await platform.invokeMethod('startService');
      await platform.invokeMethod('arm');
      await _setupAutoDisarm(); // Reschedule timer on arm
      // Always check the latest value from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final autoClose = prefs.getBool('auto_close_after_activation') ?? false;
      if (autoClose) {
        Future.delayed(const Duration(milliseconds: 400), () {
          SystemNavigator.pop();
        });
      }
    }
    setState(() => _armed = !_armed);
  }

  Future<void> _setSelectedAudio(
    String fileName,
    String loop,
    bool vibrate,
    bool flash,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_audio', fileName);
    await prefs.setString('selected_loop', loop);
    await prefs.setBool('selected_vibrate', vibrate);
    await prefs.setBool('selected_flash', flash);
    await platform.invokeMethod('setAudio', {
      'fileName': fileName,
      'loop': loop,
      'vibrate': vibrate,
      'flash': flash,
    });
    await _loadAppliedAudio(); // Refresh state after applying
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF213B44), // Set app bar color
        elevation: 0,
        title: const Text(
          'Anti-Theft Alarm',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2C5364), // top
              Color(0xFF203A43), // bottom
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Power button with reversed circle color order
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outermost (top) circle
                    AnimatedContainer(
                      width: 150,
                      height: 150,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _armed
                            ? const Color(0x2901CB15) // #01CB15 at ~16% opacity
                            : const Color(0x4F5FACB5), // #5FACB5 at 31% opacity
                      ),
                    ),
                    // Middle circle
                    AnimatedContainer(
                      width: 130,
                      height: 130,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _armed
                            ? const Color(0x6101CB15) // #01CB15 at ~38% opacity
                            : const Color(0x66518692), // #518692 at 40% opacity
                      ),
                    ),
                    // Innermost circle
                    AnimatedContainer(
                      width: 110,
                      height: 110,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _armed
                            ? const Color(0xFF01CB15) // solid #01CB15
                            : null,
                        gradient: _armed
                            ? null
                            : const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF2D515D), // top
                                  Color(0xFF65B6BF), // bottom
                                ],
                              ),
                      ),
                    ),
                    // Power icon (activate)
                    GestureDetector(
                      onTap: () async {
                        if (!_armed) {
                          await _toggleArm();
                          _showEnabledScreen();
                        } else {
                          await _toggleArm();
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        color: Colors.transparent,
                        child: Image.asset(
                          'assets/icons/activate.png',
                          width: 56,
                          height: 56,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Tap to Activate text (no underline)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  _armed ? 'Tap to Deactivate' : 'Tap to Activate',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Pick Pocket Mode card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: SizedBox(
                  height: 65,
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Pick Pocket Mode',
                            style: TextStyle(
                              color: Color(0xFF203A43),
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              letterSpacing: 0.2,
                            ),
                          ),
                          CustomSwitch(
                            value: _pickpocketMode,
                            onChanged: (val) => _setPickpocketMode(val),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Alert Sounds',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                        decorationThickness: 2,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Audio options grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: GridView.builder(
                    itemCount: audioOptions.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                        ),
                    itemBuilder: (context, index) {
                      final option = audioOptions[index];
                      final isApplied = option.fileName == _appliedAudio;
                      // Map fileName to asset icon
                      String? iconAsset;
                      switch (option.fileName) {
                        case 'ambulance.ogg':
                          iconAsset = 'assets/icons/ambulance.png';
                          break;
                        case 'warning_alarm.ogg':
                          iconAsset = 'assets/icons/warning.png';
                          break;
                        case 'police.ogg':
                          iconAsset = 'assets/icons/police.png';
                          break;
                        case 'siren2.ogg':
                          iconAsset = 'assets/icons/siren.png';
                          break;
                        case 'siren.ogg':
                          iconAsset = 'assets/icons/siren2.png';
                          break;
                        case 'alarm2.ogg':
                          iconAsset = 'assets/icons/alarm.png';
                          break;
                        case 'alert.ogg':
                          iconAsset = 'assets/icons/alert.png';
                          break;
                        case 'sensor_alarm.ogg':
                          iconAsset = 'assets/icons/sensor_alarm.png';
                          break;
                        default:
                          iconAsset = null;
                      }
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AudioOptionDetailPage(
                                option: option,
                                isApplied: isApplied,
                                appliedLoop: _appliedLoop,
                                appliedVibrate: _appliedVibrate,
                                onApply: (opt, loop, vibrate, flash) {
                                  _setSelectedAudio(
                                    opt.fileName,
                                    loop,
                                    vibrate,
                                    flash,
                                  );
                                },
                                appliedFlash: _appliedFlash,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.30),
                                blurRadius: 6,
                                offset: Offset(0, 8),
                              ),
                            ],
                            border: isApplied
                                ? Border.all(
                                    color: Colors.greenAccent,
                                    width: 3,
                                  )
                                : null,
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Use asset icon if available
                                    if (iconAsset != null)
                                      Image.asset(
                                        iconAsset,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.contain,
                                      )
                                    else
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.image,
                                            color: Colors.grey[600],
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    Text(
                                      option.label,
                                      style: const TextStyle(
                                        color: Color(0xFF203A43),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isApplied)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Wallpaper button at the bottom
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 24.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => WallpapersScreen()),
                    );
                  },
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: kCardShadow,
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 18,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Explore Stunning Wallpapers',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.black,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
