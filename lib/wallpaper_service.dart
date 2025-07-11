import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class WallpaperService {
  static const String _cacheKey = 'wallpapers_cache';
  static const String _cacheTimestampKey = 'wallpapers_cache_timestamp';
  static const String _cacheDir = 'wallpapers_cache';

  // Pexels API configuration
  static const String _apiKey =
      'PdNoZxYyUiuiiGKokg42pstH1MRFaljLLKvZSLheF1T1EkyrBgrUsO8z';
  static const String _baseUrl = 'https://api.pexels.com/v1';
  static const String _searchEndpoint = '/search';

  static Future<List<Wallpaper>> getWallpapers({
    String query = 'nature photography',
    int page = 1,
    int perPage = 16,
  }) async {
    try {
      // // Check if we have cached wallpapers
      // final cachedWallpapers = await _getCachedWallpapers();
      // if (cachedWallpapers.isNotEmpty) {
      //   return cachedWallpapers;
      // }

      // If no cache, fetch from API
      final wallpapers = await _fetchWallpapersFromApi(
        query: query,
        page: page,
        perPage: perPage,
      );
      // if (wallpapers.isNotEmpty) {
      //   await _cacheWallpapers(wallpapers);
      // }

      return wallpapers;
    } catch (e) {
      print('Error getting wallpapers: $e');
      // Return empty list if both API and cache fail
      return [];
    }
  }

  static Future<List<Wallpaper>> loadMoreWallpapers({
    String query = 'nature photography',
    int page = 1,
    int perPage = 16,
  }) async {
    try {
      // final newWallpapers = await _fetchWallpapersFromApi(query: query, page: page, perPage: perPage);
      // final cachedWallpapers = await _getCachedWallpapers();
      // final combined = [...cachedWallpapers, ...newWallpapers];
      // await _cacheWallpapers(combined);
      // return combined;
      // Instead, just fetch the next page and append in the UI
      final wallpapers = await _fetchWallpapersFromApi(
        query: query,
        page: page,
        perPage: perPage,
      );
      return wallpapers;
    } catch (e) {
      print('Error loading more wallpapers: $e');
      // return await _getCachedWallpapers();
      return [];
    }
  }

  static Future<List<Wallpaper>> _fetchWallpapersFromApi({
    String query = 'nature photography',
    int page = 1,
    int perPage = 16,
  }) async {
    try {
      // Build the API URL with parameters
      final uri = Uri.parse('$_baseUrl$_searchEndpoint').replace(
        queryParameters: {
          'query': query,
          'per_page': perPage.toString(),
          'page': page.toString(),
          'orientation': 'portrait',
          'size': 'medium',
        },
      );

      final response = await http.get(uri, headers: {'Authorization': _apiKey});

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> photos = data['photos'] ?? [];
        final List<Wallpaper> wallpapers = [];

        for (int i = 0; i < photos.length; i++) {
          final item = photos[i];
          final src = item['src'] ?? {};

          wallpapers.add(
            Wallpaper(
              id: item['id']?.toString() ?? i.toString(),
              url: src['original'] ?? '',
              author: item['photographer'] ?? 'Unknown',
              width: item['width'] ?? 1920,
              height: item['height'] ?? 1080,
            ),
          );
        }

        return wallpapers;
      } else {
        throw Exception('Failed to load wallpapers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching wallpapers: $e');
    }
  }

  static Future<List<Wallpaper>> _getCachedWallpapers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);

      if (cachedData != null) {
        final List<dynamic> data = json.decode(cachedData);
        return data.map((item) => Wallpaper.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error reading cached wallpapers: $e');
    }

    return [];
  }

  static Future<void> _cacheWallpapers(List<Wallpaper> wallpapers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wallpapersJson = wallpapers.map((w) => w.toJson()).toList();
      await prefs.setString(_cacheKey, json.encode(wallpapersJson));
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      print('Error caching wallpapers: $e');
    }
  }

  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);

      // Also clear cached files
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  static Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$_cacheDir');
  }

  static Future<bool> hasCachedWallpapers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cacheKey) != null;
    } catch (e) {
      return false;
    }
  }
}

class Wallpaper {
  final String id;
  final String url;
  final String author;
  final int width;
  final int height;

  Wallpaper({
    required this.id,
    required this.url,
    required this.author,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'author': author,
      'width': width,
      'height': height,
    };
  }

  factory Wallpaper.fromJson(Map<String, dynamic> json) {
    return Wallpaper(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      author: json['author'] ?? 'Unknown',
      width: json['width'] ?? 1920,
      height: json['height'] ?? 1080,
    );
  }
}
