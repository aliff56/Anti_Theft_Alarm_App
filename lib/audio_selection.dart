import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioOption {
  final String fileName;
  final String label;
  final IconData icon;
  final String description;

  AudioOption(this.fileName, this.label, this.icon, this.description);
}

final List<AudioOption> audioOptions = [
  AudioOption('alarm.wav', 'Alarm', Icons.alarm, 'Classic alarm sound.'),
  AudioOption('alarm2.flac', 'Alarm 2', Icons.alarm_on, 'Alternative alarm.'),
  AudioOption('alert.wav', 'Alert', Icons.warning, 'Alert sound.'),
  AudioOption('bark.wav', 'Dog Bark', Icons.pets, 'Dog barking.'),
  AudioOption('police.mp3', 'Police', Icons.local_police, 'Police siren.'),
  AudioOption('siren.wav', 'Siren', Icons.notifications_active, 'Loud siren.'),
  AudioOption('siren2.wav', 'Siren 2', Icons.notifications, 'Another siren.'),
];

class AudioSelectionGrid extends StatelessWidget {
  final void Function(AudioOption, String loop, bool vibrate, bool flash)?
  onApply;
  final String? appliedAudio;
  final String? appliedLoop;
  final bool? appliedVibrate;
  final bool? appliedFlash;
  const AudioSelectionGrid({
    Key? key,
    this.onApply,
    this.appliedAudio,
    this.appliedLoop,
    this.appliedVibrate,
    this.appliedFlash,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Build rows of 3 cards each
    List<Widget> rows = [];
    for (int i = 0; i < audioOptions.length; i += 3) {
      final rowOptions = audioOptions.skip(i).take(3).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: rowOptions.map((option) {
              final isApplied = option.fileName == appliedAudio;
              return SizedBox(
                width: 120,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            height: 140,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  option.icon,
                                  size: 40,
                                  color: Colors.tealAccent,
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    option.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Center(
                                  child: Text(
                                    option.description,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 12,
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

class _AudioOptionDetailPageState extends State<AudioOptionDetailPage> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  late String _selectedLoop;
  bool _vibrate = false;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _selectedLoop = widget.appliedLoop ?? 'infinite';
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vibrate = prefs.getBool('selected_vibrate') ?? false;
      _flash = prefs.getBool('selected_flash') ?? false;
    });
  }

  @override
  void dispose() {
    _player.dispose();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.option.label,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        iconTheme: const IconThemeData(color: Colors.tealAccent),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.option.icon, size: 64, color: Colors.tealAccent),
            const SizedBox(height: 12),
            Text(
              widget.option.label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              widget.option.description,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(
                    _isPlaying ? Icons.stop : Icons.play_arrow,
                    color: Colors.black,
                  ),
                  label: Text(
                    _isPlaying ? 'Stop Preview' : 'Preview',
                    style: const TextStyle(color: Colors.black),
                  ),
                  onPressed: _preview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  child: Text(
                    widget.isApplied ? 'Applied' : 'Apply',
                    style: const TextStyle(color: Colors.black),
                  ),
                  onPressed: widget.isApplied
                      ? null
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
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Loop Duration:', style: const TextStyle(color: Colors.white)),
            Wrap(
              spacing: 8,
              children: [
                _loopButton('30s'),
                _loopButton('1m'),
                _loopButton('2m'),
                _loopButton('infinite'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: _vibrate,
                  onChanged: widget.isApplied
                      ? null
                      : (val) => setState(() => _vibrate = val ?? false),
                  activeColor: Colors.tealAccent,
                  checkColor: Colors.black,
                ),
                const Text(
                  'Vibrate on alarm',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: _flash,
                  onChanged: widget.isApplied
                      ? null
                      : (val) => setState(() => _flash = val ?? false),
                  activeColor: Colors.tealAccent,
                  checkColor: Colors.black,
                ),
                const Text(
                  'Flash Alert',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _loopButton(String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedLoop == label,
      onSelected: widget.isApplied
          ? null
          : (_) => setState(() => _selectedLoop = label),
    );
  }
}
