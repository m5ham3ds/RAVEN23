import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/quickjs/js_bootstrap.dart';
import 'package:raven23/video_providers/unified/quickjs/quickjs_extension_settings.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';

void main() {
  group('QuickJS settings schema', () {
    test('normalizes bool, enum, multiEnum, text and number schemas', () {
      final schema = QuickJsSettingsSchema.parse(<Object?>[
        <String, Object?>{
          'key': 'subtitles',
          'label': 'Include subtitles',
          'type': 'bool',
          'default': true,
        },
        <String, Object?>{
          'key': 'audioLanguage',
          'label': 'Audio language',
          'type': 'enum',
          'default': 'auto',
          'options': <Object?>[
            <String, Object?>{'value': 'auto', 'label': 'Detect automatically'},
            <String, Object?>{'value': 'en', 'label': 'English'},
          ],
        },
        <String, Object?>{
          'key': 'mirrors',
          'label': 'Mirrors',
          'type': 'multiEnum',
          'default': <String>['one'],
          'options': <Object?>[
            <String, Object?>{'value': 'one', 'label': 'Mirror One'},
            <String, Object?>{'value': 'two', 'label': 'Mirror Two'},
          ],
        },
        <String, Object?>{
          'key': 'token',
          'label': 'API token',
          'type': 'password',
          'required': true,
          'default': 'secret',
        },
        <String, Object?>{
          'key': 'timeout',
          'label': 'Timeout',
          'type': 'number',
          'min': 5000,
          'max': 30000,
          'default': 12000,
        },
      ]);

      expect(schema.fields, hasLength(5));
      expect(schema.fields[0].type, QuickJsSettingType.boolean);
      expect(schema.fields[1].type, QuickJsSettingType.select);
      expect(schema.fields[2].type, QuickJsSettingType.multiSelect);
      expect(schema.fields[3].sensitive, isTrue);
      expect(schema.fields[3].type, QuickJsSettingType.text);
      expect(schema.fields[4].coerce('16000'), 16000);
      expect(schema.fields[4].coerce(40000), isNull);
      expect(schema.fields[1].coerce('not-an-option'), isNull);
    });

    test(
      'ignores unsupported, duplicate and oversized schema fields safely',
      () {
        final schema = QuickJsSettingsSchema.parse(<Object?>[
          <String, Object?>{
            'key': 'mode',
            'label': 'Mode',
            'type': 'enum',
            'options': ['a'],
          },
          <String, Object?>{
            'key': 'mode',
            'label': 'Duplicate',
            'type': 'text',
          },
          <String, Object?>{
            'key': 'custom',
            'label': 'Custom',
            'type': 'javascript',
          },
        ]);
        expect(schema.fields, hasLength(1));
        expect(schema.warnings, hasLength(2));
        expect(
          () => QuickJsSettingsSchema.parse(
            List<Object?>.filled(33, <String, Object?>{}),
          ),
          throwsFormatException,
        );
        final oversized = <Object?>[
          for (var field = 0; field < 20; field++)
            <String, Object?>{
              'key': 'field$field',
              'label': 'Field $field',
              'type': 'enum',
              'options': <Object?>[
                for (var option = 0; option < 50; option++)
                  <String, Object?>{
                    'value': '${List<String>.filled(256, 'x').join()}$option',
                    'label': 'Option $option',
                  },
              ],
            },
        ];
        expect(
          () => QuickJsSettingsSchema.parse(oversized),
          throwsFormatException,
        );
      },
    );

    test('integer settings reject fractional values', () {
      final schema = QuickJsSettingsSchema.parse(<Object?>[
        <String, Object?>{
          'key': 'page',
          'label': 'Page',
          'type': 'integer',
          'default': 1,
        },
      ]);
      expect(schema.fields.single.coerce(2), 2);
      expect(schema.fields.single.coerce(2.5), isNull);
    });

    test(
      'does not invent a default for a required number without constraints',
      () {
        final schema = QuickJsSettingsSchema.parse(<Object?>[
          <String, Object?>{
            'key': 'timeout',
            'label': 'Timeout',
            'type': 'number',
            'required': true,
          },
        ]);
        expect(schema.fields.single.defaultValue, isNull);
        expect(
          schema.missingRequired(<String, Object?>{'timeout': null}),
          <String>['Timeout'],
        );
      },
    );

    test(
      'does not auto-select a required enum without an explicit default',
      () {
        final schema = QuickJsSettingsSchema.parse(<Object?>[
          <String, Object?>{
            'key': 'region',
            'label': 'Region',
            'type': 'enum',
            'required': true,
            'options': <String>['auto', 'us', 'eu'],
          },
        ]);
        expect(schema.fields.single.defaultValue, isNull);
        expect(
          schema.missingRequired(<String, Object?>{'region': null}),
          <String>['Region'],
        );
        expect(schema.fields.single.coerce('us'), 'us');
      },
    );

    test('enforces required fields and supported validation rules', () {
      final schema = QuickJsSettingsSchema.parse(<Object?>[
        <String, Object?>{
          'key': 'apiUrl',
          'label': 'API URL',
          'type': 'text',
          'required': true,
          'validation': 'url',
        },
        <String, Object?>{
          'key': 'email',
          'label': 'Email',
          'type': 'text',
          'validation': 'email',
        },
        <String, Object?>{
          'key': 'optionalUrl',
          'label': 'Optional URL',
          'type': 'text',
          'validation': 'url',
        },
      ]);
      expect(schema.fields[0].coerce(''), isNull);
      expect(
        schema.fields[0].coerce('https://example.com/path'),
        'https://example.com/path',
      );
      expect(schema.fields[0].coerce('file:///tmp'), isNull);
      expect(schema.fields[1].coerce('not-an-email'), isNull);
      expect(schema.fields[1].coerce('user@example.com'), 'user@example.com');
      expect(schema.fields[2].coerce(''), '');
    });
  });

  group('QuickJS secure settings persistence', () {
    late _MemoryVault vault;
    late QuickJsExtensionSettingsStore store;

    setUp(() {
      vault = _MemoryVault();
      store = QuickJsExtensionSettingsStore(vault: vault);
    });

    test('persists values per repository source identity', () async {
      const sourceA = SourceManifest(
        id: 'sample',
        name: 'Sample A',
        repositoryUrl: 'https://repo-a.example/index.json',
        version: '1.0',
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );
      const sourceB = SourceManifest(
        id: 'sample',
        name: 'Sample B',
        repositoryUrl: 'https://repo-b.example/index.json',
        version: '1.0',
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );
      final schema = QuickJsSettingsSchema.parse(<Object?>[
        <String, Object?>{
          'key': 'token',
          'label': 'Token',
          'type': 'password',
          'default': '',
        },
        <String, Object?>{
          'key': 'mode',
          'label': 'Mode',
          'type': 'enum',
          'default': 'one',
          'options': ['one', 'two'],
        },
      ]);

      await store.save(sourceA, schema, <String, Object?>{
        'token': 'A-secret',
        'mode': 'two',
      });
      await store.save(sourceB, schema, <String, Object?>{
        'token': 'B-secret',
        'mode': 'one',
      });

      expect((await store.load(sourceA, schema))['token'], 'A-secret');
      expect((await store.load(sourceB, schema))['token'], 'B-secret');
      expect(vault.values, hasLength(2));
      expect(vault.values.values.join('|'), contains('A-secret'));
      expect(vault.values.values.join('|'), contains('B-secret'));
      expect(
        vault.values.keys.every(
          (key) => RegExp(
            r'^raven23\.quickjs\.settings\.v1\.[a-f0-9]{64}$',
          ).hasMatch(key),
        ),
        isTrue,
      );
    });

    test(
      'schema changes preserve compatible keys and discard removed or invalid ones',
      () async {
        const source = SourceManifest(
          id: 'schema-change',
          name: 'Schema Change',
          repositoryUrl: 'https://repo.example/index.json',
          version: '1.0',
          engine: SourceEngineDescriptor(
            rawType: 'javascript',
            kind: SourceEngineKind.javascript,
          ),
        );
        final oldSchema = QuickJsSettingsSchema.parse(<Object?>[
          <String, Object?>{
            'key': 'language',
            'label': 'Language',
            'type': 'text',
            'default': 'en',
          },
          <String, Object?>{
            'key': 'removed',
            'label': 'Removed',
            'type': 'text',
            'default': 'legacy',
          },
        ]);
        await store.save(source, oldSchema, <String, Object?>{
          'language': 'ar',
          'removed': 'old value',
        });
        store.invalidate(source);

        const updated = SourceManifest(
          id: 'schema-change',
          name: 'Schema Change',
          repositoryUrl: 'https://repo.example/index.json',
          version: '2.0',
          engine: SourceEngineDescriptor(
            rawType: 'javascript',
            kind: SourceEngineKind.javascript,
          ),
        );
        final newSchema = QuickJsSettingsSchema.parse(<Object?>[
          <String, Object?>{
            'key': 'language',
            'label': 'Language',
            'type': 'text',
            'default': 'en',
          },
          <String, Object?>{
            'key': 'quality',
            'label': 'Quality',
            'type': 'enum',
            'default': '720p',
            'options': ['720p', '1080p'],
          },
        ]);
        final values = await store.load(updated, newSchema);
        expect(values, <String, Object?>{'language': 'ar', 'quality': '720p'});
        final stored = vault.values.values.single;
        expect(stored, isNot(contains('removed')));
        expect(stored, contains('2.0'));
      },
    );

    test(
      'rejects secure storage payloads larger than the configured bound',
      () async {
        const source = SourceManifest(
          id: 'large-settings',
          name: 'Large settings',
          repositoryUrl: 'https://repo.example/index.json',
          engine: SourceEngineDescriptor(
            rawType: 'javascript',
            kind: SourceEngineKind.javascript,
          ),
        );
        final schema = QuickJsSettingsSchema.parse(<Object?>[
          for (var index = 0; index < 20; index++)
            <String, Object?>{
              'key': 'field$index',
              'label': 'Field $index',
              'type': 'text',
              'maxLength': 4096,
            },
        ]);
        await expectLater(
          store.save(source, schema, <String, Object?>{
            for (var index = 0; index < 20; index++)
              'field$index': List<String>.filled(4096, 'x').join(),
          }),
          throwsFormatException,
        );
        expect(vault.values, isEmpty);
      },
    );

    test(
      'rejects invalid required values without overwriting saved settings',
      () async {
        const source = SourceManifest(
          id: 'required',
          name: 'Required',
          repositoryUrl: 'https://repo.example/index.json',
          engine: SourceEngineDescriptor(
            rawType: 'javascript',
            kind: SourceEngineKind.javascript,
          ),
        );
        final schema = QuickJsSettingsSchema.parse(<Object?>[
          <String, Object?>{
            'key': 'apiKey',
            'label': 'API key',
            'type': 'text',
            'required': true,
          },
        ]);
        await expectLater(
          store.save(source, schema, <String, Object?>{'apiKey': ''}),
          throwsFormatException,
        );
        expect(vault.values, isEmpty);
      },
    );
  });

  test('sensitive settings are removed from provider console messages', () {
    expect(
      redactQuickJsSensitiveValues(
        'token=private-token and region=region-token',
        <Object?>[
          'private-token',
          <String>['region-token'],
        ],
      ),
      'token=[REDACTED] and region=[REDACTED]',
    );
  });

  test(
    'provider wrapper gives every extension its own lexical settings scope',
    () {
      final wrapped = wrapProviderSource(
        'source-a',
        'function getSettings(){return [];}',
      );
      expect(wrapped, contains('var __settings = {};'));
      expect(
        wrapped,
        contains("globalThis.__providerSettingsSetters['source-a']"),
      );
    },
  );
}

class _MemoryVault implements QuickJsSettingsVault {
  final Map<String, String> values = <String, String>{};
  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
