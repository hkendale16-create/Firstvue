import 'package:flutter_test/flutter_test.dart';
import 'package:firstvue/config/media_config.dart';
import 'package:firstvue/services/media_storage_service.dart';

void main() {
  test('external and absolute http paths pass through createReadUrl', () async {
    final external = await MediaStorageService.createReadUrl(
      bucket: MediaBucket.profile,
      path: 'https://picsum.photos/seed/fvdemo_av_1/800/800',
      provider: MediaStorageProvider.external,
    );
    expect(external, startsWith('https://'));

    final inferred = await MediaStorageService.createReadUrl(
      bucket: MediaBucket.profile,
      path: 'https://example.com/demo.jpg',
      provider: MediaStorageProvider.supabase,
    );
    expect(inferred, 'https://example.com/demo.jpg');

    expect(MediaStorageProvider.parse('external'), MediaStorageProvider.external);
  });
}
