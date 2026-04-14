import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'cart_models.dart';
import '../../services/payments/stripe_payments_service.dart';

final _uuid = Uuid();

class CartController extends StateNotifier<CartState> {
  CartController({
    required StripePaymentsService paymentsService,
    FirebaseFirestore? firestore,
    Future<SharedPreferences> Function()? sharedPreferencesLoader,
    String? localDraftKey,
  }) : _paymentsService = paymentsService,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _sharedPreferencesLoader = sharedPreferencesLoader,
       _localDraftKey = localDraftKey,
       super(const CartState()) {
    if (_sharedPreferencesLoader != null &&
        _localDraftKey != null &&
        _localDraftKey.isNotEmpty) {
      unawaited(_restoreLocalDraft());
    }
  }

  static const int _localDraftVersion = 1;

  final StripePaymentsService _paymentsService;
  final FirebaseFirestore _firestore;
  final Future<SharedPreferences> Function()? _sharedPreferencesLoader;
  final String? _localDraftKey;

  SharedPreferences? _sharedPreferences;
  bool _localMutationBeforeHydration = false;

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
    _localMutationBeforeHydration = true;
    unawaited(_persistLocalDraft());
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
    _localMutationBeforeHydration = true;
    unawaited(_persistLocalDraft());
  }

  void removeItem(String itemId) {
    final updated = state.items
        .where((item) => item.id != itemId)
        .toList(growable: false);
    state = state.copyWith(items: updated);
    _localMutationBeforeHydration = true;
    unawaited(_persistLocalDraft());
  }

  void clear() {
    state = state.clearTransient().copyWith(items: const <CartItem>[]);
    _localMutationBeforeHydration = true;
    unawaited(_persistLocalDraft());
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
      _localMutationBeforeHydration = true;
      unawaited(_persistLocalDraft());

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
      _localMutationBeforeHydration = true;
      unawaited(_persistLocalDraft());

      rethrow;
    }
  }

  Future<SharedPreferences?> _ensureSharedPreferences() async {
    final loader = _sharedPreferencesLoader;
    if (loader == null) {
      return null;
    }
    final cached = _sharedPreferences;
    if (cached != null) {
      return cached;
    }
    try {
      final resolved = await loader();
      _sharedPreferences = resolved;
      return resolved;
    } catch (error, stackTrace) {
      debugPrint('Cart local storage unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _restoreLocalDraft() async {
    final prefs = await _ensureSharedPreferences();
    final key = _localDraftKey;
    if (prefs == null || key == null || key.isEmpty) {
      return;
    }

    try {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await prefs.remove(key);
        return;
      }
      final payload = Map<String, dynamic>.from(decoded);
      final version = payload['version'];
      if (version is! num || version.toInt() != _localDraftVersion) {
        await prefs.remove(key);
        return;
      }
      final rawItems = payload['items'];
      if (rawItems is! List) {
        await prefs.remove(key);
        return;
      }
      final restoredItems = <CartItem>[];
      for (final rawItem in rawItems) {
        if (rawItem is! Map) {
          continue;
        }
        final item = CartItem.fromLocalMap(Map<String, dynamic>.from(rawItem));
        if (item.id.isEmpty || item.referenceId.isEmpty || item.name.isEmpty) {
          continue;
        }
        restoredItems.add(item);
      }
      if (_localMutationBeforeHydration) {
        return;
      }
      if (restoredItems.isEmpty) {
        return;
      }
      state = CartState(items: List<CartItem>.unmodifiable(restoredItems));
    } catch (error, stackTrace) {
      debugPrint('Failed to restore local cart draft: $error');
      debugPrintStack(stackTrace: stackTrace);
      try {
        await prefs.remove(key);
      } catch (_) {}
    }
  }

  Future<void> _persistLocalDraft() async {
    final prefs = await _ensureSharedPreferences();
    final key = _localDraftKey;
    if (prefs == null || key == null || key.isEmpty) {
      return;
    }

    try {
      if (state.items.isEmpty) {
        await prefs.remove(key);
        return;
      }
      final payload = <String, Object?>{
        'version': _localDraftVersion,
        'items': state.items
            .map((item) => item.toLocalMap())
            .toList(growable: false),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(key, jsonEncode(payload));
    } catch (error, stackTrace) {
      debugPrint('Failed to persist local cart draft: $error');
      debugPrintStack(stackTrace: stackTrace);
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
