import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/custom_switch.dart';
import '../widgets/rate_us_dialog.dart';
import '../widgets/exit_confirm_dialog.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _timerEnabled = false;
  bool _autoCloseEnabled = false;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  static const platform = MethodChannel('antitheft_service');

  Future<bool> _hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool granted = await platform.invokeMethod(
        'canScheduleExactAlarms',
      );
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<void> _requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await platform.invokeMethod('openExactAlarmSettings');
    } catch (_) {}
  }

  Future<void> _handleTimerToggle(bool v) async {
    if (v) {
      final hasPermission = await _hasExactAlarmPermission();
      if (hasPermission) {
        setState(() => _timerEnabled = true);
        await _saveSettings();
        return;
      }
      final goToSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Permission Required',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Color(0xFF213B44),
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'To use the timer, please allow "Schedule exact alarm" for this app in system settings.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Color(0xFF213B44),
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF213B44),
                          foregroundColor: Colors.white,
                          textStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.center,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx, true);
                          await _requestExactAlarmPermission();
                        },
                        child: const Text('Open Settings'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF213B44),
                          side: const BorderSide(
                            color: Color(0xFF213B44),
                            width: 2,
                          ),
                          textStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.center,
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      // After returning from settings, check again
      if (goToSettings == true) {
        final granted = await _hasExactAlarmPermission();
        if (granted) {
          setState(() => _timerEnabled = true);
          await _saveSettings();
          return;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission not granted. Timer not enabled.'),
            ),
          );
          setState(() => _timerEnabled = false);
          return;
        }
      } else {
        setState(() => _timerEnabled = false);
        return;
      }
    }
    setState(() => _timerEnabled = false);
    await _saveSettings();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _timerEnabled = prefs.getBool('auto_disarm_enabled') ?? false;
      final hour = prefs.getInt('auto_disarm_hour') ?? 9;
      final minute = prefs.getInt('auto_disarm_minute') ?? 0;
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
      _autoCloseEnabled = prefs.getBool('auto_close_after_activation') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_disarm_enabled', _timerEnabled);
    await prefs.setInt('auto_disarm_hour', _selectedTime.hour);
    await prefs.setInt('auto_disarm_minute', _selectedTime.minute);
    // Schedule/cancel native alarm on Android
    if (Platform.isAndroid) {
      if (_timerEnabled) {
        await platform.invokeMethod('scheduleAutoDisarm', {
          'hour': _selectedTime.hour,
          'minute': _selectedTime.minute,
        });
      } else {
        await platform.invokeMethod('cancelAutoDisarm');
      }
    }
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    final min = t.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF23414D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF213B44),
        elevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 0,
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 2),
            Text(
              'Settings',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 22,
              ),
            ),
          ],
        ),
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
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Image.asset(
                              'assets/icons/timer.png',
                              width: 28,
                              height: 28,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Set de-activation time',
                                  style: GoogleFonts.poppins(
                                    color: Color(0xFF23414D),
                                    fontWeight: FontWeight.w400,
                                    fontSize: 15,
                                  ),
                                ),

                                Text(
                                  'Alarm will auto-turn off :',
                                  textAlign: TextAlign.left,
                                  style: GoogleFonts.poppins(
                                    color: Colors.black.withOpacity(0.75),
                                    fontWeight: FontWeight.w300,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),

                          CustomSwitch(
                            value: _timerEnabled,
                            onChanged: (v) async {
                              await _handleTimerToggle(v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Container(
                          width: 200,
                          decoration: BoxDecoration(
                            color: Color(0xFF23414D),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime,
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFF254451),
                                        onPrimary: Colors.white,
                                        onSurface: Colors.white,
                                        surface: Colors.transparent,
                                      ),
                                      dialogBackgroundColor: Colors.transparent,
                                      timePickerTheme:
                                          const TimePickerThemeData(
                                            dialHandColor: Colors.black,
                                          ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                    child: child == null
                                        ? const SizedBox.shrink()
                                        : Dialog(
                                            backgroundColor: Colors.transparent,
                                            insetPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 32,
                                                  vertical: 32,
                                                ),
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Color(0xFF2C5364),
                                                    Color(0xFF203A43),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(16),
                                                ),
                                              ),
                                              child: SizedBox(
                                                height: 550,
                                                child: child,
                                              ),
                                            ),
                                          ),
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() => _selectedTime = picked);
                                await _saveSettings();
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _formatTime(_selectedTime),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icons/auto_exit.png',
                        width: 26,
                        height: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto Close',
                              style: GoogleFonts.poppins(
                                color: Color(0xFF23414D),
                                fontWeight: FontWeight.w400,
                                fontSize: 15,
                              ),
                            ),

                            Text(
                              'App will auto-close after activation',
                              textAlign: TextAlign.left,
                              style: GoogleFonts.poppins(
                                color: Colors.black.withOpacity(0.75),
                                fontWeight: FontWeight.w300,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CustomSwitch(
                        value: _autoCloseEnabled,
                        onChanged: (v) async {
                          setState(() => _autoCloseEnabled = v);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('auto_close_after_activation', v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _settingsTile(
                        'Share App',
                        Icons.chevron_right,
                        leading: Icons.ios_share_outlined,
                      ),
                      _settingsTile(
                        'Rate us',
                        Icons.chevron_right,
                        leading: Icons.thumb_up_outlined,
                      ),
                      _settingsTile(
                        'Feedback',
                        Icons.chevron_right,
                        leading: Icons.feedback_outlined,
                      ),
                      _settingsTile(
                        'Share with friends',
                        Icons.chevron_right,
                        leading: Icons.group_outlined,
                      ),
                      _settingsTile(
                        'Exit',
                        Icons.chevron_right,
                        leading: Icons.exit_to_app_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsTile(String label, IconData icon, {IconData? leading}) {
    final noShadowLabels = [
      'Share App',
      'Rate us',
      'Feedback',
      'Share with friends',
      'Exit',
    ];
    return Column(
      children: [
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: noShadowLabels.contains(label) ? [] : kCardShadow,
              borderRadius: BorderRadius.circular(6),
              color: Colors.white,
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
              dense: true,
              minVerticalPadding: 0,
              leading: leading != null
                  ? Icon(leading, color: const Color(0xFF23414D))
                  : null,
              title: Text(
                label,
                style: GoogleFonts.poppins(
                  color: Color(0xFF23414D),
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
              trailing: Icon(icon, color: const Color(0xFF23414D)),
              onTap: label == 'Rate us'
                  ? () => showDialog(
                      context: context,
                      builder: (context) => const RateUsDialog(),
                    )
                  : label == 'Exit'
                  ? () => showDialog(
                      context: context,
                      builder: (context) => const ExitConfirmDialog(),
                    )
                  : () {},
            ),
          ),
        ),
        if (!noShadowLabels.contains(label))
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
      ],
    );
  }
}
