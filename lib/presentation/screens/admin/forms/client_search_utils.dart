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

    final tokens =
        lowerGeneral
            .split(RegExp(r'\s+'))
            .where((token) => token.isNotEmpty)
            .toList();
    if (tokens.isEmpty) {
      return true;
    }

    bool contains(String? value, String token) {
      final normalized = value?.trim().toLowerCase();
      if (normalized == null || normalized.isEmpty) {
        return false;
      }
      return normalized.contains(token);
    }

    bool tokenMatches(String token) {
      return contains(client.fullName, token) ||
          contains(client.firstName, token) ||
          contains(client.lastName, token) ||
          contains(client.phone, token) ||
          contains(client.email, token);
    }

    return tokens.every(tokenMatches);
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
