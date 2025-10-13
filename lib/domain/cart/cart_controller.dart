import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'cart_models.dart';
import '../../services/payments/stripe_payments_service.dart';

final _uuid = Uuid();

class CartController extends StateNotifier<CartState> {
  CartController({
    required StripePaymentsService paymentsService,
    FirebaseFirestore? firestore,
  }) : _paymentsService = paymentsService,
       _firestore = firestore ?? FirebaseFirestore.instance,
       super(const CartState());

  final StripePaymentsService _paymentsService;
  final FirebaseFirestore _firestore;

  void addItem(CartItem item) {
    final existingIndex = state.items.indexWhere(
      (entry) => entry.id == item.id,
    );
    if (existingIndex >= 0) {
      final updated = state.items.toList(growable: true);
      final current = updated[existingIndex];
      updated[existingIndex] = current.copyWith(
        quantity: current.quantity + item.quantity,
      );
      state = state.copyWith(items: List<CartItem>.unmodifiable(updated));
    } else {
      state = state.copyWith(
        items: List<CartItem>.unmodifiable([...state.items, item]),
      );
    }
  }

  void setQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }
    final updated = state.items.toList(growable: true);
    final index = updated.indexWhere((item) => item.id == itemId);
    if (index < 0) {
      return;
    }
    updated[index] = updated[index].copyWith(quantity: quantity);
    state = state.copyWith(items: List<CartItem>.unmodifiable(updated));
  }

  void removeItem(String itemId) {
    final updated = state.items
        .where((item) => item.id != itemId)
        .toList(growable: false);
    state = state.copyWith(items: updated);
  }

  void clear() {
    state = state.clearTransient().copyWith(items: const <CartItem>[]);
  }

  Future<StripeCheckoutResult> checkout({
    required String salonId,
    required String clientId,
    String currency = 'eur',
    String? salonStripeAccountId,
    String? customerId,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    if (state.items.isEmpty) {
      throw StateError('Il carrello è vuoto.');
    }

    if (!_paymentsService.isConfigured) {
      throw StateError(
        'Stripe non è configurato. Assicurati di impostare STRIPE_PUBLISHABLE_KEY nei dart-define.',
      );
    }

    final cartId = _uuid.v4();
    final snapshot = CartSnapshot(
      id: cartId,
      clientId: clientId,
      salonId: salonId,
      currency: currency,
      items: state.items,
      metadata: additionalMetadata,
    );

    state = state.copyWith(
      isProcessing: true,
      lastError: null,
      lastCartId: cartId,
      lastPaymentIntentId: null,
    );

    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection('carts')
        .doc(cartId);
    await docRef.set(snapshot.toFirestore());

    try {
      final result = await _paymentsService.checkoutCart(
        cart: snapshot,
        salonStripeAccountId: salonStripeAccountId,
        customerId: customerId,
      );

      await _safeUpdateCart(docRef, <String, dynamic>{
        'status': 'submitted',
        'paymentIntentId': result.paymentIntentId,
        'clientSecret': kDebugMode ? result.clientSecret : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      state = CartState(
        items: const <CartItem>[],
        isProcessing: false,
        lastError: null,
        lastPaymentIntentId: result.paymentIntentId,
        lastCartId: cartId,
      );

      return result;
    } catch (error, stackTrace) {
      debugPrint('Checkout fallito: $error');
      debugPrintStack(stackTrace: stackTrace);

      await _safeUpdateCart(docRef, <String, dynamic>{
        'status': 'failed',
        'errorMessage': error.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      state = state.copyWith(
        isProcessing: false,
        lastError: error.toString(),
        lastPaymentIntentId: null,
      );

      rethrow;
    }
  }

  Future<void> _safeUpdateCart(
    DocumentReference<Map<String, dynamic>> docRef,
    Map<String, dynamic> data,
  ) async {
    try {
      await docRef.set(data, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint(
          'Cart update skipped due to permission denied (likely already processed server-side).',
        );
        return;
      }
      rethrow;
    }
  }
}
