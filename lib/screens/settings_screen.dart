import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../widgets/custom_switch.dart';
import '../widgets/rate_us_dialog.dart';
import '../widgets/exit_confirm_dialog.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _timerEnabled = false;
  bool _autoCloseEnabled = false;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

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
      const platform = MethodChannel('antitheft_service');
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
        backgroundColor: const Color(0xFF23414D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.urbanist(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
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
                        children: [
                          const Icon(Icons.alarm, color: Color(0xFF23414D)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Set timer to deactivate alarm',
                              style: GoogleFonts.poppins(
                                color: Color(0xFF23414D),
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          CustomSwitch(
                            value: _timerEnabled,
                            onChanged: (v) async {
                              setState(() => _timerEnabled = v);
                              await _saveSettings();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'If the alarm feature is active, it will\nbe turned off at:',
                        style: GoogleFonts.poppins(
                          color: Color(0xFFB0B6B9),
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
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
                                    timePickerTheme: const TimePickerThemeData(
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
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
                      const Icon(Icons.logout, color: Color(0xFF23414D)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Auto-close app after activation',
                          style: GoogleFonts.poppins(
                            color: Color(0xFF23414D),
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                          ),
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
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      _settingsTile(
                        'Share App',
                        Icons.chevron_right,
                        leading: Icons.ios_share_outlined,
                      ),
                      _settingsTile(
                        'Rate us',
                        Icons.chevron_right,
                        leading: Icons.star_outline,
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
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: leading != null
              ? Icon(leading, color: const Color(0xFF23414D))
              : null,
          title: Text(
            label,
            style: GoogleFonts.poppins(
              color: Color(0xFF23414D),
              fontWeight: FontWeight.w600,
              fontSize: 17,
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
        if (label != 'Exit') const Divider(height: 1, color: Color(0xFFE0E0E0)),
      ],
    );
  }
}
