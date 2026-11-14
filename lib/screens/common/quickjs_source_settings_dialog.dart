import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../video_providers/unified/source_manifest.dart';
import '../../video_providers/unified/quickjs/quickjs_extension_settings.dart';
import '../../video_providers/unified/quickjs/quickjs_extension_settings_service.dart';

class QuickJsSourceSettingsDialog extends StatefulWidget {
  const QuickJsSourceSettingsDialog({
    required this.source,
    this.service,
    super.key,
  });

  final SourceManifest source;
  final QuickJsExtensionSettingsService? service;

  static Future<bool?> show(BuildContext context, SourceManifest source) =>
      showDialog<bool>(
        context: context,
        builder: (_) => QuickJsSourceSettingsDialog(source: source),
      );

  @override
  State<QuickJsSourceSettingsDialog> createState() =>
      _QuickJsSourceSettingsDialogState();
}

class _QuickJsSourceSettingsDialogState
    extends State<QuickJsSourceSettingsDialog> {
  late final QuickJsExtensionSettingsService _service;
  late final Future<QuickJsSourceSettingsSnapshot> _snapshotFuture;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<String, Object?> _values = <String, Object?>{};
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  bool _initialized = false;
  bool _saving = false;
  int _fieldRevision = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? QuickJsExtensionSettingsService();
    _snapshotFuture = _service.load(widget.source);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initialize(QuickJsSourceSettingsSnapshot snapshot) {
    if (_initialized) return;
    _initialized = true;
    _values.addAll(snapshot.values);
    for (final field in snapshot.schema.fields) {
      if (field.type == QuickJsSettingType.text ||
          field.type == QuickJsSettingType.number) {
        _controllers[field.key] = TextEditingController(
          text: _values[field.key]?.toString() ?? '',
        );
      }
    }
  }

  Future<void> _save(QuickJsSettingsSchema schema) async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      for (final field in schema.fields) {
        final controller = _controllers[field.key];
        if (controller != null) _values[field.key] = controller.text;
      }
      await _service.save(widget.source, schema, _values);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset(QuickJsSettingsSchema schema) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.reset(widget.source, schema);
      if (mounted) {
        setState(() {
          for (final field in schema.fields) {
            _values[field.key] = field.defaultValue;
            _controllers[field.key]?.text =
                field.defaultValue?.toString() ?? '';
          }
          // Recreate FormField controls so dropdown and multi-select state is
          // reset along with text controllers and the persisted defaults.
          _fieldRevision++;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.source.name} · ${'quickjs_source_settings'.tr()}'),
    content: SizedBox(
      width: 520,
      child: FutureBuilder<QuickJsSourceSettingsSnapshot>(
        future: _snapshotFuture,
        builder: (context, state) {
          if (state.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (state.hasError) {
            return Text(
              '${'quickjs_settings_load_error'.tr()}\n${state.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            );
          }
          final snapshot = state.data!;
          _initialize(snapshot);
          if (!snapshot.hasSettings) {
            return Text('quickjs_no_settings'.tr());
          }
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final field in snapshot.schema.fields)
                    Padding(
                      key: ValueKey<String>('${field.key}:$_fieldRevision'),
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildField(field),
                    ),
                  if (snapshot.schema.warnings.isNotEmpty)
                    Text(
                      '${snapshot.schema.warnings.length} ${'quickjs_settings_unsupported_fields'.tr()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        child: Text('cancel'.tr()),
      ),
      FutureBuilder<QuickJsSourceSettingsSnapshot>(
        future: _snapshotFuture,
        builder: (context, state) {
          if (!state.hasData || !state.data!.hasSettings) {
            return const SizedBox.shrink();
          }
          return TextButton(
            onPressed: _saving ? null : () => _reset(state.data!.schema),
            child: Text('quickjs_reset_defaults'.tr()),
          );
        },
      ),
      FutureBuilder<QuickJsSourceSettingsSnapshot>(
        future: _snapshotFuture,
        builder: (context, state) {
          if (!state.hasData || !state.data!.hasSettings) {
            return const SizedBox.shrink();
          }
          return FilledButton(
            onPressed: _saving ? null : () => _save(state.data!.schema),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('save'.tr()),
          );
        },
      ),
    ],
  );

  Widget _buildField(QuickJsSettingField field) {
    final current = _values[field.key];
    switch (field.type) {
      case QuickJsSettingType.boolean:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: field.description == null ? null : Text(field.description!),
          value: current == true,
          onChanged: (value) => setState(() => _values[field.key] = value),
        );
      case QuickJsSettingType.select:
        final selected = field.options.any((option) => option.value == current)
            ? current
            : field.defaultValue;
        return DropdownButtonFormField<Object>(
          initialValue: selected,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.description,
            border: const OutlineInputBorder(),
          ),
          hint: Text('quickjs_choose_option'.tr()),
          items: <DropdownMenuItem<Object>>[
            for (final option in field.options)
              DropdownMenuItem<Object>(
                value: option.value,
                child: Text(
                  option.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          validator: (value) => field.required && field.coerce(value) == null
              ? 'quickjs_setting_invalid'.tr()
              : null,
          onChanged: (value) => setState(() => _values[field.key] = value),
        );
      case QuickJsSettingType.multiSelect:
        final selected = current is List
            ? current.cast<Object?>()
            : <Object?>[];
        return FormField<List<Object?>>(
          initialValue: selected,
          validator: (value) => field.required && (value?.isEmpty ?? true)
              ? 'quickjs_setting_invalid'.tr()
              : null,
          builder: (state) {
            final active = state.value ?? <Object?>[];
            return InputDecorator(
              decoration: InputDecoration(
                labelText: field.label,
                helperText: field.description,
                errorText: state.errorText,
                border: const OutlineInputBorder(),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  for (final option in field.options)
                    FilterChip(
                      label: Text(option.label),
                      selected: active.contains(option.value),
                      onSelected: (enabled) {
                        final next = List<Object?>.from(active);
                        if (enabled) {
                          next.add(option.value);
                        } else {
                          next.remove(option.value);
                        }
                        state.didChange(next);
                        setState(() => _values[field.key] = next);
                      },
                    ),
                ],
              ),
            );
          },
        );
      case QuickJsSettingType.text:
      case QuickJsSettingType.number:
        final controller = _controllers[field.key]!;
        return TextFormField(
          controller: controller,
          obscureText: field.sensitive,
          maxLength: field.type == QuickJsSettingType.text
              ? field.maxLength
              : 32,
          keyboardType: field.type == QuickJsSettingType.number
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.description,
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (!field.required && text.isEmpty) return null;
            final candidate = field.type == QuickJsSettingType.number
                ? num.tryParse(text)
                : value ?? '';
            return field.coerce(candidate) == null
                ? 'quickjs_setting_invalid'.tr()
                : null;
          },
        );
    }
  }
}
