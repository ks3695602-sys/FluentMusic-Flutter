import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Persistent cache manager for album and track cover images.
///
/// It stores covers in the app cache directory and keeps them for a year,
/// which is what the copied artwork widgets expect from Mornye's manager.
class CoverCacheManager {
  CoverCacheManager._();

  static const String _cacheKey = 'coverImageCache';
  static const int _maxCacheObjects = 1000;
  static const Duration _maxCacheAge = Duration(days: 365);

  static CacheManager? _instance;

  static CacheManager get instance => _instance ??= CacheManager(
    Config(
      _cacheKey,
      stalePeriod: _maxCacheAge,
      maxNrOfCacheObjects: _maxCacheObjects,
    ),
  );

  static Future<void> clearCache() async {
    await instance.emptyCache();
  }
}