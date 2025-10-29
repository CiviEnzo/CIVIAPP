import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:you_book/domain/entities/client_import.dart';

class ClientCsvImporter {
  const ClientCsvImporter();

  ClientImportParseResult parse(Uint8List bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);
    final sanitized = content.replaceAll('\r\n', '\n').trim();
    if (sanitized.isEmpty) {
      return const ClientImportParseResult(
        candidates: [],
        generalIssues: [
          ClientImportIssue(
            severity: ClientImportIssueSeverity.error,
            message: 'Il file di import è vuoto.',
          ),
        ],
      );
    }

    final delimiter = _detectDelimiter(sanitized);
    final converter = CsvToListConverter(
      fieldDelimiter: delimiter,
      shouldParseNumbers: false,
      eol: '\n',
    );

    final rows = converter.convert(sanitized);
    if (rows.isEmpty) {
      return const ClientImportParseResult(
        candidates: [],
        generalIssues: [
          ClientImportIssue(
            severity: ClientImportIssueSeverity.error,
            message: 'Impossibile leggere il file selezionato.',
          ),
        ],
      );
    }

    final headerRow = rows.first.map((cell) => cell?.toString() ?? '').toList();
    final mapping = _ColumnMapping.fromHeader(headerRow);
    final issues = <ClientImportIssue>[];

    if (mapping.phoneIndex == null) {
      issues.add(
        const ClientImportIssue(
          severity: ClientImportIssueSeverity.error,
          message:
              'Colonna telefono non trovata. Aggiungi una colonna "Telefono".',
        ),
      );
    }

    if (mapping.fullNameIndex == null &&
        mapping.firstNameIndex == null &&
        mapping.lastNameIndex == null) {
      issues.add(
        const ClientImportIssue(
          severity: ClientImportIssueSeverity.error,
          message: 'Colonna nome non trovata. Aggiungi una colonna "Nome".',
        ),
      );
    }

    if (issues.any(
      (issue) => issue.severity == ClientImportIssueSeverity.error,
    )) {
      return ClientImportParseResult(
        candidates: const [],
        generalIssues: issues,
      );
    }

    final candidates = <ClientImportCandidate>[];

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final rawRow = rows[rowIndex];
      final row = rawRow.map((cell) => cell?.toString() ?? '').toList();

      if (_isRowEmpty(row)) {
        continue;
      }

      final localIssues = <ClientImportIssue>[];

      final fullName = _resolveValue(row, mapping.fullNameIndex);
      final firstNameRaw = _resolveValue(row, mapping.firstNameIndex);
      final lastNameRaw = _resolveValue(row, mapping.lastNameIndex);
      final phoneRaw = _resolveValue(row, mapping.phoneIndex);
      final emailRaw = _resolveValue(row, mapping.emailIndex);
      final notesRaw = _resolveValue(row, mapping.notesIndex);

      if (phoneRaw.trim().isEmpty) {
        localIssues.add(
          const ClientImportIssue(
            severity: ClientImportIssueSeverity.error,
            message: 'Telefono mancante.',
          ),
        );
      }

      final nameParts = _splitName(
        firstName: firstNameRaw,
        lastName: lastNameRaw,
        fullName: fullName,
      );
      var resolvedFirstName = nameParts.first;
      var resolvedLastName = nameParts.last;

      if (resolvedFirstName.trim().isEmpty || resolvedLastName.trim().isEmpty) {
        localIssues.add(
          const ClientImportIssue(
            severity: ClientImportIssueSeverity.warning,
            message:
                'Nome incompleto. Modifica manualmente o verrà usato un valore di fallback.',
          ),
        );
      }

      final email = emailRaw.trim().isEmpty ? null : emailRaw.trim();
      if (email != null && !_looksLikeEmail(email)) {
        localIssues.add(
          const ClientImportIssue(
            severity: ClientImportIssueSeverity.warning,
            message: 'Formato email non riconosciuto.',
          ),
        );
      }

      resolvedFirstName =
          resolvedFirstName.trim().isEmpty ? '' : resolvedFirstName.trim();
      resolvedLastName =
          resolvedLastName.trim().isEmpty ? '' : resolvedLastName.trim();

      final phone = phoneRaw.trim();

      final candidate = ClientImportCandidate(
        index: rowIndex + 1,
        firstName: resolvedFirstName,
        lastName: resolvedLastName,
        phone: phone,
        rawName:
            (fullName.isNotEmpty
                    ? fullName
                    : [
                      firstNameRaw,
                      lastNameRaw,
                    ].where((value) => value.trim().isNotEmpty).join(' '))
                .trim(),
        email: email,
        notes: notesRaw.trim().isEmpty ? null : notesRaw.trim(),
        issues: localIssues,
      );
      candidates.add(candidate);
    }

    final duplicateGroups = _detectDuplicates(candidates);

    return ClientImportParseResult(
      candidates: List.unmodifiable(candidates),
      generalIssues: List.unmodifiable(issues),
      duplicateGroups: List.unmodifiable(duplicateGroups),
    );
  }

  String _detectDelimiter(String content) {
    final firstLine = content.split('\n').first;
    final semicolons = _countOccurrences(firstLine, ';');
    final commas = _countOccurrences(firstLine, ',');
    if (semicolons >= commas && semicolons > 0) {
      return ';';
    }
    if (commas > 0) {
      return ',';
    }
    return ';';
  }

  int _countOccurrences(String value, String pattern) {
    return value.split(pattern).length - 1;
  }

  bool _isRowEmpty(List<String> row) {
    for (final cell in row) {
      if (cell.trim().isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  String _resolveValue(List<String> row, int? index) {
    if (index == null || index < 0 || index >= row.length) {
      return '';
    }
    return row[index];
  }

  bool _looksLikeEmail(String value) {
    return value.contains('@') && value.contains('.');
  }

  List<String> _splitName({
    required String firstName,
    required String lastName,
    required String fullName,
  }) {
    var resolvedFirstName = firstName.trim();
    var resolvedLastName = lastName.trim();

    if (resolvedFirstName.isNotEmpty && resolvedLastName.isNotEmpty) {
      return [resolvedFirstName, resolvedLastName];
    }

    final source = fullName.trim();
    if (source.isNotEmpty) {
      final tokens =
          source
              .split(RegExp(r'\s+'))
              .where((value) => value.isNotEmpty)
              .toList();
      if (tokens.length >= 2) {
        resolvedFirstName = tokens.first;
        resolvedLastName = tokens.sublist(1).join(' ');
      } else if (tokens.length == 1) {
        resolvedFirstName = tokens.first;
        resolvedLastName = '';
      }
    }

    if (resolvedFirstName.isEmpty && resolvedLastName.isNotEmpty) {
      final tokens = resolvedLastName.split(RegExp(r'\s+'));
      resolvedFirstName = tokens.first;
      resolvedLastName =
          tokens.length > 1 ? tokens.sublist(1).join(' ') : 'Cliente';
    } else if (resolvedLastName.isEmpty && resolvedFirstName.isNotEmpty) {
      resolvedLastName = 'Cliente';
    }

    if (resolvedFirstName.isEmpty) {
      resolvedFirstName = 'Cliente';
    }
    if (resolvedLastName.isEmpty) {
      resolvedLastName = 'Cliente';
    }

    return [resolvedFirstName, resolvedLastName];
  }

  List<ClientImportDuplicateGroup> _detectDuplicates(
    List<ClientImportCandidate> candidates,
  ) {
    final duplicateGroups = <ClientImportDuplicateGroup>[];
    final phoneMap = <String, List<int>>{};
    final emailMap = <String, List<int>>{};

    for (final candidate in candidates) {
      final normalizedPhone = _normalizePhone(candidate.phone);
      if (normalizedPhone.isNotEmpty) {
        phoneMap.putIfAbsent(normalizedPhone, () => []).add(candidate.index);
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

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _normalizeEmail(String value) {
    return value.trim().toLowerCase();
  }
}

class _ColumnMapping {
  _ColumnMapping({
    this.fullNameIndex,
    this.firstNameIndex,
    this.lastNameIndex,
    this.phoneIndex,
    this.emailIndex,
    this.notesIndex,
  });

  final int? fullNameIndex;
  final int? firstNameIndex;
  final int? lastNameIndex;
  final int? phoneIndex;
  final int? emailIndex;
  final int? notesIndex;

  factory _ColumnMapping.fromHeader(List<String> header) {
    int? fullNameIndex;
    int? firstNameIndex;
    int? lastNameIndex;
    int? phoneIndex;
    int? emailIndex;
    int? notesIndex;

    for (var index = 0; index < header.length; index++) {
      final raw = header[index].toLowerCase().trim();
      if (raw.isEmpty) {
        continue;
      }

      if (raw.contains('telefono') ||
          raw.contains('cellulare') ||
          raw.contains('mobile') ||
          raw.contains('phone')) {
        phoneIndex ??= index;
        continue;
      }

      if (raw.contains('mail') || raw.contains('email')) {
        emailIndex ??= index;
        continue;
      }

      if (raw.contains('note') || raw.contains('annotazioni')) {
        notesIndex ??= index;
        continue;
      }

      if (raw.contains('cognom')) {
        lastNameIndex ??= index;
        continue;
      }

      if (raw.contains('nome completo') || raw.contains('cliente')) {
        fullNameIndex ??= index;
        continue;
      }

      if (raw.contains('nome')) {
        firstNameIndex ??= index;
        continue;
      }
    }

    return _ColumnMapping(
      fullNameIndex: fullNameIndex,
      firstNameIndex: firstNameIndex,
      lastNameIndex: lastNameIndex,
      phoneIndex: phoneIndex,
      emailIndex: emailIndex,
      notesIndex: notesIndex,
    );
  }
}
