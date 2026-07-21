import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/expense.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_aggregator.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_models.dart';

class ReportExportFile {
  const ReportExportFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  XFile toXFile() {
    return XFile.fromData(bytes, mimeType: mimeType, name: fileName);
  }
}

class ReportExportService {
  const ReportExportService();

  Future<ReportExportFile> buildExecutivePdf({
    required ReportsSnapshot snapshot,
  }) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final document = pw.Document();
    final currency = NumberFormat.currency(
      locale: 'it_IT',
      symbol: 'EUR ',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
    final salonName = _sanitizePdfText(
      snapshot.selectedSalon?.name ?? 'YouBook',
    );

    final topServicesRows =
        snapshot.topServices.take(6).map((entry) {
          return <String>[
            _sanitizePdfText(entry.name),
            entry.quantity.toStringAsFixed(0),
            _sanitizePdfText(currency.format(entry.revenue)),
          ];
        }).toList();

    final staffRows =
        snapshot.staffPerformance.take(6).map((row) {
          return <String>[
            _sanitizePdfText(row.staffName),
            _sanitizePdfText(currency.format(row.revenue)),
            '${row.completedAppointments}',
            _formatOccupancy(row.occupancy),
          ];
        }).toList();

    final inventoryRows =
        snapshot.inventoryAlerts.take(6).map((entry) {
          return <String>[
            _sanitizePdfText(entry.item.name),
            _sanitizePdfText(entry.statusLabel),
            entry.item.quantity.toStringAsFixed(0),
            entry.item.threshold.toStringAsFixed(0),
          ];
        }).toList();

    final promotionRows =
        snapshot.promotionEntries.take(6).map((entry) {
          return <String>[
            _sanitizePdfText(entry.promotion.title),
            '${entry.viewCount}',
            '${entry.ctaClicks}',
            _formatPercent(entry.ctr),
          ];
        }).toList();

    final revenueTrendRows =
        snapshot.revenueTrend.take(8).map((point) {
          return <String>[
            _sanitizePdfText(dateFormat.format(point.date)),
            _sanitizePdfText(currency.format(point.value)),
          ];
        }).toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        build: (context) {
          return [
            pw.Text(
              _sanitizePdfText('Report & Analytics'),
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              _sanitizePdfText(salonName),
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              _sanitizePdfText(
                'Periodo ${dateFormat.format(snapshot.comparison.current.start)} - '
                '${dateFormat.format(snapshot.comparison.current.end)}',
              ),
            ),
            pw.Text(
              _sanitizePdfText(
                'Generato il ${dateTimeFormat.format(DateTime.now())}',
              ),
            ),
            pw.SizedBox(height: 18),
            _buildKpiGrid(snapshot: snapshot, currency: currency),
            pw.SizedBox(height: 18),
            _buildSummaryBox(
              title: 'Indicatori secondari',
              rows: [
                _pdfInfoRow(
                  'Appuntamenti completati',
                  '${snapshot.current.completedAppointments}',
                ),
                _pdfInfoRow(
                  'Tasso cancellazioni',
                  _formatPercent(snapshot.current.cancellationRate),
                ),
                _pdfInfoRow(
                  'Tasso no-show',
                  _formatPercent(snapshot.current.noShowRate),
                ),
                _pdfInfoRow(
                  'Clienti di ritorno',
                  _formatPercent(snapshot.current.returningClientsRate),
                ),
                _pdfInfoRow(
                  'Valore medio per cliente',
                  currency.format(snapshot.current.averageRevenuePerClient),
                ),
                _pdfInfoRow(
                  'Alert magazzino',
                  '${snapshot.inventoryAlerts.length}',
                ),
                _pdfInfoRow(
                  'CTR promozioni',
                  _formatPercent(snapshot.promotionCtr),
                ),
              ],
            ),
            if (revenueTrendRows.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildTableSection(
                title: 'Trend fatturato',
                headers: const ['Data', 'Fatturato'],
                rows: revenueTrendRows,
              ),
            ],
            if (topServicesRows.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildTableSection(
                title: 'Top servizi',
                headers: const ['Servizio', 'Qta', 'Fatturato'],
                rows: topServicesRows,
              ),
            ],
            if (staffRows.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildTableSection(
                title: 'Performance staff',
                headers: const [
                  'Staff',
                  'Fatturato',
                  'Completati',
                  'Occupazione',
                ],
                rows: staffRows,
              ),
            ],
            if (inventoryRows.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildTableSection(
                title: 'Alert magazzino',
                headers: const ['Prodotto', 'Stato', 'Giacenza', 'Soglia'],
                rows: inventoryRows,
              ),
            ],
            if (promotionRows.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildTableSection(
                title: 'Marketing & promozioni',
                headers: const ['Promozione', 'View', 'Click', 'CTR'],
                rows: promotionRows,
              ),
            ],
          ];
        },
      ),
    );

    return ReportExportFile(
      fileName: 'report_youbook_$timestamp.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List.fromList(await document.save()),
    );
  }

  ReportExportFile buildCsvDataset({
    required ReportsSnapshot snapshot,
    required ReportExportDataset dataset,
  }) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${dataset.fileStem}_youbook_$timestamp.csv';
    final rows = switch (dataset) {
      ReportExportDataset.sales => _buildSalesRows(snapshot),
      ReportExportDataset.expenses => _buildExpenseRows(snapshot),
      ReportExportDataset.appointments => _buildAppointmentRows(snapshot),
      ReportExportDataset.clients => _buildClientRows(snapshot),
      ReportExportDataset.staff => _buildStaffRows(snapshot),
      ReportExportDataset.inventory => _buildInventoryRows(snapshot),
      ReportExportDataset.marketing => _buildMarketingRows(snapshot),
    };
    final csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    return ReportExportFile(
      fileName: fileName,
      mimeType: 'text/csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
  }

  List<ReportExportFile> buildAllCsvDatasets({
    required ReportsSnapshot snapshot,
  }) {
    return ReportExportDataset.values
        .map((dataset) => buildCsvDataset(snapshot: snapshot, dataset: dataset))
        .toList(growable: false);
  }

  Future<void> shareFiles({
    required List<ReportExportFile> files,
    required String subject,
    String? text,
  }) async {
    if (files.isEmpty) {
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: files.map((file) => file.toXFile()).toList(growable: false),
        subject: subject,
        text: text,
      ),
    );
  }

  pw.Widget _buildKpiGrid({
    required ReportsSnapshot snapshot,
    required NumberFormat currency,
  }) {
    final cards = <List<String>>[
      [
        'Fatturato periodo',
        currency.format(snapshot.current.totalRevenue),
        _deltaLabel(
          current: snapshot.current.totalRevenue,
          previous: snapshot.previous.totalRevenue,
        ),
      ],
      [
        'Nuovi clienti',
        '${snapshot.current.newClients}',
        _deltaLabel(
          current: snapshot.current.newClients.toDouble(),
          previous: snapshot.previous.newClients.toDouble(),
        ),
      ],
      [
        'Uscite periodo',
        currency.format(snapshot.current.totalExpenses),
        _deltaLabel(
          current: snapshot.current.totalExpenses,
          previous: snapshot.previous.totalExpenses,
        ),
      ],
      [
        'Netto',
        currency.format(snapshot.current.netProfit),
        _deltaLabel(
          current: snapshot.current.netProfit,
          previous: snapshot.previous.netProfit,
        ),
      ],
      [
        'Tasso occupazione',
        _formatOccupancy(snapshot.current.occupancy),
        _deltaLabel(
          current: snapshot.current.occupancy.ratio,
          previous: snapshot.previous.occupancy.ratio,
          isRate: true,
        ),
      ],
      [
        'Ticket medio',
        currency.format(snapshot.current.averageTicket),
        _deltaLabel(
          current: snapshot.current.averageTicket,
          previous: snapshot.previous.averageTicket,
        ),
      ],
    ];

    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards
          .map(
            (card) => pw.Container(
              width: 248,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _sanitizePdfText(card[0]),
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    _sanitizePdfText(card[1]),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _sanitizePdfText(card[2]),
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.green700,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  pw.Widget _buildSummaryBox({
    required String title,
    required List<pw.Widget> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _sanitizePdfText(title),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(_sanitizePdfText(label))),
          pw.SizedBox(width: 12),
          pw.Text(_sanitizePdfText(value)),
        ],
      ),
    );
  }

  pw.Widget _buildTableSection({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          _sanitizePdfText(title),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: headers.map(_sanitizePdfText).toList(growable: false),
          data: rows
              .map((row) => row.map(_sanitizePdfText).toList(growable: false))
              .toList(growable: false),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 5,
          ),
          border: pw.TableBorder.all(color: PdfColors.grey300),
        ),
      ],
    );
  }

  List<List<String>> _buildSalesRows(ReportsSnapshot snapshot) {
    final currency = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final rows = <List<String>>[
      [
        'Data',
        'Cliente',
        'Staff',
        'Totale report',
        'Totale scontrino',
        'Metodo',
        'Stato pagamento',
        'Canale',
        'Voci',
      ],
    ];
    for (final entry in snapshot.filteredSales) {
      final sale = entry.sale;
      final clientName =
          snapshot.clientLookup[sale.clientId]?.fullName ?? sale.clientId;
      final staffName =
          sale.staffId == null
              ? ''
              : (snapshot.staffLookup[sale.staffId!]?.fullName ??
                  sale.staffId!);
      rows.add([
        dateFormat.format(sale.createdAt),
        clientName,
        staffName,
        currency.format(entry.amount),
        currency.format(sale.total),
        sale.paymentMethod.label,
        sale.paymentStatus.name,
        sale.source ?? '',
        sale.items.map((item) => item.description).join(' | '),
      ]);
    }
    return rows;
  }

  List<List<String>> _buildExpenseRows(ReportsSnapshot snapshot) {
    final currency = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd/MM/yyyy');
    final rows = <List<String>>[
      [
        'Competenza',
        'Scadenza',
        'Voce',
        'Titolo',
        'Fornitore',
        'Totale',
        'Pagato',
        'Residuo',
        'Stato',
        'Ricorrente',
        'Pagamenti',
      ],
    ];
    for (final expense in snapshot.filteredExpenses) {
      final category =
          snapshot.expenseCategoryLookup[expense.categoryId]?.name ??
          'Senza voce';
      rows.add([
        dateFormat.format(expense.competenceDate),
        dateFormat.format(expense.dueDate),
        category,
        expense.title,
        expense.supplierName ?? '',
        currency.format(expense.totalAmount),
        currency.format(expense.paidAmount),
        currency.format(expense.outstandingAmount),
        expense.resolvedStatus.label,
        expense.isRecurring ? 'si' : 'no',
        expense.payments
            .map(
              (payment) =>
                  '${dateFormat.format(payment.date)} ${currency.format(payment.amount)} ${payment.paymentMethod.label}',
            )
            .join(' | '),
      ]);
    }
    return rows;
  }

  List<List<String>> _buildAppointmentRows(ReportsSnapshot snapshot) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final rows = <List<String>>[
      [
        'Inizio',
        'Fine',
        'Cliente',
        'Staff',
        'Stato',
        'Durata min',
        'Canale',
        'Servizi',
      ],
    ];
    for (final appointment in snapshot.filteredAppointments) {
      final clientName =
          snapshot.clientLookup[appointment.clientId]?.fullName ??
          appointment.clientId;
      final staffName =
          snapshot.staffLookup[appointment.staffId]?.fullName ??
          appointment.staffId;
      final services = appointment.serviceIds
          .map(
            (serviceId) => snapshot.serviceLookup[serviceId]?.name ?? serviceId,
          )
          .join(' | ');
      rows.add([
        dateFormat.format(appointment.start),
        dateFormat.format(appointment.end),
        clientName,
        staffName,
        appointment.status.name,
        '${appointment.duration.inMinutes}',
        appointment.bookingChannel ?? '',
        services,
      ]);
    }
    return rows;
  }

  List<List<String>> _buildClientRows(ReportsSnapshot snapshot) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final rows = <List<String>>[
      [
        'Cliente',
        'Telefono',
        'Email',
        'Creato il',
        'Referral',
        'Attivo nel periodo',
        'Di ritorno',
      ],
    ];
    for (final client in snapshot.filteredClients) {
      final anchor =
          client.createdAt ?? client.firstLoginAt ?? client.invitationSentAt;
      rows.add([
        client.fullName,
        client.phone,
        client.email ?? '',
        anchor == null ? '' : dateFormat.format(anchor),
        client.referralSource ?? '',
        snapshot.currentActiveClientIds.contains(client.id) ? 'Si' : 'No',
        snapshot.currentReturningClientIds.contains(client.id) ? 'Si' : 'No',
      ]);
    }
    return rows;
  }

  List<List<String>> _buildStaffRows(ReportsSnapshot snapshot) {
    final currency = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
      decimalDigits: 2,
    );
    final rows = <List<String>>[
      [
        'Staff',
        'Fatturato',
        'Scontrini',
        'Appuntamenti completati',
        'Ticket medio',
        'Occupazione',
      ],
    ];
    for (final row in snapshot.staffPerformance) {
      rows.add([
        row.staffName,
        currency.format(row.revenue),
        '${row.salesCount}',
        '${row.completedAppointments}',
        currency.format(row.averageTicket),
        _formatOccupancy(row.occupancy),
      ]);
    }
    return rows;
  }

  List<List<String>> _buildInventoryRows(ReportsSnapshot snapshot) {
    final currency = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
      decimalDigits: 2,
    );
    final rows = <List<String>>[
      [
        'Prodotto',
        'Categoria',
        'Giacenza',
        'Soglia',
        'Stato',
        'Costo',
        'Prezzo vendita',
        'Valore stock',
      ],
    ];
    for (final entry in snapshot.inventoryEntries) {
      rows.add([
        entry.item.name,
        entry.item.category,
        entry.item.quantity.toStringAsFixed(0),
        entry.item.threshold.toStringAsFixed(0),
        entry.statusLabel,
        currency.format(entry.item.cost),
        currency.format(entry.item.sellingPrice),
        currency.format(entry.stockValue),
      ]);
    }
    return rows;
  }

  List<List<String>> _buildMarketingRows(ReportsSnapshot snapshot) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final rows = <List<String>>[
      ['Promozione', 'Stato', 'Dal', 'Al', 'View', 'Click CTA', 'CTR'],
    ];
    for (final entry in snapshot.promotionEntries) {
      final promotion = entry.promotion;
      rows.add([
        promotion.title,
        promotion.status.name,
        promotion.startsAt == null
            ? ''
            : dateFormat.format(promotion.startsAt!),
        promotion.endsAt == null ? '' : dateFormat.format(promotion.endsAt!),
        '${entry.viewCount}',
        '${entry.ctaClicks}',
        _formatPercent(entry.ctr),
      ]);
    }
    return rows;
  }

  String _formatOccupancy(ReportOccupancySummary occupancy) {
    final ratio = occupancy.ratio;
    if (ratio == null) {
      return 'N/D';
    }
    final suffix = occupancy.estimated ? ' stimato' : '';
    return '${(ratio * 100).toStringAsFixed(1)}%$suffix';
  }

  String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  String _deltaLabel({
    required double? current,
    required double? previous,
    bool isRate = false,
  }) {
    if (current == null || previous == null) {
      return 'Confronto non disponibile';
    }
    if (isRate) {
      final delta = (current - previous) * 100;
      if (delta.abs() < 0.05) {
        return 'Stabile vs periodo precedente';
      }
      final sign = delta > 0 ? '+' : '';
      return '$sign${delta.toStringAsFixed(1)} pt vs periodo precedente';
    }
    if (previous.abs() < 0.0001) {
      if (current.abs() < 0.0001) {
        return 'Stabile vs periodo precedente';
      }
      return 'Nuovo nel periodo';
    }
    final delta = ((current - previous) / previous) * 100;
    if (delta.abs() < 0.05) {
      return 'Stabile vs periodo precedente';
    }
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)}% vs periodo precedente';
  }

  String _sanitizePdfText(String? input) {
    if (input == null || input.isEmpty) {
      return '';
    }
    const replacements = {
      'à': 'a',
      'è': 'e',
      'é': 'e',
      'ì': 'i',
      'ò': 'o',
      'ù': 'u',
      'À': 'A',
      'È': 'E',
      'É': 'E',
      'Ì': 'I',
      'Ò': 'O',
      'Ù': 'U',
      'ç': 'c',
      'Ç': 'C',
      'ß': 'ss',
      'œ': 'oe',
      'Œ': 'OE',
      '’': "'",
      '‘': "'",
      '“': '"',
      '”': '"',
      '€': 'EUR',
    };
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final replacement = replacements[char];
      if (replacement != null) {
        buffer.write(replacement);
      } else if ((rune >= 32 && rune <= 126) || rune == 10 || rune == 13) {
        buffer.write(char);
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString();
  }
}
