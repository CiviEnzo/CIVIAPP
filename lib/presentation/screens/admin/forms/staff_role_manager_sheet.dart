import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/staff_role.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class StaffRoleManagerSheet extends ConsumerStatefulWidget {
  const StaffRoleManagerSheet({
    super.key,
    required this.canManageRoles,
    this.salonId,
  });

  final bool canManageRoles;
  final String? salonId;

  @override
  ConsumerState<StaffRoleManagerSheet> createState() =>
      _StaffRoleManagerSheetState();
}

class _StaffRoleManagerSheetState extends ConsumerState<StaffRoleManagerSheet> {
  final _uuid = const Uuid();
  bool _isProcessing = false;

  List<StaffRole> _sortedRoles(List<StaffRole> roles) {
    return roles.sorted((a, b) {
      final priorityCompare = a.sortPriority.compareTo(b.sortPriority);
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
  }

  List<StaffRole> _filterRolesBySalon(List<StaffRole> roles, String? salonId) {
    final normalizedSalonId = salonId?.trim();
    if (normalizedSalonId == null || normalizedSalonId.isEmpty) {
      return roles;
    }
    return roles.where((role) {
      if (role.isDefault) {
        return true;
      }
      final roleSalonId = role.salonId?.trim();
      return roleSalonId != null && roleSalonId == normalizedSalonId;
    }).toList();
  }

  String? _resolveSalonIdForActions() {
    final explicit = widget.salonId?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final sessionSalon = ref.read(currentSalonIdProvider)?.trim();
    if (sessionSalon == null || sessionSalon.isEmpty) {
      return null;
    }
    return sessionSalon;
  }

  StaffRole? _withEnsuredSalon(StaffRole role) {
    if (role.isDefault) {
      return role;
    }
    final existingSalon = role.salonId?.trim();
    if (existingSalon != null && existingSalon.isNotEmpty) {
      return role.copyWith(salonId: existingSalon);
    }
    final resolvedSalonId = _resolveSalonIdForActions();
    if (resolvedSalonId == null) {
      _showSalonSelectionWarning();
      return null;
    }
    return role.copyWith(salonId: resolvedSalonId);
  }

  Future<void> _createRole() async {
    if (!widget.canManageRoles) {
      _showPermissionWarning();
      return;
    }
    final salonId = _resolveSalonIdForActions();
    if (salonId == null) {
      _showSalonSelectionWarning();
      return;
    }
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Nuovo ruolo'),
            content: TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome ruolo',
                hintText: 'Es. Receptionist serale',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () {
                  final value = nameController.text.trim();
                  if (value.isEmpty) {
                    return;
                  }
                  Navigator.of(ctx).pop(value);
                },
                child: const Text('Crea'),
              ),
            ],
          ),
    );
    nameController.dispose();
    if (result == null || result.trim().isEmpty) {
      return;
    }
    final rolesForSalon = _filterRolesBySalon(
      ref.read(appDataProvider).staffRoles,
      salonId,
    );
    await _submitRole(
      StaffRole(
        id: _uuid.v4(),
        name: result.trim(),
        salonId: salonId,
        isDefault: false,
        sortPriority: rolesForSalon.length + 1,
      ),
    );
  }

  Future<void> _renameRole(StaffRole role) async {
    if (!widget.canManageRoles) {
      _showPermissionWarning();
      return;
    }
    final controller = TextEditingController(text: role.name);
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Rinomina ruolo'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome ruolo'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty || value == role.name) {
                    Navigator.of(ctx).pop();
                    return;
                  }
                  Navigator.of(ctx).pop(value);
                },
                child: const Text('Salva'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty || result.trim() == role.name) {
      return;
    }
    await _submitRole(role.copyWith(name: result.trim()));
  }

  Future<void> _deleteRole(StaffRole role) async {
    if (!widget.canManageRoles) {
      _showPermissionWarning();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Elimina ruolo'),
            content: Text('Vuoi davvero eliminare il ruolo "${role.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Elimina'),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _isProcessing = true);
    try {
      await ref.read(appDataProvider.notifier).deleteStaffRole(role.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ruolo "${role.name}" eliminato.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _submitRole(StaffRole role) async {
    if (!widget.canManageRoles) {
      _showPermissionWarning();
      return;
    }
    final sanitizedRole = _withEnsuredSalon(role);
    if (sanitizedRole == null) {
      return;
    }
    setState(() => _isProcessing = true);
    try {
      await ref.read(appDataProvider.notifier).upsertStaffRole(sanitizedRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ruolo "${sanitizedRole.name}" salvato.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final explicitSalonId = widget.salonId?.trim();
    final sessionSalonId = ref.watch(currentSalonIdProvider)?.trim();
    final activeSalonId =
        (explicitSalonId != null && explicitSalonId.isNotEmpty)
            ? explicitSalonId
            : (sessionSalonId != null && sessionSalonId.isNotEmpty
                ? sessionSalonId
                : null);
    final roles = ref.watch(
      appDataProvider.select((state) => state.staffRoles),
    );
    final filteredRoles = _filterRolesBySalon(roles, activeSalonId);
    final sortedRoles = _sortedRoles(filteredRoles);
    final theme = Theme.of(context);
    final canManage = widget.canManageRoles;
    final hasActiveSalon = activeSalonId != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Gestione ruoli staff',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed:
                      _isProcessing ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Organizza le mansioni disponibili per assegnare i membri dello staff e limitare i servizi a ruoli specifici.',
              style: theme.textTheme.bodySmall,
            ),
            if (!canManage) ...[
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text(
                    'Solo gli amministratori possono modificare i ruoli.',
                  ),
                  subtitle: Text('Puoi comunque consultarne l\'elenco.'),
                ),
              ),
            ] else if (!hasActiveSalon) ...[
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('Seleziona un salone per gestire i ruoli.'),
                  subtitle: Text(
                    'I ruoli sono visibili e modificabili solo per il salone corrente.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (sortedRoles.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Nessun ruolo definito.'),
                  subtitle: const Text(
                    'Aggiungi il primo ruolo per iniziare a classificare lo staff.',
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: sortedRoles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final role = sortedRoles[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.badge_rounded),
                        title: Text(role.displayName),
                        subtitle:
                            role.isDefault
                                ? const Text('Ruolo di sistema')
                                : null,
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'Rinomina',
                              onPressed:
                                  _isProcessing || !canManage
                                      ? null
                                      : () => _renameRole(role),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              tooltip: 'Elimina',
                              onPressed:
                                  _isProcessing || role.isDefault || !canManage
                                      ? null
                                      : () => _deleteRole(role),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed:
                      _isProcessing || !canManage || !hasActiveSalon
                          ? null
                          : _createRole,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nuovo ruolo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSalonSelectionWarning() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seleziona un salone per gestire i ruoli.')),
    );
  }

  void _showPermissionWarning() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solo gli amministratori possono modificare i ruoli.'),
      ),
    );
  }
}
