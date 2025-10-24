import 'package:you_book/domain/entities/client.dart';

/// Shared utilities to filter clients by general text or client number.
class ClientSearchUtils {
  const ClientSearchUtils._();

  static List<Client> filterClients({
    required Iterable<Client> clients,
    String generalQuery = '',
    String clientNumberQuery = '',
    bool exactNumberMatch = true,
  }) {
    final lowerGeneral = generalQuery.trim().toLowerCase();
    final lowerNumber = clientNumberQuery.trim().toLowerCase();

    return clients
        .where(
          (client) =>
              _matchesGeneral(client, lowerGeneral) &&
              _matchesNumber(client, lowerNumber, exactMatch: exactNumberMatch),
        )
        .toList();
  }

  static bool _matchesGeneral(Client client, String lowerGeneral) {
    if (lowerGeneral.isEmpty) {
      return true;
    }
    bool contains(String? value) =>
        value != null && value.toLowerCase().contains(lowerGeneral);
    return contains(client.firstName) ||
        contains(client.lastName) ||
        contains(client.phone) ||
        contains(client.email);
  }

  static bool _matchesNumber(
    Client client,
    String lowerNumber, {
    required bool exactMatch,
  }) {
    if (lowerNumber.isEmpty) {
      return true;
    }
    final number = client.clientNumber;
    if (number == null) {
      return false;
    }
    final lowerClientNumber = number.toLowerCase();
    return exactMatch
        ? lowerClientNumber == lowerNumber
        : lowerClientNumber.contains(lowerNumber);
  }
}
