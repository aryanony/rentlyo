import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/payment_record_model.dart';
import '../models/deal_model.dart';
import '../core/brand_config.dart';

class ExportService {
  /// Generate Excel file bytes for ledger records
  static List<int>? exportLedgerToExcel(List<PaymentRecordModel> records, Map<String, DealModel> dealsMap) {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Rent Ledger'];
    excel.setDefaultSheet('Rent Ledger');

    // Headers
    sheetObject.appendRow([
      TextCellValue('Month Period'),
      TextCellValue('Unit ID'),
      TextCellValue('Effective Rent (INR)'),
      TextCellValue('Payment Source'),
      TextCellValue('Due from Renter (INR)'),
      TextCellValue('Carried Over Due (INR)'),
      TextCellValue('Amount Paid (INR)'),
      TextCellValue('Amount Pending (INR)'),
      TextCellValue('Status'),
      TextCellValue('Payment Method'),
      TextCellValue('Renter Note'),
    ]);

    for (var r in records) {
      sheetObject.appendRow([
        TextCellValue(r.periodMonth),
        TextCellValue(r.unitId),
        DoubleCellValue(r.effectiveRent),
        TextCellValue(r.paymentSource),
        DoubleCellValue(r.dueFromRenter),
        DoubleCellValue(r.carriedOverDue),
        DoubleCellValue(r.amountPaidByRenter),
        DoubleCellValue(r.amountPending),
        TextCellValue(r.status),
        TextCellValue(r.paymentMethod ?? 'N/A'),
        TextCellValue(r.renterNote ?? ''),
      ]);
    }

    return excel.save();
  }

  /// Generate CSV string for ledger records
  static String exportLedgerToCSV(List<PaymentRecordModel> records) {
    List<List<dynamic>> rows = [
      [
        'Month Period',
        'Unit ID',
        'Effective Rent',
        'Payment Source',
        'Due from Renter',
        'Carried Over Due',
        'Amount Paid',
        'Amount Pending',
        'Status',
        'Payment Method',
        'Renter Note',
      ]
    ];

    for (var r in records) {
      rows.add([
        r.periodMonth,
        r.unitId,
        r.effectiveRent,
        r.paymentSource,
        r.dueFromRenter,
        r.carriedOverDue,
        r.amountPaidByRenter,
        r.amountPending,
        r.status,
        r.paymentMethod ?? 'N/A',
        r.renterNote ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Generate and print/download PDF statement for a single renter
  static Future<void> generatePDFStatement({
    required String renterName,
    required String unitLabel,
    required DealModel deal,
    required List<PaymentRecordModel> records,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('${BrandConfig.brandName} — Payment Ledger Statement',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Tenant Name: $renterName'),
              pw.Text('Unit: $unitLabel'),
              pw.Text('Base Rent: INR ${deal.baseMonthlyRent} | Advance: INR ${deal.advanceAmount}'),
              pw.SizedBox(height: 15),
              pw.TableHelper.fromTextArray(
                headers: ['Month', 'Source', 'Rent', 'Paid', 'Pending', 'Status'],
                data: records
                    .map((r) => [
                          r.periodMonth,
                          r.paymentSource,
                          'INR ${r.effectiveRent.toStringAsFixed(0)}',
                          'INR ${r.amountPaidByRenter.toStringAsFixed(0)}',
                          'INR ${r.amountPending.toStringAsFixed(0)}',
                          r.status,
                        ])
                    .toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  /// Generate Property-wide Monthly Financial Statement PDF Report
  static Future<void> generatePropertySummaryPDF({
    required String propertyName,
    required String periodMonth,
    required double expected,
    required double collected,
    required double pending,
    required List<Map<String, dynamic>> unitRows,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$propertyName — Monthly Revenue Report ($periodMonth)',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Total Rent Expected: INR ${expected.toStringAsFixed(0)}'),
              pw.Text('Total Rent Collected: INR ${collected.toStringAsFixed(0)}'),
              pw.Text('Total Pending Arrears: INR ${pending.toStringAsFixed(0)}'),
              pw.SizedBox(height: 15),
              pw.TableHelper.fromTextArray(
                headers: ['Unit', 'Tenant', 'Monthly Rent', 'Paid', 'Pending', 'Status'],
                data: unitRows
                    .map((r) => [
                          r['unit'] ?? '',
                          r['renter'] ?? '',
                          'INR ${r['rent']}',
                          'INR ${r['paid']}',
                          'INR ${r['pending']}',
                          r['status'] ?? '',
                        ])
                    .toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
