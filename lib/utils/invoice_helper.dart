import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/sale.dart';
import '../models/customer.dart';

class InvoiceHelper {
  static final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');
  static final _dateFormat = DateFormat('dd-MM-yyyy hh:mm a');

  /// Generates a beautiful PDF Invoice matching the Platinum & Rose Gold theme.
  static Future<Uint8List> generateInvoicePdf(Sale sale, Customer customer) async {
    final pdf = pw.Document();

    final roseGoldColor = PdfColor.fromHex('#B76E79');
    final charcoalColor = PdfColor.fromHex('#2E2E3A');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Logo / Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: charcoalColor,
                        ),
                      ),
                      pw.Text(
                        'Smart Business Invoice',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: roseGoldColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'ID: ${sale.id.substring(0, sale.id.length.clamp(0, 8))}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: charcoalColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: roseGoldColor, thickness: 2),
              pw.SizedBox(height: 16),

              // Billing Details Section
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BILLED TO:',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: roseGoldColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          customer.name,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: charcoalColor,
                          ),
                        ),
                        if (customer.phone.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Phone: ${customer.phone}',
                            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'INVOICE DETAILS:',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: roseGoldColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Date: ${_dateFormat.format(sale.saleDate)}',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 32),

              // Items Table
               pw.TableHelper.fromTextArray(
                border: const pw.TableBorder(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  left: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  right: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: charcoalColor,
                  fontSize: 12,
                ),
                headers: ['Product Name', 'Price', 'Qty', 'Total'],
                data: sale.items.map((item) {
                  return [
                    item.productName,
                    _currencyFormat.format(item.unitPrice),
                    '${item.quantity}',
                    _currencyFormat.format(item.subtotal),
                  ];
                }).toList(),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                },
                cellStyle: pw.TextStyle(fontSize: 11, color: charcoalColor),
                cellDecoration: (int rowIndex, dynamic cellValue, int colIndex) {
                  return const pw.BoxDecoration(color: PdfColors.white);
                },
              ),
              pw.SizedBox(height: 24),

              // Billing Totals Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 12)),
                            pw.Text(_currencyFormat.format(sale.totalAmount), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Paid Amount:', style: const pw.TextStyle(fontSize: 12)),
                            pw.Text(_currencyFormat.format(sale.paidAmount), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Divider(color: roseGoldColor, thickness: 1),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Balance Due:',
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: charcoalColor),
                            ),
                            pw.Text(
                              _currencyFormat.format(sale.balanceDue),
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: sale.balanceDue > 0 ? PdfColors.red : PdfColors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(fontSize: 12, color: roseGoldColor, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Smart Business Ledger — Fast, Secure, and Offline-First',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a clean text receipt optimized for WhatsApp inline messages.
  static String generateShareableText(Sale sale, Customer customer) {
    final buffer = StringBuffer();
    buffer.writeln('*📄 RETAIL RECEIPT*');
    buffer.writeln('------------------------------------------');
    buffer.writeln('*Date:* ${_dateFormat.format(sale.saleDate)}');
    buffer.writeln('*Customer:* ${customer.name}');
    if (customer.phone.isNotEmpty) {
      buffer.writeln('*Phone:* ${customer.phone}');
    }
    buffer.writeln('------------------------------------------');

    var index = 1;
    for (final item in sale.items) {
      buffer.writeln('$index. _${item.productName}_');
      buffer.writeln('    ${item.quantity} pcs x ₹${item.unitPrice.toStringAsFixed(0)} = *₹${item.subtotal.toStringAsFixed(0)}*');
      index++;
    }

    buffer.writeln('------------------------------------------');
    buffer.writeln('*Total Amount:*  ₹${sale.totalAmount.toStringAsFixed(0)}');
    buffer.writeln('*Amount Paid:*  ₹${sale.paidAmount.toStringAsFixed(0)}');

    final due = sale.balanceDue;
    if (due > 0) {
      buffer.writeln('*Balance Due:*  ₹${due.toStringAsFixed(0)} ⚠️');
    } else {
      buffer.writeln('*Balance Due:*  ₹0 (Paid ✓)');
    }
    buffer.writeln('------------------------------------------');
    buffer.writeln('Thank you for shopping with us! 🙏');

    return buffer.toString();
  }

  /// Uses share_plus to share text receipt.
  static Future<void> shareTextReceipt(Sale sale, Customer customer) async {
    final text = generateShareableText(sale, customer);
    await Share.share(
      text,
      subject: 'Receipt — ${customer.name}',
    );
  }
}
