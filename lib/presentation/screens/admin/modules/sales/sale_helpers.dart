import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/cash_flow_entry.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/sale.dart';

Future<void> recordSaleCashFlow({
  required WidgetRef ref,
  required Sale sale,
  required List<Client> clients,
}) async {
  if (sale.paymentStatus == SalePaymentStatus.posticipated) {
    return;
  }
  final cashAmount = sale.paymentStatus == SalePaymentStatus.deposit
      ? sale.paidAmount
      : sale.total;
  final amount = double.parse(cashAmount.toStringAsFixed(2));
  if (amount <= 0) {
    return;
  }
  final clientName =
      clients.firstWhereOrNull((client) => client.id == sale.clientId)?.fullName ??
          'Cliente';
  final entry = CashFlowEntry(
    id: const Uuid().v4(),
    salonId: sale.salonId,
    type: CashFlowType.income,
    amount: amount,
    date: sale.createdAt,
    createdAt: DateTime.now(),
    description: sale.paymentStatus == SalePaymentStatus.deposit
        ? 'Acconto vendita a $clientName'
        : 'Vendita a $clientName',
    category: 'Vendite',
    staffId: sale.staffId,
    clientId: sale.clientId,
  );
  await ref.read(appDataProvider.notifier).upsertCashFlowEntry(entry);
}
