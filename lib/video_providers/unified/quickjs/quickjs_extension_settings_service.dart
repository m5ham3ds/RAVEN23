import 'package:flutter/foundation.dart';

import '../source_manifest.dart';
import 'quickjs_extension_settings.dart';
import 'quickjs_exception.dart';
import 'quickjs_provider_runtime.dart';

class QuickJsSourceSettingsSnapshot {
  const QuickJsSourceSettingsSnapshot({
    required this.schema,
    required this.values,
  });

  final QuickJsSettingsSchema schema;
  final Map<String, Object?> values;
  bool get hasSettings => schema.fields.isNotEmpty;
}

/// Reads only the extension's declared getSettings() schema and persists
/// validated values under a hash of its stable repository/source identity.
class QuickJsExtensionSettingsService {
  QuickJsExtensionSettingsService({
    QuickJsProviderRuntime? runtime,
    QuickJsExtensionSettingsStore? store,
  }) : _runtime = runtime ?? QuickJsProviderRuntime(),
       _ownsRuntime = runtime == null,
       _store = store ?? QuickJsExtensionSettingsStore.instance;

  final QuickJsProviderRuntime _runtime;
  final bool _ownsRuntime;
  final QuickJsExtensionSettingsStore _store;

  Future<QuickJsSourceSettingsSnapshot> load(SourceManifest source) async {
    if (source.engine.kind != SourceEngineKind.javascript) {
      throw ArgumentError(
        'Settings are available only for QuickJS extensions.',
      );
    }
    try {
      Object? raw;
      try {
        raw = await _runtime.call(
          source,
          'getSettings',
          const <Object?>[],
          timeout: const Duration(seconds: 12),
        );
      } on JsRuntimeException catch (error) {
        if (!error.message.contains('missing method: getSettings')) rethrow;
        raw = null;
      }
      final schema = QuickJsSettingsSchema.parse(raw);
      final values = await _store.load(source, schema);
      return QuickJsSourceSettingsSnapshot(schema: schema, values: values);
    } finally {
      if (_ownsRuntime) _runtime.dispose();
    }
  }

  Future<void> save(
    SourceManifest source,
    QuickJsSettingsSchema schema,
    Map<String, Object?> values,
  ) => _store.save(source, schema, values);

  Future<void> reset(SourceManifest source, QuickJsSettingsSchema schema) =>
      _store.reset(source, schema);

  @visibleForTesting
  QuickJsExtensionSettingsStore get storeForTesting => _store;
}
