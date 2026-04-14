import 'package:you_book/domain/entities/client.dart';

/// Shared utilities to filter clients by general text or client number.
class ClientSearchUtils {
  const ClientSearchUtils._();

  static const int minGeneralQueryLength = 3;
  static const String minSearchCriteriaMessage =
      'Inserisci almeno 3 caratteri oppure un numero cliente';

  static bool hasMinimumGeneralQueryLength(String query) {
    return query.trim().length >= minGeneralQueryLength;
  }

  static bool hasClientNumberQuery(String query) {
    return query.trim().isNotEmpty;
  }

  static bool hasSearchableQueryForMode({
    required String query,
    required bool isClientNumber,
  }) {
    return isClientNumber
        ? hasClientNumberQuery(query)
        : hasMinimumGeneralQueryLength(query);
  }

  static bool hasShortQueryForMode({
    required String query,
    required bool isClientNumber,
  }) {
    final trimmedQuery = query.trim();
    return !isClientNumber &&
        trimmedQuery.isNotEmpty &&
        trimmedQuery.length < minGeneralQueryLength;
  }

  static bool hasSearchableCriteria({
    String generalQuery = '',
    String clientNumberQuery = '',
  }) {
    return hasMinimumGeneralQueryLength(generalQuery) ||
        hasClientNumberQuery(clientNumberQuery);
  }

  static bool hasShortGeneralQuery({
    String generalQuery = '',
    String clientNumberQuery = '',
  }) {
    final trimmedGeneral = generalQuery.trim();
    return trimmedGeneral.isNotEmpty &&
        trimmedGeneral.length < minGeneralQueryLength &&
        !hasClientNumberQuery(clientNumberQuery);
  }

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

  static List<Client> rankedClients({
    required Iterable<Client> clients,
    String generalQuery = '',
    String clientNumberQuery = '',
    String? activeSalonId,
    bool exactNumberMatch = true,
    int? limit,
  }) {
    final ranked = filterClients(
      clients: clients,
      generalQuery: generalQuery,
      clientNumberQuery: clientNumberQuery,
      exactNumberMatch: exactNumberMatch,
    );
    sortClientsForSelection(
      ranked,
      activeSalonId: activeSalonId,
      clientNumberQuery: clientNumberQuery,
    );
    if (limit != null && ranked.length > limit) {
      return ranked.sublist(0, limit);
    }
    return ranked;
  }

  static void sortClientsForSelection(
    List<Client> clients, {
    String? activeSalonId,
    String clientNumberQuery = '',
  }) {
    final normalizedNumber = clientNumberQuery.trim().toLowerCase();
    final hasActiveSalon = activeSalonId != null && activeSalonId.isNotEmpty;
    clients.sort((a, b) {
      final aExactNumber =
          normalizedNumber.isNotEmpty &&
          (a.clientNumber ?? '').trim().toLowerCase() == normalizedNumber;
      final bExactNumber =
          normalizedNumber.isNotEmpty &&
          (b.clientNumber ?? '').trim().toLowerCase() == normalizedNumber;
      if (aExactNumber != bExactNumber) {
        return aExactNumber ? -1 : 1;
      }

      final aPreferredSalon = hasActiveSalon && a.salonId == activeSalonId;
      final bPreferredSalon = hasActiveSalon && b.salonId == activeSalonId;
      if (aPreferredSalon != bPreferredSalon) {
        return aPreferredSalon ? -1 : 1;
      }

      final lastNameCompare = a.lastName.compareTo(b.lastName);
      if (lastNameCompare != 0) {
        return lastNameCompare;
      }
      final firstNameCompare = a.firstName.compareTo(b.firstName);
      if (firstNameCompare != 0) {
        return firstNameCompare;
      }
      return a.id.compareTo(b.id);
    });
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
