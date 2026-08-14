import 'package:firstvue/models/post_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('entity posting identity is distinct from the personal profile', () {
    const personal = PostIdentityOption.personal(displayName: 'Kendale');
    const business = PostIdentityOption(
      kind: PostIdentityKind.business,
      businessId: 'biz-1',
      label: 'Velvet Room',
      subtitle: 'Business',
    );
    expect(personal.isPersonal, isTrue);
    expect(business.isPersonal, isFalse);
    expect(business.storageKey, 'business:biz-1');
    expect(personal.storageKey, isNot(business.storageKey));
  });

  test('stored keys restore the selected entity, not the owner person', () {
    const options = [
      PostIdentityOption.personal(displayName: 'Kendale'),
      PostIdentityOption(
        kind: PostIdentityKind.business,
        businessId: 'biz-1',
        label: 'Velvet Room',
        subtitle: 'Business',
      ),
    ];
    final matched = PostIdentityOption.matchStoredKey(
      options,
      'business:biz-1',
    );
    expect(matched?.label, 'Velvet Room');
    expect(matched?.isPersonal, isFalse);
  });
}
