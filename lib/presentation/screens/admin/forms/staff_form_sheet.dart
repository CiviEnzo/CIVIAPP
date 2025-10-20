import 'dart:async';
import 'dart:typed_data';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/domain/entities/staff_role.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

const String _defaultRoleId = 'estetista';
const String _unknownRoleId = 'staff-role-unknown';

class _CompressedAvatar {
  const _CompressedAvatar({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

class StaffFormSheet extends ConsumerStatefulWidget {
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
  ConsumerState<StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends ConsumerState<StaffFormSheet> {
  static const int _maxAvatarBytes = 2 * 1024 * 1024;
  static const int _maxAvatarSourceBytes = 8 * 1024 * 1024;
  static const int _maxAvatarDimension = 1024;

  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _vacationAllowanceController;
  late TextEditingController _permissionAllowanceController;
  late List<String> _selectedRoleIds;
  late final String _staffId;
  late final String? _initialAvatarStoragePath;
  String? _salonId;
  DateTime? _dateOfBirth;
  String? _avatarUrl;
  String? _avatarStoragePath;
  String? _avatarError;
  bool _isUploadingAvatar = false;
  bool _hasSaved = false;
  final Set<String> _pathsToDeleteOnSave = <String>{};

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _staffId = initial?.id ?? _uuid.v4();
    _avatarUrl = initial?.avatarUrl;
    _avatarStoragePath = initial?.avatarStoragePath;
    _initialAvatarStoragePath = initial?.avatarStoragePath;
    _firstNameController = TextEditingController(
      text: initial?.firstName ?? '',
    );
    _lastNameController = TextEditingController(text: initial?.lastName ?? '');
    _phoneController = TextEditingController(text: initial?.phone ?? '');
    _emailController = TextEditingController(text: initial?.email ?? '');
    _vacationAllowanceController = TextEditingController(
      text:
          '${initial?.vacationAllowance ?? StaffMember.defaultVacationAllowance}',
    );
    _permissionAllowanceController = TextEditingController(
      text:
          '${initial?.permissionAllowance ?? StaffMember.defaultPermissionAllowance}',
    );
    _dateOfBirth = initial?.dateOfBirth;
    final initialRoleIds = _normalizeRoleIds(initial?.roleIds ?? const []);
    if (initialRoleIds.isNotEmpty) {
      _selectedRoleIds = initialRoleIds;
    } else {
      final preferred = _preferredRoleId(widget.roles);
      _selectedRoleIds = preferred == null ? <String>[] : <String>[preferred];
    }
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _vacationAllowanceController.dispose();
    _permissionAllowanceController.dispose();
    final avatarPath = _avatarStoragePath;
    if (!_hasSaved &&
        avatarPath != null &&
        avatarPath.isNotEmpty &&
        avatarPath != _initialAvatarStoragePath) {
      unawaited(
        ref.read(firebaseStorageServiceProvider).deleteFile(avatarPath),
      );
    }
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

  List<String> _normalizeRoleIds(List<String> rawIds) {
    final normalized = <String>[];
    for (final raw in rawIds) {
      final normalizedId = _normalizeRoleId(raw);
      if (normalizedId != null && !normalized.contains(normalizedId)) {
        normalized.add(normalizedId);
      }
    }
    return normalized;
  }

  String? _preferredRoleId(List<StaffRole> roles) {
    if (roles.isEmpty) {
      return null;
    }
    final candidates = <String?>[
      widget.initial == null
          ? null
          : _normalizeRoleIds(widget.initial!.roleIds).firstOrNull,
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

  String _avatarInitials() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final buffer = StringBuffer();
    if (first.isNotEmpty) {
      buffer.write(first[0]);
    }
    if (last.isNotEmpty) {
      buffer.write(last[0]);
    }
    final initials = buffer.toString().toUpperCase();
    if (initials.isNotEmpty) {
      return initials.length > 2 ? initials.substring(0, 2) : initials;
    }
    return '?';
  }

  Future<void> _pickAvatar() async {
    if (_isUploadingAvatar) {
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
      withReadStream: true,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.first;
    if (file.size > _maxAvatarSourceBytes) {
      final maxMb = (_maxAvatarSourceBytes / (1024 * 1024)).toStringAsFixed(1);
      setState(() {
        _avatarError = 'L\'immagine supera il limite di $maxMb MB.';
      });
      return;
    }
    final bytes = await _resolveBytes(file);
    if (!mounted) {
      return;
    }
    if (bytes == null || bytes.isEmpty) {
      setState(() {
        _avatarError = 'Impossibile leggere il file selezionato.';
      });
      return;
    }
    final salonId = _salonId;
    if (salonId == null || salonId.isEmpty) {
      setState(() {
        _avatarError = 'Seleziona un salone prima di caricare una foto.';
      });
      return;
    }
    setState(() {
      _isUploadingAvatar = true;
      _avatarError = null;
    });
    final storage = ref.read(firebaseStorageServiceProvider);
    final session = ref.read(sessionControllerProvider);
    final uploaderId = session.uid ?? 'unknown';
    final previousPath = _avatarStoragePath;
    try {
      final compressed = await _compressAvatar(bytes);
      late final _CompressedAvatar uploadData;
      if (compressed != null) {
        uploadData = compressed;
      } else {
        final fallbackExtension = _fallbackExtensionForUpload(file.extension);
        if (fallbackExtension == null) {
          if (!mounted) {
            return;
          }
          setState(() {
            _avatarError =
                'Formato immagine non supportato. Usa JPG, PNG o WEBP.';
          });
          return;
        }
        uploadData = _CompressedAvatar(
          bytes: bytes,
          extension: fallbackExtension,
        );
      }
      if (uploadData.bytes.length > _maxAvatarBytes) {
        if (!mounted) {
          return;
        }
        final maxMb = (_maxAvatarBytes / (1024 * 1024)).toStringAsFixed(1);
        setState(() {
          _avatarError =
              'Impossibile ridurre la dimensione sotto $maxMb MB. Usa un\'immagine più piccola.';
        });
        return;
      }
      final upload = await storage.uploadStaffAvatar(
        salonId: salonId,
        staffId: _staffId,
        data: uploadData.bytes,
        fileName: 'avatar.${uploadData.extension}',
        uploaderId: uploaderId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarUrl = upload.downloadUrl;
        _avatarStoragePath = upload.storagePath;
      });
      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != upload.storagePath) {
        if (previousPath == _initialAvatarStoragePath) {
          _pathsToDeleteOnSave.add(previousPath);
        } else {
          unawaited(storage.deleteFile(previousPath));
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarError = 'Impossibile caricare l\'immagine: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  void _removeAvatar() {
    if (_isUploadingAvatar) {
      return;
    }
    final currentPath = _avatarStoragePath;
    if (currentPath != null && currentPath.isNotEmpty) {
      final storage = ref.read(firebaseStorageServiceProvider);
      if (currentPath == _initialAvatarStoragePath) {
        _pathsToDeleteOnSave.add(currentPath);
      } else {
        unawaited(storage.deleteFile(currentPath));
      }
    }
    setState(() {
      _avatarUrl = null;
      _avatarStoragePath = null;
      _avatarError = null;
    });
  }

  Future<Uint8List?> _resolveBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes;
    }
    final stream = file.readStream;
    if (stream == null) {
      return null;
    }
    final builder = BytesBuilder();
    try {
      await for (final chunk in stream) {
        builder.add(chunk);
        if (builder.length > _maxAvatarSourceBytes) {
          return null;
        }
      }
      final data = builder.takeBytes();
      return data.isEmpty ? null : data;
    } catch (_) {
      return null;
    }
  }

  Future<_CompressedAvatar?> _compressAvatar(Uint8List bytes) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return null;
      }
      img.Image processed = decoded;
      final maxSide =
          decoded.width >= decoded.height ? decoded.width : decoded.height;
      if (maxSide > _maxAvatarDimension) {
        processed = img.copyResize(
          decoded,
          width:
              decoded.width >= decoded.height
                  ? _maxAvatarDimension
                  : (_maxAvatarDimension * decoded.width / decoded.height)
                      .round(),
          height:
              decoded.height >= decoded.width
                  ? _maxAvatarDimension
                  : (_maxAvatarDimension * decoded.height / decoded.width)
                      .round(),
          interpolation: img.Interpolation.linear,
        );
      }
      final hasAlpha = processed.hasAlpha;
      if (hasAlpha) {
        final encoded = img.encodePng(processed, level: 6);
        return _CompressedAvatar(
          bytes: Uint8List.fromList(encoded),
          extension: 'png',
        );
      }
      final encoded = img.encodeJpg(processed, quality: 80);
      return _CompressedAvatar(
        bytes: Uint8List.fromList(encoded),
        extension: 'jpg',
      );
    } catch (_) {
      return null;
    }
  }

  String? _fallbackExtensionForUpload(String? rawExtension) {
    if (rawExtension == null || rawExtension.isEmpty) {
      return null;
    }
    final lower = rawExtension.toLowerCase();
    switch (lower) {
      case 'jpeg':
      case 'jpg':
        return 'jpg';
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      default:
        return null;
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage:
                          _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child:
                          _avatarUrl == null
                              ? Text(
                                _avatarInitials(),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              )
                              : null,
                    ),
                    if (_isUploadingAvatar)
                      SizedBox(
                        height: 76,
                        width: 76,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _isUploadingAvatar ? null : _pickAvatar,
                        icon:
                            _isUploadingAvatar
                                ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.upload_rounded),
                        label: Text(
                          _avatarUrl == null
                              ? 'Carica foto'
                              : 'Sostituisci foto',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            (_avatarUrl == null || _isUploadingAvatar)
                                ? null
                                : _removeAvatar,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Rimuovi'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Consigliato: immagine quadrata, massimo 2 MB.',
              style: theme.textTheme.bodySmall,
            ),
            if (_avatarError != null) ...[
              const SizedBox(height: 8),
              Text(
                _avatarError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
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
              FormField<List<String>>(
                initialValue: List<String>.from(_selectedRoleIds),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Seleziona almeno una mansione'
                            : null,
                builder: (field) {
                  final errorText = field.errorText;
                  return InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Mansioni',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          sortedRoles
                              .map(
                                (role) => FilterChip(
                                  label: Text(role.displayName),
                                  selected: _selectedRoleIds.contains(role.id),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        if (!_selectedRoleIds.contains(
                                          role.id,
                                        )) {
                                          _selectedRoleIds = List<String>.from(
                                            _selectedRoleIds,
                                          )..add(role.id);
                                        }
                                      } else {
                                        _selectedRoleIds =
                                            _selectedRoleIds
                                                .where(
                                                  (value) => value != role.id,
                                                )
                                                .toList();
                                      }
                                    });
                                    field.didChange(
                                      List<String>.from(_selectedRoleIds),
                                    );
                                  },
                                ),
                              )
                              .toList(),
                    ),
                  );
                },
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
    if (!_hasRoles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aggiungi una mansione prima di salvare.'),
        ),
      );
      return;
    }
    final normalizedRoles = _normalizeRoleIds(_selectedRoleIds);
    if (normalizedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno una mansione.')),
      );
      return;
    }
    if (_salonId == null || _salonId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Specifica un salone di riferimento')),
      );
      return;
    }

    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final staff = StaffMember(
      id: _staffId,
      salonId: _salonId!,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      roleIds: normalizedRoles,
      phone: phone.isEmpty ? null : phone,
      email: email.isEmpty ? null : email,
      dateOfBirth: _dateOfBirth,
      vacationAllowance: _parseAllowance(
        _vacationAllowanceController,
        StaffMember.defaultVacationAllowance,
      ),
      permissionAllowance: _parseAllowance(
        _permissionAllowanceController,
        StaffMember.defaultPermissionAllowance,
      ),
      avatarUrl: _avatarUrl,
      avatarStoragePath: _avatarStoragePath,
    );
    final storage = ref.read(firebaseStorageServiceProvider);
    for (final path in _pathsToDeleteOnSave) {
      if (path.isNotEmpty && path != _avatarStoragePath) {
        unawaited(storage.deleteFile(path));
      }
    }
    _hasSaved = true;
    Navigator.of(context).pop(staff);
  }
}
