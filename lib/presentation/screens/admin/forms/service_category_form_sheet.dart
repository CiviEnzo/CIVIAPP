import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service_category.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

const List<Color> _categoryColorOptions = <Color>[
  Color(0xFF6750A4),
  Color(0xFF8E24AA),
  Color(0xFF3949AB),
  Color(0xFF1E88E5),
  Color(0xFF039BE5),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFF7CB342),
  Color(0xFFFF7043),
  Color(0xFFFB8C00),
  Color(0xFFD81B60),
  Color(0xFF546E7A),
];

class ServiceCategoryFormSheet extends StatefulWidget {
  const ServiceCategoryFormSheet({
    super.key,
    required this.salons,
    this.initial,
    this.initialSalonId,
    this.initialSortOrder,
  });

  final List<Salon> salons;
  final ServiceCategory? initial;
  final String? initialSalonId;
  final int? initialSortOrder;

  @override
  State<ServiceCategoryFormSheet> createState() =>
      _ServiceCategoryFormSheetState();
}

class _ServiceCategoryFormSheetState extends State<ServiceCategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _name;
  late TextEditingController _description;
  late TextEditingController _sortOrder;
  late TextEditingController _colorHex;
  String? _salonId;
  Color? _color;
  String? _colorHexError;
  bool _isUpdatingHexField = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    final defaultSortOrder =
        initial?.sortOrder ?? widget.initialSortOrder ?? 100;
    _sortOrder = TextEditingController(text: defaultSortOrder.toString());
    _salonId =
        initial?.salonId ??
        widget.initialSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _color = initial?.color != null ? Color(initial!.color!) : null;
    _colorHex = TextEditingController(
      text: _color != null ? _formatColorHex(_color!) : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _sortOrder.dispose();
    _colorHex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canChangeSalon = widget.initial == null && widget.salons.length > 1;
    final theme = Theme.of(context);
    return DialogActionLayout(
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null
                  ? 'Nuova categoria'
                  : 'Modifica categoria',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (widget.salons.length > 1)
              DropdownButtonFormField<String>(
                value: _salonId,
                decoration: const InputDecoration(labelText: 'Salone'),
                items:
                    widget.salons
                        .map(
                          (salon) => DropdownMenuItem(
                            value: salon.id,
                            child: Text(salon.name),
                          ),
                        )
                        .toList(),
                onChanged:
                    canChangeSalon
                        ? (value) => setState(() => _salonId = value)
                        : null,
              )
            else
              TextFormField(
                enabled: false,
                initialValue:
                    widget.salons.isNotEmpty
                        ? widget.salons.first.name
                        : 'Nessun salone',
                decoration: const InputDecoration(labelText: 'Salone'),
              ),
            if (widget.salons.isNotEmpty) const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il nome della categoria'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Descrizione (opzionale)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sortOrder,
              decoration: const InputDecoration(
                labelText: 'Ordine di visualizzazione',
                helperText:
                    'Numeri più bassi mostrano la categoria più in alto.',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _buildColorPicker(theme),
            const SizedBox(height: 16),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _submit,
          child: const Text('Salva'),
        ),
      ],
    );
  }

  Widget _buildColorPicker(ThemeData theme) {
    final selected = _color;
    final colors = List<Color>.from(_categoryColorOptions);
    if (selected != null &&
        colors.every((color) => color.value != selected.value)) {
      colors.insert(0, selected);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Colore categoria',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              colors
                  .map(
                    (color) => _CategoryColorSwatch(
                      color: color,
                      selected: selected?.value == color.value,
                      onTap: () => _handlePresetColorTap(color),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _colorHex,
          decoration: InputDecoration(
            labelText: 'Codice colore personalizzato',
            hintText: '#RRGGBB',
            errorText: _colorHexError,
          ),
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
          ],
          onChanged: _onColorHexChanged,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ?? theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selected != null
                    ? 'Selezionato ${_formatColorHex(selected)}'
                    : 'Nessun colore selezionato',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton.icon(
              onPressed:
                  selected == null
                      ? null
                      : () => _setSelectedColor(null, syncHexField: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Nessun colore'),
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_salonId == null || _salonId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleziona un salone.')));
      return;
    }

    final category = ServiceCategory(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      name: _name.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      sortOrder: _parseSortOrder(_sortOrder.text.trim()),
      color: _color?.value,
    );

    Navigator.of(context).pop(category);
  }

  void _handlePresetColorTap(Color color) {
    _setSelectedColor(color, syncHexField: true);
  }

  void _setSelectedColor(Color? color, {bool syncHexField = false}) {
    setState(() {
      _color = color;
      _colorHexError = null;
      if (syncHexField) {
        _syncHexField(color);
      }
    });
  }

  void _syncHexField(Color? color) {
    _isUpdatingHexField = true;
    final text = color != null ? _formatColorHex(color) : '';
    _colorHex.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _isUpdatingHexField = false;
  }

  void _onColorHexChanged(String rawValue) {
    if (_isUpdatingHexField) {
      return;
    }
    final value = rawValue.trim();
    if (value.isEmpty) {
      _setSelectedColor(null);
      return;
    }

    final parsed = _tryParseHexColor(value);
    if (parsed != null) {
      setState(() {
        _color = parsed;
        _colorHexError = null;
        _syncHexField(parsed);
      });
    } else {
      setState(() {
        _colorHexError = 'Inserisci un colore hex valido (es. #FFAA33).';
      });
    }
  }

  String _formatColorHex(Color color) {
    final value = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${value.substring(2)}';
  }

  Color? _tryParseHexColor(String input) {
    final match =
        RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').firstMatch(input);
    if (match == null) {
      return null;
    }
    var hex = match.group(1)!;
    if (hex.length == 3) {
      hex = hex.split('').map((char) => '$char$char').join();
    }
    final value = int.tryParse(hex, radix: 16);
    if (value == null) {
      return null;
    }
    return Color(0xFF000000 | value);
  }

  int _parseSortOrder(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      return widget.initial?.sortOrder ?? 100;
    }
    return parsed;
  }
}

class _CategoryColorSwatch extends StatelessWidget {
  const _CategoryColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final checkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : const Color(0xFF1C1B1F);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected
                      ? scheme.onSurface
                      : scheme.outlineVariant.withValues(alpha: 0.6),
              width: selected ? 3 : 1,
            ),
            boxShadow:
                selected
                    ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                    : const <BoxShadow>[],
          ),
          child: selected ? Icon(Icons.check_rounded, color: checkColor) : null,
        ),
      ),
    );
  }
}
