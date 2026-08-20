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

    test('accepts a direct index URL and removes query and fragment', () {
      expect(
        RulesRepositoryConfig.normalizeForStorage(
          'https://example.com/rules/index.json?cache=1#catalog',
        ),
        'https://example.com/rules/',
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
  });
}
