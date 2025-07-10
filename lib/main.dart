import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'audio_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';
// If you see an error about shared_preferences, run:
// flutter pub add shared_preferences

import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';
import 'package:animated_check/animated_check.dart';

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
  bool _appliedFlash = false;
  bool _pickpocketMode = false;

  @override
  void initState() {
    super.initState();
    _loadAppliedAudio();
    _loadPickpocketMode();
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
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text(
              'Pickpocket Mode',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Only alert if phone is pulled out of pocket',
              style: TextStyle(color: Colors.white70),
            ),
            value: _pickpocketMode,
            onChanged: (val) => _setPickpocketMode(val),
            activeColor: Colors.tealAccent,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AudioSelectionGrid(
              appliedAudio: _appliedAudio,
              appliedLoop: _appliedLoop,
              appliedVibrate: _appliedVibrate,
              appliedFlash: _appliedFlash,
              onApply: (option, loop, vibrate, flash) {
                _setSelectedAudio(option.fileName, loop, vibrate, flash);
              },
              footer: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.wallpaper),
                  label: const Text('Wallpapers'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => WallpapersScreen()),
                    );
                  },
                ),
              ),
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

// WallpapersScreen implementation
class WallpapersScreen extends StatelessWidget {
  const WallpapersScreen({Key? key}) : super(key: key);

  // List of wallpaper asset paths
  List<String> get wallpaperAssets => [
    'assets/wallpapers/1.jpg',
    'assets/wallpapers/2.jpg',
    'assets/wallpapers/3.jpg',
    'assets/wallpapers/4.jpg',
    'assets/wallpapers/5.jpg',
    'assets/wallpapers/6.jpg',
    'assets/wallpapers/7.jpg',
    'assets/wallpapers/8.jpg',
    'assets/wallpapers/9.jpg',
    'assets/wallpapers/10.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Wallpaper')),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 240, // Increased height for each item
        ),
        itemCount: wallpaperAssets.length,
        itemBuilder: (context, index) {
          final asset = wallpaperAssets[index];
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WallpaperPreviewScreen(
                    assetPath: asset,
                    parentContext: context,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(asset, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}

class WallpaperPreviewScreen extends StatelessWidget {
  final String assetPath;
  final BuildContext parentContext;
  const WallpaperPreviewScreen({
    Key? key,
    required this.assetPath,
    required this.parentContext,
  }) : super(key: key);

  Future<void> _showConfirmationDialog(BuildContext parentContext) async {
    BuildContext? dialogContext;
    showDialog(
      context: parentContext,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        dialogContext = ctx;
        return Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _AnimatedTick(),
                const SizedBox(height: 18),
                const Text(
                  'Wallpaper Applied!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
    await Future.delayed(
      const Duration(milliseconds: 1200),
    ); // Shorter dialog display
    if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
      Navigator.of(dialogContext!).pop();
    }
  }

  Future<void> _setWallpaper(BuildContext context, int location) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/temp_wallpaper.jpg').create();
      await file.writeAsBytes(bytes);
      final wallpaperManager = WallpaperManagerFlutter();
      bool result = await wallpaperManager.setWallpaper(file, location);
      if (context.mounted && result) {
        // Pop the preview screen first
        Navigator.of(context).pop();
        // Show the dialog on the parent screen after the pop
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showConfirmationDialog(parentContext);
        });
      } else if (context.mounted && !result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set wallpaper.'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set wallpaper: $e'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          ),
        );
      }
    }
  }

  void _showSetOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Set as Home Screen'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _setWallpaper(context, WallpaperManagerFlutter.homeScreen);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Set as Lock Screen'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _setWallpaper(context, WallpaperManagerFlutter.lockScreen);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.smartphone),
                title: const Text('Set as Both'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _setWallpaper(context, WallpaperManagerFlutter.bothScreens);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.center,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.wallpaper),
                label: const Text('Set as Wallpaper'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _showSetOptions(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTick extends StatefulWidget {
  const _AnimatedTick({Key? key}) : super(key: key);

  @override
  State<_AnimatedTick> createState() => _AnimatedTickState();
}

class _AnimatedTickState extends State<_AnimatedTick>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400), // Faster animation
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCheck(progress: _controller, size: 48, color: Colors.white);
  }
}
