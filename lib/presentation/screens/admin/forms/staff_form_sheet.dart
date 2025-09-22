import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/domain/entities/staff_role.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const String _defaultRoleId = 'estetista';
const String _unknownRoleId = 'staff-role-unknown';

class StaffFormSheet extends StatefulWidget {
  const StaffFormSheet({
    super.key,
    required this.salons,
    required this.roles,
    this.initial,
    this.defaultSalonId,
    this.defaultRoleId,
  });

  final List<Salon> salons;
  final List<StaffRole> roles;
  final StaffMember? initial;
  final String? defaultSalonId;
  final String? defaultRoleId;

  @override
  State<StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<StaffFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _skillsController;
  late TextEditingController _vacationAllowanceController;
  late TextEditingController _permissionAllowanceController;
  String? _roleId;
  String? _salonId;
  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _firstNameController = TextEditingController(
      text: initial?.firstName ?? '',
    );
    _lastNameController = TextEditingController(text: initial?.lastName ?? '');
    _phoneController = TextEditingController(text: initial?.phone ?? '');
    _emailController = TextEditingController(text: initial?.email ?? '');
    _skillsController = TextEditingController(
      text: initial?.skills.join(', ') ?? '',
    );
    _vacationAllowanceController = TextEditingController(
      text:
          '${initial?.vacationAllowance ?? StaffMember.defaultVacationAllowance}',
    );
    _permissionAllowanceController = TextEditingController(
      text:
          '${initial?.permissionAllowance ?? StaffMember.defaultPermissionAllowance}',
    );
    _dateOfBirth = initial?.dateOfBirth;
    _roleId = _normalizeRoleId(initial?.roleId ?? widget.defaultRoleId);
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureDefaults();
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _skillsController.dispose();
    _vacationAllowanceController.dispose();
    _permissionAllowanceController.dispose();
    super.dispose();
  }

  bool get _hasRoles => widget.roles.isNotEmpty;

  String? _normalizeRoleId(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return widget.roles.firstWhereOrNull((role) => role.id == trimmed)?.id;
  }

  String? _preferredRoleId(List<StaffRole> roles) {
    if (roles.isEmpty) {
      return null;
    }
    final candidates = <String?>[
      _normalizeRoleId(widget.initial?.roleId),
      _normalizeRoleId(widget.defaultRoleId),
      _normalizeRoleId(_defaultRoleId),
      _normalizeRoleId(_unknownRoleId),
    ];
    for (final candidate in candidates) {
      if (candidate != null) {
        return candidate;
      }
    }
    return roles.first.id;
  }

  void _ensureDefaults() {
    if (!_hasRoles) {
      return;
    }
    final roleExists = widget.roles.any((role) => role.id == _roleId);
    if (!roleExists) {
      setState(() {
        _roleId = _preferredRoleId(widget.roles);
      });
    }
    if (_salonId == null && widget.salons.isNotEmpty) {
      setState(() {
        _salonId = widget.salons.first.id;
      });
    }
  }

  Future<void> _pickDateOfBirth() async {
    final initialDate =
        _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 80)),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  int _parseAllowance(TextEditingController controller, int fallback) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < 0) {
      return fallback;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat('dd MMMM yyyy', 'it_IT');
    final sortedRoles = widget.roles.sorted((a, b) {
      final priority = a.sortPriority.compareTo(b.sortPriority);
      if (priority != 0) {
        return priority;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    final roleItems =
        sortedRoles
            .map(
              (role) => DropdownMenuItem<String>(
                value: role.id,
                child: Text(role.displayName),
              ),
            )
            .toList();
    final dateLabel =
        _dateOfBirth != null
            ? dateFormatter.format(_dateOfBirth!)
            : 'Seleziona data';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null
                  ? 'Nuovo membro dello staff'
                  : 'Modifica membro dello staff',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              textCapitalization: TextCapitalization.words,
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il nome'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Cognome'),
              textCapitalization: TextCapitalization.words,
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il cognome'
                          : null,
            ),
            const SizedBox(height: 12),
            if (_hasRoles)
              DropdownButtonFormField<String>(
                value: _roleId,
                decoration: const InputDecoration(
                  labelText: 'Tipo di mansione',
                ),
                items: roleItems,
                validator:
                    (value) => value == null ? 'Seleziona una mansione' : null,
                onChanged: (value) => setState(() => _roleId = value),
              )
            else
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nessuna mansione disponibile. Aggiungi un ruolo dallo spazio staff.',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDateOfBirth,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data di nascita',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dateLabel),
                    const Icon(Icons.calendar_today_rounded, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telefono'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'Inserisci l\'email';
                }
                if (!text.contains('@')) {
                  return 'Inserisci un\'email valida';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vacationAllowanceController,
                    decoration: const InputDecoration(
                      labelText: 'Ferie annue (giorni)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _permissionAllowanceController,
                    decoration: const InputDecoration(
                      labelText: 'Permessi annui',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skillsController,
              decoration: const InputDecoration(
                labelText: 'Competenze (separate da virgola)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _salonId,
              decoration: const InputDecoration(
                labelText: 'Salone di riferimento',
              ),
              items:
                  widget.salons
                      .map(
                        (salon) => DropdownMenuItem(
                          value: salon.id,
                          child: Text(salon.name),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _salonId = value),
              validator:
                  (value) =>
                      value == null || value.isEmpty
                          ? 'Seleziona il salone di riferimento'
                          : null,
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _hasRoles ? _submit : null,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Salva'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_hasRoles || _roleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aggiungi una mansione prima di salvare.'),
        ),
      );
      return;
    }
    if (_salonId == null || _salonId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Specifica un salone di riferimento')),
      );
      return;
    }
    final skills =
        _skillsController.text
            .split(',')
            .map((skill) => skill.trim())
            .where((skill) => skill.isNotEmpty)
            .toList();

    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final staff = StaffMember(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      roleId: _roleId!,
      phone: phone.isEmpty ? null : phone,
      email: email.isEmpty ? null : email,
      dateOfBirth: _dateOfBirth,
      skills: skills,
      vacationAllowance: _parseAllowance(
        _vacationAllowanceController,
        StaffMember.defaultVacationAllowance,
      ),
      permissionAllowance: _parseAllowance(
        _permissionAllowanceController,
        StaffMember.defaultPermissionAllowance,
      ),
    );
    Navigator.of(context).pop(staff);
  }
}
