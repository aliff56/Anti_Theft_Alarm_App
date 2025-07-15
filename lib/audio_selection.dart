import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'widgets/custom_switch.dart';

class AudioOption {
  final String fileName;
  final String label;
  final IconData icon;
  final String description;

  AudioOption(this.fileName, this.label, this.icon, this.description);
}

final List<AudioOption> audioOptions = [
  AudioOption('alarm2.ogg', 'Alarm', Icons.alarm_on, 'Alternative alarm.'),
  AudioOption('alert.ogg', 'Alert', Icons.warning, 'Alert sound.'),
  AudioOption(
    'warning_alarm.ogg',
    'Warning Alarm',
    Icons.warning_amber,
    'Loud warning alarm.',
  ),
  AudioOption(
    'sensor_alarm.ogg',
    'Sensor Alarm',
    Icons.sensors,
    'Sensor triggered alarm.',
  ),
  AudioOption(
    'ambulance.ogg',
    'Ambulance',
    Icons.local_hospital,
    'Ambulance siren.',
  ),
  AudioOption('police.ogg', 'Police', Icons.local_police, 'Police siren.'),
  AudioOption('siren.ogg', 'Siren', Icons.notifications_active, 'Loud siren.'),
  AudioOption('siren2.ogg', 'Siren 2', Icons.notifications, 'Another siren.'),
];

class AudioSelectionGrid extends StatelessWidget {
  final void Function(AudioOption, String loop, bool vibrate, bool flash)?
  onApply;
  final String? appliedAudio;
  final String? appliedLoop;
  final bool? appliedVibrate;
  final bool? appliedFlash;
  final Widget? footer;
  const AudioSelectionGrid({
    Key? key,
    this.onApply,
    this.appliedAudio,
    this.appliedLoop,
    this.appliedVibrate,
    this.appliedFlash,
    this.footer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Build rows of 3 cards each
    List<Widget> rows = [];
    for (int i = 0; i < audioOptions.length; i += 2) {
      final rowOptions = audioOptions.skip(i).take(2).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: rowOptions.map((option) {
              final isApplied = option.fileName == appliedAudio;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AudioOptionDetailPage(
                            option: option,
                            isApplied: isApplied,
                            appliedLoop: appliedLoop,
                            appliedVibrate: appliedVibrate ?? false,
                            onApply: onApply,
                            appliedFlash: appliedFlash,
                          ),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 4,
                      color: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            height: 180,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  option.icon,
                                  size: 48,
                                  color: Colors.tealAccent,
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    option.label,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    option.description,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isApplied)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.tealAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(5.0),
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }
    if (footer != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
          child: footer!,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: rows,
    );
  }
}

class AudioOptionDetailPage extends StatefulWidget {
  final AudioOption option;
  final bool isApplied;
  final String? appliedLoop;
  final bool appliedVibrate;
  final bool? appliedFlash;
  final void Function(AudioOption, String loop, bool vibrate, bool flash)?
  onApply;
  const AudioOptionDetailPage({
    required this.option,
    required this.isApplied,
    this.appliedLoop,
    required this.appliedVibrate,
    this.appliedFlash,
    this.onApply,
  });

  @override
  State<AudioOptionDetailPage> createState() => _AudioOptionDetailPageState();
}

class _AudioOptionDetailPageState extends State<AudioOptionDetailPage>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  late String _selectedLoop;
  bool _vibrate = false;
  bool _flash = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  bool _isSeeking = false;
  double _systemVolume = 0.5;
  static const platform = MethodChannel('antitheft_service');
  late AnimationController _waveController;

  // Track if the settings match the applied values
  bool get _isCurrentApplied {
    return widget.isApplied &&
        _selectedLoop == (widget.appliedLoop ?? 'infinite') &&
        _vibrate == widget.appliedVibrate &&
        _flash == (widget.appliedFlash ?? false);
  }

  @override
  void initState() {
    super.initState();
    _selectedLoop = widget.appliedLoop ?? 'infinite';
    _loadSettings();
    _player.onDurationChanged.listen((d) {
      setState(() {
        _audioDuration = d;
      });
    });
    _player.onPositionChanged.listen((p) {
      if (!_isSeeking) {
        setState(() {
          _audioPosition = p;
        });
      }
    });
    _getSystemVolume();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vibrate = prefs.getBool('selected_vibrate') ?? false;
      _flash = prefs.getBool('selected_flash') ?? false;
    });
  }

  Future<void> _getSystemVolume() async {
    try {
      final double volume = await platform.invokeMethod('getSystemVolume');
      setState(() {
        _systemVolume = volume;
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _setSystemVolume(double value) async {
    setState(() {
      _systemVolume = value;
    });
    try {
      await platform.invokeMethod('setSystemVolume', {'volume': value});
    } catch (e) {
      // ignore
    }
  }

  Future<void> _setAsRingtone() async {
    // Check Android version
    if (!Platform.isAndroid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ringtone setting is only supported on Android.'),
          ),
        );
      }
      return;
    }
    // Check WRITE_SETTINGS permission via platform channel
    final bool hasWriteSettings =
        await platform.invokeMethod('hasWriteSettingsPermission') ?? false;
    if (!hasWriteSettings) {
      if (mounted) {
        final goToSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'To set a ringtone, please allow "Modify system settings" for this app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (goToSettings == true) {
          await platform.invokeMethod('openWriteSettings');
        }
      }
      return;
    }
    // Only request storage permission for Android 9 and below
    bool storageGranted = true;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 29) {
        final status = await Permission.storage.request();
        storageGranted = status.isGranted;
        if (!storageGranted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to set ringtone.'),
            ),
          );
          return;
        }
      }
    }
    try {
      final result = await platform.invokeMethod('setRingtone', {
        'fileName': widget.option.fileName,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result ?? 'Ringtone set!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to set ringtone: $e')));
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    if (_isPlaying) {
      await _player.stop();
      setState(() => _isPlaying = false);
    } else {
      final assetPath = 'sounds/${widget.option.fileName}';
      try {
        await _player.play(AssetSource(assetPath));
        setState(() => _isPlaying = true);
        _player.onPlayerComplete.listen((_) {
          setState(() => _isPlaying = false);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio file not found: ${widget.option.fileName}'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Map fileName to asset icon
    String? iconAsset;
    switch (widget.option.fileName) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sound',
          style: GoogleFonts.urbanist(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF213B44),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C5364), Color(0xFF203A43)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sound Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 8,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 90,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_isPlaying)
                              AnimatedBuilder(
                                animation: _waveController,
                                builder: (context, child) {
                                  return CustomPaint(
                                    painter: _DualPulseCirclePainter(
                                      _waveController.value,
                                    ),
                                    size: const Size(90, 90),
                                  );
                                },
                              ),
                            iconAsset != null
                                ? Image.asset(iconAsset, width: 80, height: 80)
                                : Icon(
                                    widget.option.icon,
                                    size: 52,
                                    color: Colors.tealAccent,
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 36,
                          child: ElevatedButton(
                            onPressed: _preview,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF203A43),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 4,
                              shadowColor: Colors.black.withOpacity(0.18),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 0,
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            child: Text(
                              _isPlaying ? 'Stop' : 'Play',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 100,
                          height: 36,
                          child: ElevatedButton(
                            onPressed: _isCurrentApplied
                                ? () {}
                                : () {
                                    widget.onApply?.call(
                                      widget.option,
                                      _selectedLoop,
                                      _vibrate,
                                      _flash,
                                    );
                                    Navigator.pop(context);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF203A43),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 4,
                              shadowColor: Colors.black.withOpacity(0.18),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 0,
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            child: Text(
                              _isCurrentApplied ? 'Applied' : 'Apply',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Volume
              Text(
                'Volume:',
                style: GoogleFonts.urbanist(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/volume.png',
                      width: 36,
                      height: 36,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 5,
                          activeTrackColor: const Color(0xFF203A43),
                          inactiveTrackColor: Colors.grey.shade300,
                          thumbColor: const Color(0xFF203A43),
                          overlayColor: const Color(0x33213A43),
                          thumbShape: const _ThumbWithDotShape(),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 20,
                          ),
                        ),
                        child: Slider(
                          value: _systemVolume,
                          min: 0,
                          max: 1,
                          onChanged: (value) => _setSystemVolume(value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Duration
              Text(
                'Duration:',
                style: GoogleFonts.urbanist(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _durationButton('20s'),
                    const SizedBox(width: 12),
                    _durationButton('1m'),
                    const SizedBox(width: 12),
                    _durationButton('2m'),
                    const SizedBox(width: 12),
                    _durationButton('infinite', isIcon: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Flash/Vibrate
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    _toggleRow(
                      iconAsset: 'assets/icons/flash.png',
                      label: 'Flash on alert',
                      value: _flash,
                      onChanged: (val) => setState(() => _flash = val),
                    ),
                    _toggleRow(
                      iconAsset: 'assets/icons/vibrate.png',
                      label: 'Vibrate on alert',
                      value: _vibrate,
                      onChanged: (val) => setState(() => _vibrate = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Set as ringtone
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _setAsRingtone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF264653),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Set this sound as ringtone',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationButton(String label, {bool isIcon = false}) {
    final selected =
        _selectedLoop == label ||
        (label == 'infinite' &&
            (_selectedLoop == 'infinite' || _selectedLoop == '∞'));
    return SizedBox(
      width: 70,
      child: OutlinedButton(
        onPressed: () => setState(() => _selectedLoop = label),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? const Color(0xFF203A43) : Colors.white,
          foregroundColor: selected ? Colors.white : const Color(0xFF203A43),
          side: BorderSide(color: const Color(0xFF23414D), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        ),
        child: isIcon
            ? Image.asset(
                'assets/icons/infinity.png',
                width: 30,
                height: 30,
                color: selected ? Colors.white : const Color(0xFF203A43),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF203A43),
                  fontSize: 15,
                ),
              ),
      ),
    );
  }

  Widget _toggleRow({
    required String iconAsset,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Image.asset(iconAsset, width: 28, height: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Color(0xFF23414D),
                fontSize: 22,
              ),
            ),
          ),
          Transform.scale(
            scale: 1.0,
            child: CustomSwitch(
              value: value,
              onChanged: onChanged,
              width: 52,
              height: 32,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return '$m:$s';
  }
}

// Dual pulse animation painter (two circles pulsing at different rates)
class _DualPulseCirclePainter extends CustomPainter {
  final double progress;
  _DualPulseCirclePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Large circle: slow, big pulse
    final double bigBase = size.width * 0.45;
    final double bigPulse = bigBase + 18 * math.sin(progress * 2 * math.pi);
    final Paint bigPaint = Paint()
      ..color = const Color(0xFF39737A).withOpacity(0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, bigPulse, bigPaint);

    // Small circle: faster, smaller pulse
    final double smallBase = size.width * 0.32;
    final double smallPulse = smallBase + 10 * math.sin(progress * 4 * math.pi);
    final Paint smallPaint = Paint()
      ..color = const Color(0xFF39737A).withOpacity(0.32)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, smallPulse, smallPaint);
  }

  @override
  bool shouldRepaint(covariant _DualPulseCirclePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Custom thumb shape for slider with a white dot in the center
class _ThumbWithDotShape extends SliderComponentShape {
  const _ThumbWithDotShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(26, 26);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    // Outer dark circle
    final Paint outerPaint = Paint()
      ..color = sliderTheme.thumbColor ?? const Color(0xFF203A43)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 13, outerPaint);
    // Inner white dot
    final Paint innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 9, innerPaint);
  }
}

// Deactivated Screen
class DeactivatedScreen extends StatelessWidget {
  const DeactivatedScreen({Key? key, required this.onBackToHome})
    : super(key: key);
  final VoidCallback onBackToHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF203A43),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 48),
                Center(
                  child: Image.asset(
                    'assets/icons/deactivated.png',
                    width: 110,
                    height: 110,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Anti-theft alert feature deactivated',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Go to home page to reactivate the\nfeature',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onBackToHome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF264653),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Back to Home'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
