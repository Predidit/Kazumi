import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/config/rules_repository_config.dart';

void main() {
  group('RulesRepositoryConfig', () {
    test('uses the official repository when the setting is blank', () {
      expect(
        RulesRepositoryConfig.baseUri('   ').toString(),
        ApiEndpoints.pluginShop,
      );
    });

    test('normalizes a repository directory URL', () {
      expect(
        RulesRepositoryConfig.normalizeForStorage('https://example.com/rules'),
        'https://example.com/rules/',
      );
    });

    test('accepts a case-insensitive direct index URL', () {
      expect(
        RulesRepositoryConfig.normalizeForStorage(
          'https://example.com/rules/INDEX.JSON',
        ),
        'https://example.com/rules/',
      );
    });

    test('normalizes trailing and encoded index URL variants', () {
      expect(
        RulesRepositoryConfig.normalizeForStorage(
          'https://example.com/rules/index.json/',
        ),
        'https://example.com/rules/',
      );
      expect(
        RulesRepositoryConfig.normalizeForStorage(
          'https://example.com/rules/%69ndex.json',
        ),
        'https://example.com/rules/',
      );
    });

    test('accepts explicit directory URLs whose last segment contains dots',
        () {
      expect(
        RulesRepositoryConfig.normalizeForStorage(
          'https://example.com/rules/v1.2/',
        ),
        'https://example.com/rules/v1.2/',
      );
      expect(
        RulesRepositoryConfig.normalizeForStorage(
          'https://example.com/rules.d/',
        ),
        'https://example.com/rules.d/',
      );
    });

    test('normalizes official repository URLs back to the default setting', () {
      expect(
        RulesRepositoryConfig.normalizeForStorage(ApiEndpoints.pluginShop),
        isEmpty,
      );
      expect(
        RulesRepositoryConfig.normalizeForStorage(
          '${ApiEndpoints.pluginShop}index.json',
        ),
        isEmpty,
      );
      expect(
        RulesRepositoryConfig.isCustomRepository(ApiEndpoints.pluginShop),
        isFalse,
      );
      expect(
        RulesRepositoryConfig.isCustomRepository(
          'https://example.com/rules/',
        ),
        isTrue,
      );
    });

    test('resolves catalog and rule URLs from the same repository', () {
      const repository = 'https://example.com/rules/';
      expect(
        RulesRepositoryConfig.catalogUri(repository).toString(),
        'https://example.com/rules/index.json',
      );
      expect(
        RulesRepositoryConfig.ruleUri(repository, 'demo').toString(),
        'https://example.com/rules/demo.json',
      );
    });

    test('rejects non-HTTP repository URLs', () {
      expect(
        () => RulesRepositoryConfig.baseUri('file:///tmp/rules/'),
        throwsFormatException,
      );
      expect(
        () => RulesRepositoryConfig.baseUri('example.com/rules'),
        throwsFormatException,
      );
    });

    test('rejects URLs with credentials, query parameters or fragments', () {
      expect(
        () => RulesRepositoryConfig.baseUri(
          'https://user:pass@example.com/rules/',
        ),
        throwsFormatException,
      );
      expect(
        () => RulesRepositoryConfig.baseUri(
          'https://example.com/rules/index.json?cache=1',
        ),
        throwsFormatException,
      );
      expect(
        () => RulesRepositoryConfig.baseUri(
          'https://example.com/rules/#catalog',
        ),
        throwsFormatException,
      );
    });

    test('rejects file URLs and GitHub repository pages', () {
      expect(
        () => RulesRepositoryConfig.baseUri(
          'https://example.com/rules/catalog.json',
        ),
        throwsFormatException,
      );
      expect(
        () => RulesRepositoryConfig.baseUri(
          'https://github.com/example/rules',
        ),
        throwsFormatException,
      );
    });
  });
}
