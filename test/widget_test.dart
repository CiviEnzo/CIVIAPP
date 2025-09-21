import 'package:civiapp/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Mostra schermata di login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CiviApp()));
    await tester.pump();

    expect(find.text('Accedi a CiviApp'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Accedi'), findsOneWidget);
  });
}
