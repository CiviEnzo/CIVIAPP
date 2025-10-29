import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/domain/entities/client_import.dart';
import 'package:you_book/services/clients/client_csv_importer.dart';

void main() {
  const importer = ClientCsvImporter();

  test('parses csv rows into candidates', () {
    const csv =
        'Nome;Telefono;Mail\nMario Rossi;3331112222;mario@example.com\n'
        'Anna;3200000000;\n';
    final bytes = Uint8List.fromList(utf8.encode(csv));

    final result = importer.parse(bytes);

    expect(result.generalIssues, isEmpty);
    expect(result.candidates, hasLength(2));
    expect(result.duplicateGroups, isEmpty);

    final first = result.candidates.first;
    expect(first.firstName, equals('Mario'));
    expect(first.lastName, equals('Rossi'));
    expect(first.phone, equals('3331112222'));
    expect(first.email, equals('mario@example.com'));
    expect(first.hasErrors, isFalse);
    expect(first.hasWarnings, isFalse);

    final second = result.candidates[1];
    expect(second.firstName, equals('Anna'));
    expect(second.lastName, equals('Cliente'));
    expect(second.hasWarnings, isTrue);
  });

  test('detects duplicate phone and email values', () {
    const csv =
        'Nome;Telefono;Mail\n'
        'Mario Rossi;3331112222;mario@example.com\n'
        'Anna Bianchi;3331112222;anna@example.com\n'
        'Luca Verdi;3899998888;mario@example.com\n';
    final bytes = Uint8List.fromList(utf8.encode(csv));

    final result = importer.parse(bytes);

    expect(result.duplicateGroups, hasLength(2));

    final phoneDuplicate = result.duplicateGroups.firstWhere(
      (group) => group.type == ClientImportDuplicateType.phone,
    );
    expect(phoneDuplicate.indices, containsAll(<int>[2, 3]));

    final emailDuplicate = result.duplicateGroups.firstWhere(
      (group) => group.type == ClientImportDuplicateType.email,
    );
    expect(emailDuplicate.indices, containsAll(<int>[2, 4]));
  });

  test('reports general issues when required columns are missing', () {
    const csv = 'Nome;Mail\nMario Rossi;mario@example.com\n';
    final bytes = Uint8List.fromList(utf8.encode(csv));

    final result = importer.parse(bytes);

    expect(
      result.generalIssues.where((issue) => issue.message.contains('Telefono')),
      isNotEmpty,
    );
    expect(result.candidates, isEmpty);
  });
}
