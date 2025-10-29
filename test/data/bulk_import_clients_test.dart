import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_import.dart';

void main() {
  test('bulkImportClients merges existing clients when requested', () async {
    final store = AppDataStore(
      firestore: null,
      currentUser: null,
      storage: null,
    );
    final existing = Client(
      id: 'existing-client',
      salonId: 'salon-1',
      firstName: 'Mario',
      lastName: 'Rossi',
      phone: '3331112222',
      email: 'mario@old.com',
      notes: 'Nota originale',
      loyaltyInitialPoints: 0,
      loyaltyPoints: 0,
      marketedConsents: const [],
      fcmTokens: const [],
      channelPreferences: const ChannelPreferences(),
    );

    store.state = store.state.copyWith(clients: [existing]);

    final drafts = [
      ClientImportDraft(
        firstName: 'Mario',
        lastName: 'Rossi',
        phone: '3331112222',
        email: 'mario@new.com',
        notes: 'Import note',
        existingClientId: existing.id,
      ),
      const ClientImportDraft(
        firstName: 'Anna',
        lastName: 'Verdi',
        phone: '3339998888',
        email: 'anna@new.com',
        notes: 'Nuova cliente',
      ),
    ];

    final result = await store.bulkImportClients(
      salonId: 'salon-1',
      drafts: drafts,
    );

    expect(result.failures, isEmpty);
    expect(result.successes, hasLength(2));

    final updated = store.state.clients.firstWhere(
      (client) => client.id == existing.id,
    );
    expect(updated.email, equals('mario@new.com'));
    expect(updated.notes, contains('Import note'));

    final newClient = store.state.clients.firstWhere(
      (client) => client.id != existing.id,
    );
    expect(newClient.firstName, equals('Anna'));
    expect(newClient.phone, equals('3339998888'));
  });
}
