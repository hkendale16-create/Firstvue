import 'package:firstvue/services/search_autocomplete_service.dart';
import 'package:firstvue/services/username_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UsernameService autocomplete helpers', () {
    test('isUsernameQuery detects @-prefixed queries', () {
      expect(UsernameService.isUsernameQuery('@jo'), isTrue);
      expect(UsernameService.isUsernameQuery('  @kendale  '), isTrue);
      expect(UsernameService.isUsernameQuery('john'), isFalse);
      expect(UsernameService.isUsernameQuery('#tag'), isFalse);
    });

    test('autocompletePrefix strips @ and normalizes partial handles', () {
      expect(UsernameService.autocompletePrefix('@jo'), 'jo');
      expect(UsernameService.autocompletePrefix('@JO_'), 'jo_');
      expect(UsernameService.autocompletePrefix('@'), isNull);
      expect(UsernameService.autocompletePrefix('john'), isNull);
    });

    test('normalize still requires full valid handles', () {
      expect(UsernameService.normalize('@jo'), isNull);
      expect(UsernameService.normalize('@joe'), 'joe');
    });
  });

  group('SearchAutocompleteService.shouldSearch', () {
    test('requires @ plus at least one character for handle search', () {
      expect(SearchAutocompleteService.shouldSearch('@'), isFalse);
      expect(SearchAutocompleteService.shouldSearch('@j'), isTrue);
      expect(SearchAutocompleteService.shouldSearch('@jo'), isTrue);
    });

    test('requires two characters for general search', () {
      expect(SearchAutocompleteService.shouldSearch('j'), isFalse);
      expect(SearchAutocompleteService.shouldSearch('jo'), isTrue);
    });
  });
}
