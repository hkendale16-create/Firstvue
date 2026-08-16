import '../approved_businesses_service.dart';
import '../entity_details_service.dart';
import '../media_storage_service.dart';
import 'cache_ttls.dart';
import 'feed_page_cache.dart';
import 'ttl_memory_cache.dart';

/// Central clear for Phase 2 device caches (logout / account switch).
class DeviceCacheHub {
  DeviceCacheHub._();

  static void clearAll() {
    DeviceCaches.profiles.clear();
    ApprovedBusinessesService.clearCache();
    EntityDetailsService.clearCache();
    FeedPageCache.clear();
    MediaStorageService.clearCaches();
  }
}

/// Shared profile-card cache (used by [ProfileCards]).
class DeviceCaches {
  DeviceCaches._();

  static final profiles = TtlMemoryCache<Map<String, dynamic>>(
    ttl: CacheTtls.profile,
    maxEntries: 400,
    name: 'profiles',
  );
}
