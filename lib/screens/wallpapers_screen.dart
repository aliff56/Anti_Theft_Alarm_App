import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../wallpaper_service.dart';
import '../theme.dart';
import 'package:google_fonts/google_fonts.dart';

class WallpapersScreen extends StatefulWidget {
  const WallpapersScreen({Key? key}) : super(key: key);

  @override
  State<WallpapersScreen> createState() => _WallpapersScreenState();
}

class _WallpapersScreenState extends State<WallpapersScreen> {
  static List<Wallpaper>? _wallpapersCache;
  List<Wallpaper> _wallpapers = [];
  bool _isLoading = true;
  bool _hasError = false;
  final int _perPage = 80;

  @override
  void initState() {
    super.initState();
    if (_wallpapersCache != null) {
      _wallpapers = _wallpapersCache!;
      _isLoading = false;
      _hasError = false;
      setState(() {});
    } else {
      _loadWallpapers();
    }
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
        _wallpapersCache = wallpapers;
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
      appBar: AppBar(
        title: Text(
          'Choose Wallpaper',
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF213B44),
        elevation: 0,
      ),
      extendBodyBehindAppBar: false,
      body: Container(
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
        child: _isLoading
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
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
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
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
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
                // You may want to import and use your _AnimatedTick widget here
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
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
    await Future.delayed(const Duration(milliseconds: 1200));
    if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
      Navigator.of(dialogContext!).pop();
    }
  }

  Future<void> _setWallpaper(BuildContext context, int location) async {
    try {
      final response = await http.get(Uri.parse(wallpaper.url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/temp_wallpaper.jpg').create();
        await file.writeAsBytes(bytes);
        final wallpaperManager = WallpaperManagerFlutter();
        bool result = await wallpaperManager.setWallpaper(file, location);
        if (context.mounted && result) {
          Navigator.of(context).pop();
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
        backgroundColor: const Color(0xFF213B44),
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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF213B44),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _showSetOptions(context),
                  child: const Text('Set as Wallpaper'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
