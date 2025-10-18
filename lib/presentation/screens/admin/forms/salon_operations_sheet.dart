import 'package:civiapp/domain/entities/salon.dart';
import 'package:flutter/material.dart';

class SalonOperationsSheet extends StatefulWidget {
  const SalonOperationsSheet({super.key, required this.salon});

  final Salon salon;

  @override
  State<SalonOperationsSheet> createState() => _SalonOperationsSheetState();
}

class _SalonOperationsSheetState extends State<SalonOperationsSheet> {
  late SalonStatus _status;
  late bool _showKpis;
  late bool _showOperational;
  late bool _showEquipment;
  late bool _showRooms;
  late bool _showLoyalty;
  late bool _showSocial;

  @override
  void initState() {
    super.initState();
    final sections = widget.salon.dashboardSections;
    _status = widget.salon.status;
    _showKpis = sections.showKpis;
    _showOperational = sections.showOperational;
    _showEquipment = sections.showEquipment;
    _showRooms = sections.showRooms;
    _showLoyalty = sections.showLoyalty;
    _showSocial = sections.showSocial;
  }

  void _submit() {
    final updated = widget.salon.copyWith(
      status: _status,
      dashboardSections: widget.salon.dashboardSections.copyWith(
        showKpis: _showKpis,
        showOperational: _showOperational,
        showEquipment: _showEquipment,
        showRooms: _showRooms,
        showLoyalty: _showLoyalty,
        showSocial: _showSocial,
      ),
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operatività', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              'Aggiorna lo stato del salone e scegli quali card mostrare nella dashboard operativa.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<SalonStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Stato del salone'),
              items: SalonStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            const SizedBox(height: 24),
            Text('Card visibili', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildToggle(
              title: 'KPI giornalieri',
              subtitle: 'Staff, clienti, appuntamenti',
              value: _showKpis,
              onChanged: (value) => setState(() => _showKpis = value),
            ),
            _buildToggle(
              title: 'Stato operativo',
              subtitle: 'Panoramica stato salone',
              value: _showOperational,
              onChanged: (value) => setState(() => _showOperational = value),
            ),
            _buildToggle(
              title: 'Macchinari',
              subtitle: 'Elenco macchinari e stato',
              value: _showEquipment,
              onChanged: (value) => setState(() => _showEquipment = value),
            ),
            _buildToggle(
              title: 'Cabine e stanze',
              subtitle: 'Capienze e disponibilità',
              value: _showRooms,
              onChanged: (value) => setState(() => _showRooms = value),
            ),
            _buildToggle(
              title: 'Programma fedeltà',
              subtitle: 'Overview punti e stato',
              value: _showLoyalty,
              onChanged: (value) => setState(() => _showLoyalty = value),
            ),
            _buildToggle(
              title: 'Presenza online & social',
              subtitle: 'Link ai canali digitali',
              value: _showSocial,
              onChanged: (value) => setState(() => _showSocial = value),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('Salva'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
