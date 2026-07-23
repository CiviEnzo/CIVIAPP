import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/domain/entities/client.dart';

void main() {
  final now = DateTime(2026, 7, 22, 12);

  test('native app is active when it was seen within thirty days', () {
    final client = _client(
      firstAppOpenedAt: now.subtract(const Duration(days: 60)),
      lastAppSeenAt: now.subtract(const Duration(days: 5)),
    );

    expect(client.hasOpenedNativeApp, isTrue);
    expect(client.isNativeAppActiveAt(now), isTrue);
  });

  test('native app is inactive when last usage is older than thirty days', () {
    final client = _client(
      firstAppOpenedAt: now.subtract(const Duration(days: 90)),
      lastAppSeenAt: now.subtract(const Duration(days: 31)),
    );

    expect(client.hasOpenedNativeApp, isTrue);
    expect(client.isNativeAppActiveAt(now), isFalse);
  });

  test('legacy push token remains an active migration fallback', () {
    final client = _client(fcmTokens: const <String>['legacy-token']);

    expect(client.hasOpenedNativeApp, isTrue);
    expect(client.isNativeAppActiveAt(now), isTrue);
  });

  test('client without native usage is never opened', () {
    final client = _client();

    expect(client.hasOpenedNativeApp, isFalse);
    expect(client.isNativeAppActiveAt(now), isFalse);
  });
}

Client _client({
  DateTime? firstAppOpenedAt,
  DateTime? lastAppSeenAt,
  List<String> fcmTokens = const <String>[],
}) {
  return Client(
    id: 'client-1',
    salonId: 'salon-1',
    firstName: 'Mario',
    lastName: 'Rossi',
    phone: '3330000000',
    firstAppOpenedAt: firstAppOpenedAt,
    lastAppSeenAt: lastAppSeenAt,
    fcmTokens: fcmTokens,
  );
}
