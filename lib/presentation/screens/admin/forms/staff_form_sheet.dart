import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class StaffFormSheet extends StatefulWidget {
  const StaffFormSheet({
    super.key,
    required this.salons,
    this.initial,
    this.defaultSalonId,
  });

  final List<Salon> salons;
  final StaffMember? initial;
  final String? defaultSalonId;

  @override
  State<StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<StaffFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _skillsController;
  StaffRole _role = StaffRole.estetista;
  String? _salonId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.fullName ?? '');
    _phoneController = TextEditingController(text: initial?.phone ?? '');
    _emailController = TextEditingController(text: initial?.email ?? '');
    _skillsController = TextEditingController(text: initial?.skills.join(', ') ?? '');
    _role = initial?.role ?? StaffRole.estetista;
    _salonId = initial?.salonId ?? widget.defaultSalonId ?? (widget.salons.isNotEmpty ? widget.salons.first.id : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null ? 'Nuovo membro dello staff' : 'Modifica membro dello staff',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome e cognome'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Inserisci il nome' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<StaffRole>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Ruolo'),
              items: StaffRole.values
                  .map((role) => DropdownMenuItem(value: role, child: Text(role.label)))
                  .toList(),
              onChanged: (value) => setState(() => _role = value ?? StaffRole.estetista),
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
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skillsController,
              decoration: const InputDecoration(labelText: 'Competenze (separate da virgola)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _salonId,
              decoration: const InputDecoration(labelText: 'Salone di riferimento'),
              items: widget.salons
                  .map(
                    (salon) => DropdownMenuItem(
                      value: salon.id,
                      child: Text(salon.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _salonId = value),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Salva'),
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
    if (_salonId == null || _salonId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Specifica un salone di riferimento')),
      );
      return;
    }
    final skills = _skillsController.text
        .split(',')
        .map((skill) => skill.trim())
        .where((skill) => skill.isNotEmpty)
        .toList();

    final staff = StaffMember(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      fullName: _nameController.text.trim(),
      role: _role,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      skills: skills,
    );

    Navigator.of(context).pop(staff);
  }
}
