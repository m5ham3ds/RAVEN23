import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../source_manifest.dart';

enum QuickJsSettingType { text, number, boolean, select, multiSelect }

class QuickJsSettingOption {
  const QuickJsSettingOption({required this.value, required this.label});
  final Object value;
  final String label;

  Map<String, Object> toJson() => <String, Object>{
    'value': value,
    'label': label,
  };
}

class QuickJsSettingField {
  const QuickJsSettingField({
    required this.key,
    required this.label,
    required this.type,
    required this.defaultValue,
    required this.required,
    required this.sensitive,
    this.description,
    this.min,
    this.max,
    this.maxLength = 2048,
    this.options = const <QuickJsSettingOption>[],
    this.validation,
  });

  final String key;
  final String label;
  final QuickJsSettingType type;
  final Object? defaultValue;
  final bool required;
  final bool sensitive;
  final String? description;
  final num? min;
  final num? max;
  final int maxLength;
  final List<QuickJsSettingOption> options;
  final String? validation;

  Object? coerce(Object? value) {
    switch (type) {
      case QuickJsSettingType.text:
        if (value is! String || value.length > maxLength) return null;
        if (value.isEmpty) return required ? null : '';
        if (required && value.trim().isEmpty) return null;
        if (validation == 'url') {
          final uri = Uri.tryParse(value);
          if (uri == null ||
              !const <String>{
                'http',
                'https',
              }.contains(uri.scheme.toLowerCase()) ||
              uri.host.isEmpty) {
            return null;
          }
        }
        if (validation == 'email' &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
          return null;
        }
        if (validation == 'integer' && int.tryParse(value) == null) return null;
        if (validation == 'number' && num.tryParse(value)?.isFinite != true) {
          return null;
        }
        return value;
      case QuickJsSettingType.number:
        final parsed = value is num
            ? value
            : num.tryParse(value?.toString() ?? '');
        if (parsed == null || !parsed.isFinite) return null;
        if (validation == 'integer' && parsed % 1 != 0) return null;
        if (min != null && parsed < min!) return null;
        if (max != null && parsed > max!) return null;
        return parsed;
      case QuickJsSettingType.boolean:
        return value is bool ? value : null;
      case QuickJsSettingType.select:
        return options.any((option) => option.value == value) ? value : null;
      case QuickJsSettingType.multiSelect:
        if (value is! List) return null;
        final valid = value
            .where((item) => options.any((option) => option.value == item))
            .toList();
        if (valid.length != value.length || (required && valid.isEmpty)) {
          return null;
        }
        return valid;
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'label': label,
    'type': type.name,
    'default': defaultValue,
    'required': required,
    'sensitive': sensitive,
    'description': description,
    'min': min,
    'max': max,
    'maxLength': maxLength,
    'options': options.map((option) => option.toJson()).toList(),
    'validation': validation,
  };
}

class QuickJsSettingsSchema {
  const QuickJsSettingsSchema({
    required this.fields,
    this.warnings = const <String>[],
  });

  final List<QuickJsSettingField> fields;
  final List<String> warnings;

  String get fingerprint => sha256
      .convert(
        utf8.encode(
          jsonEncode(
            fields.map((field) => field.toJson()).toList(growable: false),
          ),
        ),
      )
      .toString();

  List<String> missingRequired(Map<String, Object?> values) => fields
      .where(
        (field) => field.required && field.coerce(values[field.key]) == null,
      )
      .map((field) => field.label)
      .toList(growable: false);

  factory QuickJsSettingsSchema.parse(Object? raw) {
    if (raw == null) {
      return const QuickJsSettingsSchema(fields: <QuickJsSettingField>[]);
    }
    if (raw is! List) {
      throw const FormatException('getSettings() must return an array.');
    }
    if (raw.length > 32) {
      throw const FormatException('Settings schema exceeds 32 fields.');
    }
    if (utf8.encode(jsonEncode(raw)).length > 64 * 1024) {
      throw const FormatException(
        'Settings schema exceeds the 64 KB safety limit.',
      );
    }

    final fields = <QuickJsSettingField>[];
    final warnings = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is! Map) {
        warnings.add('Ignored a non-object settings field.');
        continue;
      }
      final key = item['key']?.toString().trim() ?? '';
      final label = item['label']?.toString().trim() ?? '';
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9_.-]{0,63}$').hasMatch(key) ||
          label.isEmpty ||
          label.length > 120 ||
          !seen.add(key)) {
        warnings.add('Ignored an invalid or duplicate settings field.');
        continue;
      }
      final rawType = (item['type'] ?? 'text').toString().trim().toLowerCase();
      final sensitive =
          item['sensitive'] == true ||
          item['secret'] == true ||
          rawType == 'password' ||
          rawType == 'secret' ||
          item['sensitive']?.toString().toLowerCase() == 'true';
      final type = switch (rawType) {
        'text' || 'string' || 'password' || 'secret' => QuickJsSettingType.text,
        'number' ||
        'integer' ||
        'int' ||
        'float' ||
        'decimal' => QuickJsSettingType.number,
        'bool' || 'boolean' || 'toggle' => QuickJsSettingType.boolean,
        'enum' || 'select' || 'dropdown' => QuickJsSettingType.select,
        'multienum' ||
        'multi-enum' ||
        'multiselect' ||
        'multi-select' => QuickJsSettingType.multiSelect,
        _ => null,
      };
      if (type == null) {
        warnings.add('Ignored unsupported settings type for "$key".');
        continue;
      }
      final options = <QuickJsSettingOption>[];
      final rawOptions = item['options'];
      if (rawOptions is List) {
        if (rawOptions.length > 50) {
          warnings.add('Ignored "$key": option count exceeds 50.');
          continue;
        }
        for (final option in rawOptions) {
          final value = option is Map ? option['value'] : option;
          final optionLabel = option is Map ? option['label'] : option;
          if (!_isScalar(value) || optionLabel == null) continue;
          final valueText = value.toString();
          final labelText = optionLabel.toString().trim();
          if (valueText.length > 256 ||
              labelText.isEmpty ||
              labelText.length > 120) {
            continue;
          }
          if (options.any((existing) => existing.value == value)) continue;
          options.add(
            QuickJsSettingOption(value: value as Object, label: labelText),
          );
        }
      }
      if ((type == QuickJsSettingType.select ||
              type == QuickJsSettingType.multiSelect) &&
          options.isEmpty) {
        warnings.add('Ignored "$key": select setting has no valid options.');
        continue;
      }

      final min = item['min'] is num ? item['min'] as num : null;
      final max = item['max'] is num ? item['max'] as num : null;
      if (min != null && max != null && min > max) {
        warnings.add('Ignored "$key": minimum exceeds maximum.');
        continue;
      }
      final rawMaxLength = item['maxLength'] ?? item['max_length'];
      final maxLength = rawMaxLength is num
          ? rawMaxLength.toInt().clamp(1, 4096).toInt()
          : 2048;
      final rawValidation = item['validation']?.toString().trim().toLowerCase();
      const safeValidationRules = <String>{'url', 'email', 'integer', 'number'};
      final validation = safeValidationRules.contains(rawValidation)
          ? rawValidation
          : (rawType == 'integer' || rawType == 'int' ? 'integer' : null);
      final rawDescription = item['description']?.toString().trim();
      final description = rawDescription == null || rawDescription.isEmpty
          ? null
          : rawDescription.substring(
              0,
              rawDescription.length.clamp(0, 240).toInt(),
            );
      final field = QuickJsSettingField(
        key: key,
        label: label,
        type: type,
        defaultValue: null,
        required: item['required'] == true,
        sensitive: sensitive,
        description: description,
        min: min,
        max: max,
        maxLength: maxLength,
        options: List<QuickJsSettingOption>.unmodifiable(options),
        validation: validation,
      );
      final candidateDefault = item.containsKey('default')
          ? item['default']
          : item['defaultValue'];
      Object? defaultValue = field.coerce(candidateDefault);
      defaultValue ??= switch (type) {
        QuickJsSettingType.text => '',
        QuickJsSettingType.number =>
          field.required ? null : min ?? (max != null && max < 0 ? max : 0),
        QuickJsSettingType.boolean => false,
        QuickJsSettingType.select =>
          field.required ? null : options.first.value,
        QuickJsSettingType.multiSelect => <Object>[],
      };
      fields.add(
        QuickJsSettingField(
          key: field.key,
          label: field.label,
          type: field.type,
          defaultValue: defaultValue,
          required: field.required,
          sensitive: field.sensitive,
          description: field.description,
          min: field.min,
          max: field.max,
          maxLength: field.maxLength,
          options: field.options,
          validation: field.validation,
        ),
      );
    }
    return QuickJsSettingsSchema(
      fields: List<QuickJsSettingField>.unmodifiable(fields),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  static bool _isScalar(Object? value) =>
      value is String || value is num || value is bool;
}

/// Removes values explicitly marked sensitive by a provider before any
/// provider-originated console message is written to application logs.
String redactQuickJsSensitiveValues(
  String message,
  Iterable<Object?> sensitiveValues,
) {
  var safeMessage = message;
  for (final value in sensitiveValues) {
    if (value is List) {
      safeMessage = redactQuickJsSensitiveValues(safeMessage, value);
      continue;
    }
    final secret = value?.toString() ?? '';
    if (secret.isNotEmpty) {
      safeMessage = safeMessage.replaceAll(secret, '[REDACTED]');
    }
  }
  return safeMessage;
}

abstract interface class QuickJsSettingsVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureQuickJsSettingsVault implements QuickJsSettingsVault {
  SecureQuickJsSettingsVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class QuickJsExtensionSettingsStore {
  QuickJsExtensionSettingsStore({QuickJsSettingsVault? vault})
    : _vault = vault ?? SecureQuickJsSettingsVault();

  static final QuickJsExtensionSettingsStore instance =
      QuickJsExtensionSettingsStore();
  static const int storageSchemaVersion = 1;
  static const String _prefix = 'raven23.quickjs.settings.v1.';
  static const int _maxStoredBytes = 64 * 1024;
  final QuickJsSettingsVault _vault;
  final Map<String, Map<String, Object?>> _cache =
      <String, Map<String, Object?>>{};
  final Map<String, String> _cacheFingerprints = <String, String>{};
  final Map<String, String> _cacheVersions = <String, String>{};

  String _storageKey(SourceManifest source) =>
      '$_prefix${sha256.convert(utf8.encode(source.stableKey)).toString()}';

  Future<Map<String, Object?>> load(
    SourceManifest source,
    QuickJsSettingsSchema schema,
  ) async {
    final cacheKey = _storageKey(source);
    final cached = _cache[cacheKey];
    if (cached != null &&
        _cacheFingerprints[cacheKey] == schema.fingerprint &&
        _cacheVersions[cacheKey] == source.version) {
      return Map<String, Object?>.unmodifiable(cached);
    }
    Map<String, dynamic> saved = <String, dynamic>{};
    try {
      final raw = await _vault.read(cacheKey);
      if (raw != null && utf8.encode(raw).length <= _maxStoredBytes) {
        final decoded = jsonDecode(raw);
        if (decoded is Map &&
            decoded['storageSchemaVersion'] == storageSchemaVersion &&
            decoded['values'] is Map) {
          saved = Map<String, dynamic>.from(decoded['values'] as Map);
        }
      }
    } catch (_) {
      // Corrupt or incompatible values are ignored; secure storage is rewritten below.
    }
    final values = <String, Object?>{};
    for (final field in schema.fields) {
      final candidate = field.coerce(saved[field.key]);
      values[field.key] = candidate ?? field.defaultValue;
    }
    await _write(source, schema, values);
    return Map<String, Object?>.unmodifiable(values);
  }

  Future<void> save(
    SourceManifest source,
    QuickJsSettingsSchema schema,
    Map<String, Object?> values,
  ) async {
    final validated = <String, Object?>{};
    final errors = <String>[];
    for (final field in schema.fields) {
      final candidate = values.containsKey(field.key)
          ? values[field.key]
          : field.defaultValue;
      final parsed = field.coerce(candidate);
      if (parsed == null && field.required) {
        errors.add(field.label);
      } else {
        validated[field.key] = parsed ?? field.defaultValue;
      }
    }
    if (errors.isNotEmpty) {
      throw FormatException(
        'Required or invalid settings: ${errors.join(', ')}',
      );
    }
    await _write(source, schema, validated);
  }

  Future<void> reset(
    SourceManifest source,
    QuickJsSettingsSchema schema,
  ) async {
    await _write(source, schema, <String, Object?>{
      for (final field in schema.fields) field.key: field.defaultValue,
    });
  }

  Future<void> _write(
    SourceManifest source,
    QuickJsSettingsSchema schema,
    Map<String, Object?> values,
  ) async {
    final key = _storageKey(source);
    final envelope = <String, Object?>{
      'storageSchemaVersion': storageSchemaVersion,
      'sourceVersion': source.version,
      'schemaFingerprint': schema.fingerprint,
      'values': values,
    };
    final encoded = jsonEncode(envelope);
    if (utf8.encode(encoded).length > _maxStoredBytes) {
      throw const FormatException(
        'Extension settings exceed the secure storage size limit.',
      );
    }
    await _vault.write(key, encoded);
    _cache[key] = Map<String, Object?>.from(values);
    _cacheFingerprints[key] = schema.fingerprint;
    _cacheVersions[key] = source.version;
  }

  void invalidate(SourceManifest source) {
    final key = _storageKey(source);
    _cache.remove(key);
    _cacheFingerprints.remove(key);
    _cacheVersions.remove(key);
  }
}
