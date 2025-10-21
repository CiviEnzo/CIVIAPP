import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:flutter/material.dart';

class SalonSocialSheet extends StatefulWidget {
  const SalonSocialSheet({super.key, required this.salon});

  final Salon salon;

  @override
  State<SalonSocialSheet> createState() => _SalonSocialSheetState();
}

class _EditableSocialLink {
  _EditableSocialLink({
    required this.id,
    String? label,
    String? url,
    this.isDefault = false,
  })  : label = TextEditingController(text: label ?? ''),
        url = TextEditingController(text: url ?? '');

  factory _EditableSocialLink.fromEntry(
    MapEntry<String, String> entry,
    String id, {
    bool isDefault = false,
  }) {
    return _EditableSocialLink(
      id: id,
      label: entry.key,
      url: entry.value,
      isDefault: isDefault,
    );
  }

  final String id;
  final bool isDefault;
  final TextEditingController label;
  final TextEditingController url;

  void dispose() {
    label.dispose();
    url.dispose();
  }
}

class _SalonSocialSheetState extends State<SalonSocialSheet> {
  static const List<String> _defaultSocialLabels = ['Instagram', 'Facebook', 'TikTok'];

  final _formKey = GlobalKey<FormState>();
  late List<_EditableSocialLink> _links;

  @override
  void initState() {
    super.initState();
    final entries = widget.salon.socialLinks.entries.toList();
    final usedIndexes = <int>{};
    final initialLinks = <_EditableSocialLink>[];

    for (final defaultLabel in _defaultSocialLabels) {
      final lower = defaultLabel.toLowerCase();
      final index = entries.indexWhere(
        (entry) => entry.key.toLowerCase() == lower,
      );
      MapEntry<String, String>? matchedEntry;
      if (index != -1) {
        matchedEntry = entries[index];
        usedIndexes.add(index);
      }
      initialLinks.add(
        _EditableSocialLink(
          id: 'default_$lower',
          label: defaultLabel,
          url: matchedEntry?.value,
          isDefault: true,
        ),
      );
    }

    for (var i = 0; i < entries.length; i++) {
      if (usedIndexes.contains(i)) {
        continue;
      }
      final entry = entries[i];
      initialLinks.add(
        _EditableSocialLink.fromEntry(entry, 'link_$i'),
      );
    }

    _links = initialLinks;
  }

  @override
  void dispose() {
    for (final link in _links) {
      link.dispose();
    }
    super.dispose();
  }

  void _addLink() {
    setState(() {
      _links.add(_EditableSocialLink(id: UniqueKey().toString()));
    });
  }

  void _removeLink(_EditableSocialLink link) {
    if (link.isDefault) {
      return;
    }
    if (_links.length == 1) {
      setState(() {
        link.label.clear();
        link.url.clear();
      });
      return;
    }
    setState(() {
      _links.remove(link);
    });
    link.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final map = <String, String>{};
    for (final link in _links) {
      final label = link.label.text.trim();
      final url = link.url.text.trim();
      if (label.isEmpty && url.isEmpty) {
        continue;
      }
      if (url.isEmpty && link.isDefault) {
        continue;
      }
      map[label] = url;
    }
    final updated = widget.salon.copyWith(socialLinks: map);
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DialogActionLayout(
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Presenza online e social', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              'Aggiungi i canali social e digitali del salone.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ..._links.map((link) => _buildCard(context, link)).toList(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addLink,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Aggiungi canale'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salva'),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, _EditableSocialLink link) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Canale', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (link.isDefault)
                  Tooltip(
                    message: 'Canale predefinito',
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.outline,
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Rimuovi',
                    onPressed: () => _removeLink(link),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            TextFormField(
              controller: link.label,
              readOnly: link.isDefault,
              decoration: const InputDecoration(
                labelText: 'Nome canale',
                helperText: 'Es. Instagram, Facebook... ',
              ),
              validator: (value) {
                final label = value?.trim() ?? '';
                final url = link.url.text.trim();
                if (label.isEmpty && url.isEmpty) {
                  return null;
                }
                if (label.isEmpty) {
                  return 'Inserisci il nome del canale';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: link.url,
              decoration: const InputDecoration(
                labelText: 'URL',
                helperText: 'https://...',
              ),
              validator: (value) {
                final url = value?.trim() ?? '';
                final label = link.label.text.trim();
                if (label.isEmpty && url.isEmpty) {
                  return null;
                }
                if (url.isEmpty) {
                  if (link.isDefault) {
                    return null;
                  }
                  return 'Inserisci l\'URL del canale';
                }
                final uri = Uri.tryParse(url);
                if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
                  return 'URL non valido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
