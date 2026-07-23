import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/services/payments/stripe_payments_service.dart';

void main() {
  test('translates a declined card error', () {
    expect(
      italianPaymentErrorMessage(Exception('Your card was declined.')),
      'La carta è stata rifiutata. Contatta la banca oppure usa un altro metodo di pagamento.',
    );
  });

  test('translates insufficient funds', () {
    expect(
      italianPaymentErrorMessage(
        StripePaymentsException.failed(message: 'insufficient_funds'),
      ),
      'Fondi insufficienti. Usa un’altra carta o un altro metodo di pagamento.',
    );
  });

  test('explains canceled payments and reassures about charges', () {
    expect(
      italianPaymentErrorMessage(
        StripePaymentsException.canceled(message: 'Payment canceled'),
      ),
      'Pagamento annullato. Non è stato effettuato alcun addebito.',
    );
  });

  test('does not expose unknown technical payment errors', () {
    const rawError = 'Unexpected PaymentIntent backend failure';

    final message = italianPaymentErrorMessage(Exception(rawError));

    expect(
      message,
      'Il servizio di pagamento è temporaneamente non disponibile. Riprova tra qualche minuto.',
    );
    expect(message, isNot(contains(rawError)));
  });
}
