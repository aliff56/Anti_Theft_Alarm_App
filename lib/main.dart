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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'wallpaper_service.dart';
import 'splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
      home: SplashScreen(
        onGetStarted: () {
          navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(
              builder: (_) => const MyHomePage(title: 'Anti-Theft'),
            ),
          );
        },
      ),
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

  void _showEnabledScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AlarmEnabledScreen()));
  }

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
        backgroundColor: const Color(0xFF213B44), // Set app bar color
        elevation: 0,
        title: const Text(
          'Anti-Theft Alarm',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {}, // Placeholder for settings
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
                          Switch(
                            value: _pickpocketMode,
                            onChanged: (val) => _setPickpocketMode(val),
                            activeColor: Colors.white, // Thumb when ON
                            inactiveThumbColor: Colors.white, // Thumb when OFF
                            activeTrackColor: Color(0xFF203A43),
                            inactiveTrackColor: Color(0xFF203A43),
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
                      borderRadius: BorderRadius.circular(16),
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
class WallpapersScreen extends StatefulWidget {
  const WallpapersScreen({Key? key}) : super(key: key);

  @override
  State<WallpapersScreen> createState() => _WallpapersScreenState();
}

class _WallpapersScreenState extends State<WallpapersScreen> {
  List<Wallpaper> _wallpapers = [];
  bool _isLoading = true;
  bool _hasError = false;
  final int _perPage = 16;

  @override
  void initState() {
    super.initState();
    _loadWallpapers();
  }

  Future<void> _loadWallpapers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final wallpapers = await WallpaperService.getWallpapers(
        page: 1,
        perPage: _perPage,
      );
      setState(() {
        _wallpapers = wallpapers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Wallpaper')),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading wallpapers...'),
                ],
              ),
            )
          : _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load wallpapers',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadWallpapers,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _wallpapers.isEmpty
          ? const Center(child: Text('No wallpapers available'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 240,
              ),
              itemCount: _wallpapers.length,
              itemBuilder: (context, index) {
                final wallpaper = _wallpapers[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WallpaperPreviewScreen(
                          wallpaper: wallpaper,
                          parentContext: context,
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: wallpaper.url,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class WallpaperPreviewScreen extends StatelessWidget {
  final Wallpaper wallpaper;
  final BuildContext parentContext;
  const WallpaperPreviewScreen({
    Key? key,
    required this.wallpaper,
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
      // Download the image from URL
      final response = await http.get(Uri.parse(wallpaper.url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
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
      } else {
        throw Exception('Failed to download image: ${response.statusCode}');
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
              child: CachedNetworkImage(
                imageUrl: wallpaper.url,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.black,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(Icons.error, color: Colors.red, size: 48),
                  ),
                ),
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

class AlarmEnabledScreen extends StatelessWidget {
  const AlarmEnabledScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF203A43),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            // Add an extra outer green circle (make it more visible)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Color(0xFF01CB15), width: 1),
              ),
              child: Container(
                margin: const EdgeInsets.all(6),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF01CB15), // solid green
                  border: Border.all(color: Color(0xFF01CB15), width: 4),
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(0xFF01CB15), width: 2),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/icons/tick.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Anti-theft alert feature is\nenabled',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0, left: 16, right: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Back to Home'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
