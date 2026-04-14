import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/presentation/screens/admin/forms/client_search_utils.dart';

void main() {
  test('ClientSearchUtils requires 3 characters for general search', () {
    expect(
      ClientSearchUtils.hasSearchableCriteria(generalQuery: 'ma'),
      isFalse,
    );
    expect(ClientSearchUtils.hasShortGeneralQuery(generalQuery: 'ma'), isTrue);
    expect(
      ClientSearchUtils.hasSearchableCriteria(generalQuery: 'mar'),
      isTrue,
    );
    expect(
      ClientSearchUtils.hasShortGeneralQuery(generalQuery: 'mar'),
      isFalse,
    );
  });

  test('ClientSearchUtils applies minimum length by search mode', () {
    expect(
      ClientSearchUtils.hasSearchableQueryForMode(
        query: 'ma',
        isClientNumber: false,
      ),
      isFalse,
    );
    expect(
      ClientSearchUtils.hasShortQueryForMode(
        query: 'ma',
        isClientNumber: false,
      ),
      isTrue,
    );
    expect(
      ClientSearchUtils.hasSearchableQueryForMode(
        query: 'mar',
        isClientNumber: false,
      ),
      isTrue,
    );
    expect(
      ClientSearchUtils.hasSearchableQueryForMode(
        query: '1',
        isClientNumber: true,
      ),
      isTrue,
    );
    expect(
      ClientSearchUtils.hasShortQueryForMode(query: '1', isClientNumber: true),
      isFalse,
    );
  });

  test(
    'ClientSearchUtils allows client number search without minimum length',
    () {
      expect(
        ClientSearchUtils.hasSearchableCriteria(clientNumberQuery: '1'),
        isTrue,
      );
      expect(
        ClientSearchUtils.hasShortGeneralQuery(
          generalQuery: 'ma',
          clientNumberQuery: '1',
        ),
        isFalse,
      );
    },
  );

  test(
    'ClientSearchUtils filters matching clients once criteria are valid',
    () {
      final clients = [
        Client(
          id: 'client-1',
          salonId: 'salon-1',
          firstName: 'Mario',
          lastName: 'Rossi',
          phone: '3331234567',
          email: 'mario@test.it',
          clientNumber: '101',
        ),
        Client(
          id: 'client-2',
          salonId: 'salon-1',
          firstName: 'Anna',
          lastName: 'Bianchi',
          phone: '3337654321',
          email: 'anna@test.it',
          clientNumber: '202',
        ),
      ];

      final generalMatches = ClientSearchUtils.filterClients(
        clients: clients,
        generalQuery: 'mario',
      );
      final numberMatches = ClientSearchUtils.filterClients(
        clients: clients,
        clientNumberQuery: '202',
      );

      expect(generalMatches.map((client) => client.id), ['client-1']);
      expect(numberMatches.map((client) => client.id), ['client-2']);
    },
  );

  test(
    'ClientSearchUtils ranks exact client number matches and active salon first',
    () {
      final clients = [
        Client(
          id: 'client-1',
          salonId: 'salon-2',
          firstName: 'Marco',
          lastName: 'Blu',
          phone: '3331234567',
          clientNumber: '200',
        ),
        Client(
          id: 'client-2',
          salonId: 'salon-1',
          firstName: 'Mario',
          lastName: 'Rossi',
          phone: '3337654321',
          clientNumber: '101',
        ),
        Client(
          id: 'client-3',
          salonId: 'salon-1',
          firstName: 'Marta',
          lastName: 'Verdi',
          phone: '3330000000',
          clientNumber: '200',
        ),
      ];

      final rankedByNumber = ClientSearchUtils.rankedClients(
        clients: clients,
        clientNumberQuery: '200',
        activeSalonId: 'salon-1',
        exactNumberMatch: false,
      );

      expect(rankedByNumber.map((client) => client.id), [
        'client-3',
        'client-1',
      ]);

      final rankedBySalon = ClientSearchUtils.rankedClients(
        clients: clients,
        generalQuery: 'mar',
        activeSalonId: 'salon-1',
      );

      expect(rankedBySalon.take(2).map((client) => client.id), [
        'client-2',
        'client-3',
      ]);
    },
  );
}
