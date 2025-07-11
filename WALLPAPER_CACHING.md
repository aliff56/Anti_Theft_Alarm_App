# Wallpaper Caching System

This document explains how the wallpaper caching system works in the Anti-Theft app.

## Overview

The wallpaper system now uses an API-based approach with intelligent caching to minimize API requests and provide a smooth user experience.

## How It Works

### 1. First Time Access
- When a user opens the wallpaper section for the first time, the app checks if wallpapers are cached locally
- If no cache exists, it makes an API request to fetch 10 wallpapers
- The wallpapers are then stored locally using SharedPreferences and cached network images

### 2. Subsequent Access
- On subsequent visits to the wallpaper section, the app loads wallpapers from the local cache
- No API requests are made unless the user manually refreshes
- This significantly reduces API usage and improves loading speed

### 3. Manual Refresh
- Users can tap the refresh button in the app bar to clear the cache and fetch new wallpapers
- This allows users to get fresh wallpapers when desired

## API Configuration

The system currently uses the Pexels API (https://api.pexels.com/) which provides high-quality mobile wallpapers. The API is configured with the following parameters:

- **Query**: "mobile wallpapers" - Searches for mobile-optimized wallpapers
- **Per Page**: 10 - Number of wallpapers per request
- **Page**: 1 - First page of results
- **Orientation**: "portrait" - Portrait-oriented wallpapers for mobile devices
- **Size**: "medium" - Medium-sized images for optimal performance

### Current API Settings:

```dart
// In lib/wallpaper_service.dart
static const String _apiKey = 'PdNoZxYyUiuiiGKokg42pstH1MRFaljLLKvZSLheF1T1EkyrBgrUsO8z';
static const String _baseUrl = 'https://api.pexels.com/v1';
static const String _searchEndpoint = '/search';
```

### Alternative APIs you can use:

1. **Unsplash API** (requires API key):
   ```dart
   static const String _apiUrl = 'https://api.unsplash.com/photos/random?count=10&client_id=YOUR_API_KEY';
   ```

2. **Picsum Photos API** (free, no API key):
   ```dart
   static const String _apiUrl = 'https://picsum.photos/v2/list?page=1&limit=10';
   ```

3. **Your own API endpoint**:
   ```dart
   static const String _apiUrl = 'https://your-api.com/wallpapers';
   ```

## File Structure

- `lib/wallpaper_service.dart` - Handles API calls and caching logic
- `lib/main.dart` - Updated WallpapersScreen to use the new service

## Benefits

1. **Reduced API Usage**: Only makes requests when necessary
2. **Faster Loading**: Cached images load instantly
3. **Offline Support**: Works even without internet after initial load
4. **User Control**: Users can refresh to get new wallpapers
5. **Error Handling**: Graceful fallbacks when API is unavailable

## Technical Details

### Caching Strategy
- **SharedPreferences**: Stores wallpaper metadata (URLs, IDs, etc.)
- **CachedNetworkImage**: Handles image caching and display
- **Automatic Cleanup**: Old cache can be cleared manually

### Error Handling
- Network errors are handled gracefully
- Loading states are shown to users
- Retry mechanisms are available
- Fallback to empty state if needed

## Customization

To customize the wallpaper system:

1. **Change API**: Modify `_apiUrl` in `WallpaperService`
2. **Adjust Cache Size**: Modify the number of wallpapers fetched
3. **Add Categories**: Extend the service to support wallpaper categories
4. **Custom UI**: Modify the grid layout and preview screen

## API Rate Limits

The current implementation is designed to work within typical API rate limits:
- Only 10 wallpapers per request
- Cached indefinitely until manual refresh
- No automatic background refresh

This approach ensures you stay well within most free API limits while providing a great user experience. 