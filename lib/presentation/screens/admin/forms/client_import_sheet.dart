import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_import.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/services/clients/client_csv_importer.dart';

class ClientImportSheet extends ConsumerStatefulWidget {
  const ClientImportSheet({
    super.key,
    required this.salons,
    required this.clients,
    this.defaultSalonId,
  });

  final List<Salon> salons;
  final List<Client> clients;
  final String? defaultSalonId;

  @override
  ConsumerState<ClientImportSheet> createState() => _ClientImportSheetState();
}

class _ClientImportSheetState extends ConsumerState<ClientImportSheet> {
  String? _selectedSalonId;
  bool _isParsing = false;
  bool _isImporting = false;
  String? _selectedFileName;
  ClientImportParseResult? _parseResult;
  final List<_CandidateControllers> _controllers = [];
  final Set<int> _excludedRows = <int>{};
  List<ClientImportCandidate> _workingCandidates = const [];
  List<ClientImportDuplicateGroup> _duplicateGroups = const [];
  Map<int, List<Client>> _existingMatches = const {};

  @override
  void initState() {
    super.initState();
    _selectedSalonId =
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_isParsing) {
      return;
    }
    setState(() {
      _isParsing = true;
      _selectedFileName = null;
      _parseResult = null;
      _excludedRows.clear();
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() {
          _isParsing = false;
        });
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException(
          'Impossibile leggere il contenuto del file selezionato.',
        );
      }

      await _parseFile(file.name, bytes);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la lettura del file: $error')),
      );
      setState(() {
        _isParsing = false;
      });
    }
  }

  Future<void> _parseFile(String? fileName, Uint8List bytes) async {
    final importer = ClientCsvImporter();
    final result = importer.parse(bytes);

    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers.clear();
    _excludedRows.clear();

    if (result.generalIssues.any(
      (issue) => issue.severity == ClientImportIssueSeverity.error,
    )) {
      setState(() {
        _parseResult = result;
        _selectedFileName = fileName;
        _isParsing = false;
        _workingCandidates = const [];
        _duplicateGroups = const [];
        _existingMatches = const {};
      });
      return;
    }

    for (final candidate in result.candidates) {
      final controllers = _CandidateControllers(
        candidate,
        onChanged: _handleCandidateChanged,
      );
      _controllers.add(controllers);
    }

    setState(() {
      _parseResult = result;
      _selectedFileName = fileName;
      _isParsing = false;
    });
    _recomputeCandidates();
  }

  void _handleCandidateChanged() {
    if (!mounted) {
      return;
    }
    _recomputeCandidates();
  }

  void _recomputeCandidates() {
    final baseCandidates = <ClientImportCandidate>[];
    final issuesByIndex = <int, List<ClientImportIssue>>{};

    for (final controller in _controllers) {
      final candidate = controller.build();
      baseCandidates.add(candidate);
      issuesByIndex[candidate.index] = List<ClientImportIssue>.from(
        candidate.issues,
      );
    }

    final includedCandidates =
        baseCandidates
            .where((candidate) => !_excludedRows.contains(candidate.index))
            .toList();

    final duplicates = _detectDuplicateGroups(includedCandidates);
    for (final group in duplicates) {
      for (final index in group.indices) {
        issuesByIndex[index]?.add(
          ClientImportIssue(
            severity: ClientImportIssueSeverity.error,
            message:
                group.type == ClientImportDuplicateType.phone
                    ? 'Telefono duplicato nel file.'
                    : 'Email duplicata nel file.',
          ),
        );
      }
    }

    final existingMatches = _detectExistingMatches(includedCandidates);
    existingMatches.forEach((index, matches) {
      final controller = _controllerForIndex(index);
      final selectedId = controller?.existingClientId;
      final hasSelectedMatch =
          selectedId != null &&
          matches.any((client) => client.id == selectedId);
      if (!hasSelectedMatch) {
        issuesByIndex[index]?.add(
          ClientImportIssue(
            severity: ClientImportIssueSeverity.warning,
            message:
                matches.length == 1
                    ? 'Coincide con un cliente esistente.'
                    : 'Coincide con ${matches.length} clienti esistenti.',
          ),
        );
      }
    });

    final updatedCandidates =
        baseCandidates
            .map(
              (candidate) => candidate.copyWith(
                issues: List.unmodifiable(
                  issuesByIndex[candidate.index] ?? const [],
                ),
              ),
            )
            .toList();

    if (!mounted) {
      return;
    }
    setState(() {
      _workingCandidates = List.unmodifiable(updatedCandidates);
      _duplicateGroups = List.unmodifiable(duplicates);
      _existingMatches = existingMatches.map(
        (key, value) => MapEntry(key, List.unmodifiable(value)),
      );
    });
  }

  List<ClientImportCandidate> get _currentCandidates => _workingCandidates;

  List<ClientImportDuplicateGroup> _detectDuplicateGroups(
    List<ClientImportCandidate> candidates,
  ) {
    final duplicateGroups = <ClientImportDuplicateGroup>[];
    final phoneMap = <String, List<int>>{};
    final emailMap = <String, List<int>>{};

    for (final candidate in candidates) {
      final phone = _normalizePhone(candidate.phone);
      if (phone.isNotEmpty) {
        phoneMap.putIfAbsent(phone, () => []).add(candidate.index);
      }
      final email = candidate.email;
      if (email != null && email.trim().isNotEmpty) {
        final normalizedEmail = _normalizeEmail(email);
        emailMap.putIfAbsent(normalizedEmail, () => []).add(candidate.index);
      }
    }

    void addGroups(Map<String, List<int>> map, ClientImportDuplicateType type) {
      for (final entry in map.entries) {
        final indices = entry.value;
        if (indices.length <= 1) {
          continue;
        }
        indices.sort();
        duplicateGroups.add(
          ClientImportDuplicateGroup(
            indices: List.unmodifiable(indices),
            type: type,
            value: entry.key,
          ),
        );
      }
    }

    addGroups(phoneMap, ClientImportDuplicateType.phone);
    addGroups(emailMap, ClientImportDuplicateType.email);

    return duplicateGroups;
  }

  Map<int, List<Client>> _detectExistingMatches(
    List<ClientImportCandidate> candidates,
  ) {
    final salonId = _selectedSalonId;
    if (salonId == null) {
      return const {};
    }

    final salonClients =
        widget.clients.where((client) => client.salonId == salonId).toList();

    final phoneIndex = <String, List<Client>>{};
    final emailIndex = <String, List<Client>>{};

    for (final client in salonClients) {
      final normalizedPhone = _normalizePhone(client.phone);
      if (normalizedPhone.isNotEmpty) {
        phoneIndex.putIfAbsent(normalizedPhone, () => []).add(client);
      }
      final email = client.email?.trim();
      if (email != null && email.isNotEmpty) {
        final normalizedEmail = _normalizeEmail(email);
        emailIndex.putIfAbsent(normalizedEmail, () => []).add(client);
      }
    }

    final matchesByCandidate = <int, List<Client>>{};

    for (final candidate in candidates) {
      final matches = <Client>{};
      final normalizedPhone = _normalizePhone(candidate.phone);
      if (normalizedPhone.isNotEmpty) {
        matches.addAll(phoneIndex[normalizedPhone] ?? const []);
      }
      final email = candidate.email;
      if (email != null && email.trim().isNotEmpty) {
        final normalizedEmail = _normalizeEmail(email);
        matches.addAll(emailIndex[normalizedEmail] ?? const []);
      }
      if (matches.isNotEmpty) {
        matchesByCandidate[candidate.index] = matches.toList();
      }
    }

    return matchesByCandidate;
  }

  _CandidateControllers? _controllerForIndex(int index) {
    return _controllers.firstWhereOrNull(
      (controller) => controller.index == index,
    );
  }

  bool get _canImport {
    if (_isParsing || _isImporting) {
      return false;
    }
    if (_controllers.isEmpty) {
      return false;
    }
    if (_selectedSalonId == null) {
      return false;
    }
    final candidates = _currentCandidates;
    final included = candidates.where(
      (candidate) => !_excludedRows.contains(candidate.index),
    );
    if (included.isEmpty) {
      return false;
    }
    return included.every((candidate) => !candidate.hasErrors);
  }

  Future<void> _import() async {
    if (!_canImport) {
      return;
    }
    final salonId = _selectedSalonId;
    if (salonId == null) {
      return;
    }
    final candidates =
        _currentCandidates
            .where((candidate) => !_excludedRows.contains(candidate.index))
            .toList();
    final drafts = candidates.map((candidate) => candidate.toDraft()).toList();

    setState(() {
      _isImporting = true;
    });

    try {
      final result = await ref
          .read(appDataProvider.notifier)
          .bulkImportClients(salonId: salonId, drafts: drafts);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import fallito: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  void _toggleRow(int index, bool include) {
    if (include) {
      _excludedRows.remove(index);
    } else {
      _excludedRows.add(index);
    }
    _recomputeCandidates();
  }

  void _mergeDuplicateGroup(
    ClientImportDuplicateGroup group,
    int primaryIndex,
  ) {
    final primary = _controllerForIndex(primaryIndex);
    if (primary == null) {
      return;
    }
    final others =
        group.indices
            .where((index) => index != primaryIndex)
            .map(_controllerForIndex)
            .whereType<_CandidateControllers>()
            .toList();
    if (others.isEmpty) {
      return;
    }

    String mergeValue(List<String> values, String fallback) {
      return _firstNonEmpty(values, fallback: fallback);
    }

    final mergedFirstName = mergeValue([
      primary.firstName.text,
      ...others.map((controller) => controller.firstName.text),
    ], 'Cliente');
    final mergedLastName = mergeValue([
      primary.lastName.text,
      ...others.map((controller) => controller.lastName.text),
    ], 'Cliente');
    final mergedPhone = mergeValue([
      primary.phone.text,
      ...others.map((controller) => controller.phone.text),
    ], primary.phone.text);
    final mergedEmail = _firstNonEmpty([
      primary.email.text,
      ...others.map((controller) => controller.email.text),
    ]);
    final mergedNotesList =
        [
          primary.notes.text,
          ...others.map((controller) => controller.notes.text),
        ].where((value) => value.trim().isNotEmpty).toSet().toList();
    final mergedNotes = mergedNotesList.join('\n');

    primary.firstName.text = mergedFirstName;
    primary.lastName.text = mergedLastName;
    primary.phone.text = mergedPhone;
    primary.email.text = mergedEmail;
    primary.notes.text = mergedNotes;

    for (final controller in others) {
      _excludedRows.add(controller.index);
    }

    _recomputeCandidates();
  }

  String _firstNonEmpty(Iterable<String> values, {String fallback = ''}) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  Client? _selectedExistingClientFor(int index) {
    final controller = _controllerForIndex(index);
    if (controller == null) {
      return null;
    }
    final id = controller.existingClientId;
    if (id == null) {
      return null;
    }
    return widget.clients.firstWhereOrNull((client) => client.id == id);
  }

  Future<void> _showExistingClientDialog(
    int candidateIndex,
    List<Client> matches,
  ) async {
    if (matches.isEmpty) {
      return;
    }
    final controller = _controllerForIndex(candidateIndex);
    if (controller == null) {
      return;
    }

    final selectedId = await showModalBottomSheet<String?>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abbina a cliente esistente',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...matches.map((client) {
                    final email = client.email;
                    final subtitleParts = <String>[
                      client.phone,
                      if (email != null && email.isNotEmpty) email,
                    ];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline_rounded),
                      title: Text(client.fullName),
                      subtitle:
                          subtitleParts.isEmpty
                              ? null
                              : Text(subtitleParts.join(' • ')),
                      trailing:
                          controller.existingClientId == client.id
                              ? const Icon(Icons.check_circle_rounded)
                              : null,
                      onTap: () => Navigator.of(ctx).pop(client.id),
                    );
                  }),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_add_alt_1_rounded),
                    title: const Text('Crea come nuovo cliente'),
                    onTap: () => Navigator.of(ctx).pop(null),
                  ),
                ],
              ),
            ),
          ),
    );

    if (!mounted) {
      return;
    }

    controller.setExistingClientId(selectedId);
    _recomputeCandidates();
  }

  void _clearExistingClient(int index) {
    final controller = _controllerForIndex(index);
    if (controller == null) {
      return;
    }
    controller.setExistingClientId(null);
    _recomputeCandidates();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidates = _currentCandidates;
    final includedCount =
        candidates
            .where((candidate) => !_excludedRows.contains(candidate.index))
            .length;
    final generalIssues = _parseResult?.generalIssues ?? const [];
    final duplicateGroups = _duplicateGroups;
    final candidateLookup = {
      for (final candidate in candidates) candidate.index: candidate,
    };
    final existingMatches = _existingMatches;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Importa clienti da CSV', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                'Seleziona il salone di destinazione, carica un file CSV con le colonne '
                '"Nome", "Telefono" ed eventualmente "Mail" e "Note". '
                'Puoi modificare le righe prima di confermare l\'import.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSalonId,
                decoration: const InputDecoration(
                  labelText: 'Salone di destinazione',
                ),
                items:
                    widget.salons
                        .map(
                          (salon) => DropdownMenuItem<String>(
                            value: salon.id,
                            child: Text(salon.name),
                          ),
                        )
                        .toList(),
                onChanged:
                    _isParsing || _isImporting
                        ? null
                        : (value) {
                          setState(() => _selectedSalonId = value);
                          if (_controllers.isNotEmpty) {
                            _recomputeCandidates();
                          }
                        },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _isParsing || _isImporting ? null : _pickFile,
                    icon:
                        _isParsing
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.file_upload_rounded),
                    label: const Text('Carica CSV'),
                  ),
                  const SizedBox(width: 16),
                  if (_selectedFileName != null)
                    Expanded(
                      child: Text(
                        'File selezionato: $_selectedFileName',
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              if (generalIssues.isNotEmpty) ...[
                const SizedBox(height: 16),
                _IssuesBox(issues: generalIssues),
              ],
              if (duplicateGroups.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Possibili duplicati nel file',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...duplicateGroups.map<Widget>((group) {
                  final groupCandidates =
                      group.indices
                          .map((index) => candidateLookup[index])
                          .whereType<ClientImportCandidate>()
                          .toList();
                  if (groupCandidates.length <= 1) {
                    return const SizedBox.shrink();
                  }
                  final title =
                      group.type == ClientImportDuplicateType.phone
                          ? 'Telefono duplicato (${group.value})'
                          : 'Email duplicata (${group.value})';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 12),
                          ...groupCandidates.map((candidate) {
                            final details = <String>[];
                            if (candidate.phone.isNotEmpty) {
                              details.add(candidate.phone);
                            }
                            if (candidate.email != null &&
                                candidate.email!.isNotEmpty) {
                              details.add(candidate.email!);
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Riga ${candidate.index}: '
                                '${candidate.rawName.isEmpty ? candidate.firstName : candidate.rawName}'
                                '${details.isEmpty ? '' : '\n${details.join(' • ')}'}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            );
                          }),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final candidate in groupCandidates)
                                FilledButton.tonal(
                                  onPressed:
                                      () => _mergeDuplicateGroup(
                                        group,
                                        candidate.index,
                                      ),
                                  child: Text(
                                    'Unisci su riga ${candidate.index}',
                                  ),
                                ),
                              for (final candidate in groupCandidates)
                                OutlinedButton(
                                  onPressed:
                                      () => _toggleRow(candidate.index, false),
                                  child: Text(
                                    'Escludi riga ${candidate.index}',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              if (_controllers.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'Carica un file CSV per visualizzare l\'anteprima dei clienti.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      final controller = _controllers[index];
                      final isIncluded =
                          !_excludedRows.contains(candidate.index);
                      final matches =
                          existingMatches[candidate.index] ?? const <Client>[];
                      final selectedExisting = _selectedExistingClientFor(
                        candidate.index,
                      );
                      return _CandidateCard(
                        candidate: candidate,
                        controllers: controller,
                        isIncluded: isIncluded,
                        onToggleIncluded:
                            (value) => _toggleRow(candidate.index, value),
                        existingMatches: matches,
                        selectedExisting: selectedExisting,
                        onManageExisting:
                            matches.isEmpty
                                ? null
                                : () => _showExistingClientDialog(
                                  candidate.index,
                                  matches,
                                ),
                        onClearExisting:
                            selectedExisting == null
                                ? null
                                : () => _clearExistingClient(candidate.index),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Righe incluse: $includedCount',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed:
                            _isImporting
                                ? null
                                : () => Navigator.of(context).pop(),
                        child: const Text('Annulla'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _canImport ? _import : null,
                        child:
                            _isImporting
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Importa clienti'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _normalizeEmail(String value) {
    return value.trim().toLowerCase();
  }
}

class _CandidateControllers {
  _CandidateControllers(
    ClientImportCandidate candidate, {
    required VoidCallback onChanged,
  }) : index = candidate.index,
       rawName = candidate.rawName,
       existingClientId = candidate.existingClientId,
       _onChanged = onChanged,
       firstName = TextEditingController(text: candidate.firstName),
       lastName = TextEditingController(text: candidate.lastName),
       phone = TextEditingController(text: candidate.phone),
       email = TextEditingController(text: candidate.email ?? ''),
       notes = TextEditingController(text: candidate.notes ?? '') {
    firstName.addListener(onChanged);
    lastName.addListener(onChanged);
    phone.addListener(onChanged);
    email.addListener(onChanged);
    notes.addListener(onChanged);
  }

  final int index;
  final String rawName;
  String? existingClientId;
  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController notes;
  final VoidCallback _onChanged;

  ClientImportCandidate build() {
    final issues = <ClientImportIssue>[];
    final normalizedFirst = firstName.text.trim();
    final normalizedLast = lastName.text.trim();
    final normalizedPhone = phone.text.trim();
    final normalizedEmail = email.text.trim();
    final normalizedNotes = notes.text.trim();

    var resolvedFirst = normalizedFirst;
    var resolvedLast = normalizedLast;

    if (resolvedFirst.isEmpty) {
      resolvedFirst = 'Cliente';
      issues.add(
        const ClientImportIssue(
          severity: ClientImportIssueSeverity.warning,
          message: 'Nome mancante, uso del valore predefinito.',
        ),
      );
    }

    if (resolvedLast.isEmpty) {
      resolvedLast = 'Cliente';
      issues.add(
        const ClientImportIssue(
          severity: ClientImportIssueSeverity.warning,
          message: 'Cognome mancante, uso del valore predefinito.',
        ),
      );
    }

    if (normalizedPhone.isEmpty) {
      issues.add(
        const ClientImportIssue(
          severity: ClientImportIssueSeverity.error,
          message: 'Telefono mancante.',
        ),
      );
    }

    if (normalizedEmail.isNotEmpty && !_looksLikeEmail(normalizedEmail)) {
      issues.add(
        const ClientImportIssue(
          severity: ClientImportIssueSeverity.warning,
          message: 'Formato email non riconosciuto.',
        ),
      );
    }

    return ClientImportCandidate(
      index: index,
      firstName: resolvedFirst,
      lastName: resolvedLast,
      phone: normalizedPhone,
      rawName: rawName,
      email: normalizedEmail.isEmpty ? null : normalizedEmail,
      notes: normalizedNotes.isEmpty ? null : normalizedNotes,
      existingClientId: existingClientId,
      issues: issues,
    );
  }

  void setExistingClientId(String? value) {
    if (existingClientId == value) {
      return;
    }
    existingClientId = value;
    _onChanged();
  }

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    email.dispose();
    notes.dispose();
  }

  bool _looksLikeEmail(String value) {
    return value.contains('@') && value.contains('.');
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.controllers,
    required this.isIncluded,
    required this.onToggleIncluded,
    required this.existingMatches,
    this.selectedExisting,
    this.onManageExisting,
    this.onClearExisting,
  });

  final ClientImportCandidate candidate;
  final _CandidateControllers controllers;
  final bool isIncluded;
  final ValueChanged<bool> onToggleIncluded;
  final List<Client> existingMatches;
  final Client? selectedExisting;
  final VoidCallback? onManageExisting;
  final VoidCallback? onClearExisting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = candidate.hasErrors && isIncluded;
    final hasWarning = candidate.hasWarnings && isIncluded && !hasError;
    final borderColor =
        hasError
            ? theme.colorScheme.error
            : hasWarning
            ? theme.colorScheme.tertiary
            : theme.colorScheme.outlineVariant;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isIncluded,
                  onChanged: (value) => onToggleIncluded(value ?? true),
                ),
                Expanded(
                  child: Text(
                    'Riga ${candidate.index}: ${candidate.rawName.isEmpty ? 'Cliente senza nome' : candidate.rawName}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllers.firstName,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllers.lastName,
              decoration: const InputDecoration(labelText: 'Cognome'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllers.phone,
              decoration: const InputDecoration(labelText: 'Telefono'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllers.email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllers.notes,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 2,
            ),
            if ((existingMatches.isNotEmpty && onManageExisting != null) ||
                selectedExisting != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedExisting != null) ...[
                      Text(
                        'Collegato a ${selectedExisting!.fullName}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        selectedExisting!.phone,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (onClearExisting != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onClearExisting,
                            icon: const Icon(Icons.link_off_rounded),
                            label: const Text('Rimuovi collegamento'),
                          ),
                        ),
                    ] else ...[
                      Text(
                        existingMatches.length == 1
                            ? 'Trovato 1 potenziale duplicato nel salone.'
                            : 'Trovati ${existingMatches.length} potenziali duplicati nel salone.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (existingMatches.isNotEmpty && onManageExisting != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: onManageExisting,
                          icon: const Icon(Icons.manage_accounts_rounded),
                          label: Text(
                            selectedExisting == null
                                ? 'Gestisci duplicati'
                                : 'Cambia collegamento',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (isIncluded && candidate.issues.isNotEmpty) ...[
              const SizedBox(height: 12),
              _IssuesBox(issues: candidate.issues),
            ],
          ],
        ),
      ),
    );
  }
}

class _IssuesBox extends StatelessWidget {
  const _IssuesBox({required this.issues});

  final List<ClientImportIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            issues
                .map(
                  (issue) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        issue.severity == ClientImportIssueSeverity.error
                            ? Icons.error_outline
                            : Icons.warning_amber_rounded,
                        size: 18,
                        color:
                            issue.severity == ClientImportIssueSeverity.error
                                ? theme.colorScheme.error
                                : theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          issue.message,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
      ),
    );
  }
}
