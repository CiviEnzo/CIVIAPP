import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/salon_access_request.dart';

void main() {
  test('approveSalonAccessRequest reuses matching client contacts', () async {
    final store = AppDataStore(
      firestore: null,
      currentUser: null,
      storage: null,
    );
    final existingClient = _client(
      id: 'client-existing',
      email: 'andrea@example.com',
      phone: '3920980081',
    );
    final request = _request(
      email: 'Andrea@Example.com',
      phone: '392 098 0081',
    );
    store.state = store.state.copyWith(
      clients: <Client>[existingClient],
      salonAccessRequests: <SalonAccessRequest>[request],
    );

    await store.approveSalonAccessRequest(request: request);

    expect(store.state.clients, hasLength(1));
    final approvedClient = store.state.clients.single;
    expect(approvedClient.id, existingClient.id);
    expect(approvedClient.email, 'andrea@example.com');
    expect(approvedClient.phone, '392 098 0081');
    expect(
      approvedClient.onboardingStatus,
      ClientOnboardingStatus.onboardingCompleted,
    );

    final approvedRequest = store.state.salonAccessRequests.single;
    expect(approvedRequest.status, SalonAccessRequestStatus.approved);
    expect(approvedRequest.clientId, existingClient.id);
  });

  test('approveSalonAccessRequest rejects ambiguous contact matches', () async {
    final store = AppDataStore(
      firestore: null,
      currentUser: null,
      storage: null,
    );
    final emailClient = _client(
      id: 'client-email',
      email: 'andrea@example.com',
      phone: '3331112222',
    );
    final phoneClient = _client(
      id: 'client-phone',
      email: 'other@example.com',
      phone: '3920980081',
    );
    final request = _request(email: 'andrea@example.com', phone: '3920980081');
    store.state = store.state.copyWith(
      clients: <Client>[emailClient, phoneClient],
      salonAccessRequests: <SalonAccessRequest>[request],
    );

    expect(
      () => store.approveSalonAccessRequest(request: request),
      throwsA(isA<StateError>()),
    );

    expect(store.state.clients, hasLength(2));
    expect(
      store.state.salonAccessRequests.single.status,
      SalonAccessRequestStatus.pending,
    );
  });
}

Client _client({
  required String id,
  required String email,
  required String phone,
}) {
  return Client(
    id: id,
    salonId: 'salon-1',
    firstName: 'Andrea',
    lastName: 'Cliente',
    phone: phone,
    email: email,
    loyaltyInitialPoints: 0,
    loyaltyPoints: 0,
    marketedConsents: const [],
    fcmTokens: const [],
    channelPreferences: const ChannelPreferences(),
    createdAt: DateTime(2026, 1, 1),
  );
}

SalonAccessRequest _request({required String email, required String phone}) {
  return SalonAccessRequest(
    id: 'request-1',
    salonId: 'salon-1',
    userId: 'user-1',
    firstName: 'Andrea',
    lastName: 'D Anna',
    email: email,
    phone: phone,
    status: SalonAccessRequestStatus.pending,
    createdAt: DateTime(2026, 1, 2),
  );
}
