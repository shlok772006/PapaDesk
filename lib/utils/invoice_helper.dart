import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/purchase.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import '../providers/customer_providers.dart';
import '../providers/supplier_providers.dart';

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

  /// Generates a PDF Account Statement for a customer.
  static Future<Uint8List> generateLedgerStatementPdf(Customer customer, List<LedgerEntry> entries) async {
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
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ACCOUNT STATEMENT',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: charcoalColor,
                        ),
                      ),
                      pw.Text(
                        'Smart Business Ledger',
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
                        'DUE: ${_currencyFormat.format(customer.pendingAmount)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: customer.pendingAmount > 0 ? PdfColors.red : PdfColors.green,
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
                          'CUSTOMER DETAILS:',
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
                          'STATEMENT DETAILS:',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: roseGoldColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Generated Date: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 32),

              // Transactions Table
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
                headers: ['Date', 'Type', 'Total / Amount', 'Paid Initially', 'Dues Remaining'],
                data: entries.map((entry) {
                  final dateStr = DateFormat('dd-MM-yyyy').format(entry.date);
                  if (entry.type == 'sale') {
                    final sale = entry.entity as Sale;
                    return [
                      dateStr,
                      'Sale',
                      _currencyFormat.format(sale.totalAmount),
                      _currencyFormat.format(sale.paidAmount),
                      _currencyFormat.format(sale.balanceDue),
                    ];
                  } else {
                    final payment = entry.entity as Payment;
                    return [
                      dateStr,
                      'Payment Received',
                      _currencyFormat.format(payment.amount),
                      '-',
                      '-',
                    ];
                  }
                }).toList(),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
                cellStyle: pw.TextStyle(fontSize: 10, color: charcoalColor),
                cellDecoration: (int rowIndex, dynamic cellValue, int colIndex) {
                  return const pw.BoxDecoration(color: PdfColors.white);
                },
              ),
              pw.SizedBox(height: 24),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 8),
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

  /// Generates a clean text ledger statement optimized for WhatsApp.
  static String generateLedgerStatementText(Customer customer, List<LedgerEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln('*📄 ACCOUNT STATEMENT*');
    buffer.writeln('------------------------------------------');
    buffer.writeln('*Customer:* ${customer.name}');
    if (customer.phone.isNotEmpty) {
      buffer.writeln('*Phone:* ${customer.phone}');
    }
    buffer.writeln('*Current Balance Due:* *₹${customer.pendingAmount.toStringAsFixed(0)}*');
    buffer.writeln('------------------------------------------');
    buffer.writeln('*Recent Ledger History:*');
    buffer.writeln('');

    final limit = entries.length.clamp(0, 10); // Show last 10 entries max
    for (var i = 0; i < limit; i++) {
      final entry = entries[i];
      final dateStr = DateFormat('dd-MM-yyyy').format(entry.date);
      if (entry.type == 'sale') {
        final sale = entry.entity as Sale;
        buffer.writeln('• $dateStr: *Sale*');
        buffer.writeln('  Total: ₹${sale.totalAmount.toStringAsFixed(0)} | Paid: ₹${sale.paidAmount.toStringAsFixed(0)}');
        final dues = sale.balanceDue;
        if (dues > 0) {
          buffer.writeln('  Remaining Sale Dues: *₹${dues.toStringAsFixed(0)}*');
        }
      } else {
        final payment = entry.entity as Payment;
        buffer.writeln('• $dateStr: *Payment Received*');
        buffer.writeln('  Amount: *₹${payment.amount.toStringAsFixed(0)}*');
      }
      buffer.writeln('');
    }

    buffer.writeln('------------------------------------------');
    buffer.writeln('Please review your statement. Thank you! 🙏');
    return buffer.toString();
  }

  /// Uses share_plus to share the ledger statement.
  static Future<void> shareLedgerStatement(Customer customer, List<LedgerEntry> entries) async {
    final text = generateLedgerStatementText(customer, entries);
    await Share.share(
      text,
      subject: 'Ledger Statement — ${customer.name}',
    );
  }

  /// Generates a PDF for a supplier purchase bill.
  static Future<Uint8List> generatePurchasePdf(Purchase purchase, String supplierName, List<Product> allProducts) async {
    final pdf = pw.Document();

    final roseGoldColor = PdfColor.fromHex('#B76E79');
    final charcoalColor = PdfColor.fromHex('#2E2E3A');

    final productMap = {for (var p in allProducts) p.id: p};

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SUPPLIER PURCHASE BILL',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: charcoalColor,
                        ),
                      ),
                      pw.Text(
                        'Smart Business Ledger',
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
                        'ID: ${purchase.id.substring(0, purchase.id.length.clamp(0, 8))}',
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

              // Details Section
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SUPPLIER:',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: roseGoldColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          supplierName,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: charcoalColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'BILL DETAILS:',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: roseGoldColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Date: ${DateFormat('dd-MM-yyyy hh:mm a').format(purchase.purchaseDate)}',
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
                headers: ['Product Name', 'Cost Price', 'Qty', 'Total'],
                data: purchase.items.map((item) {
                  final product = productMap[item.productId];
                  final productName = product?.name ?? 'Unknown Product';
                  final itemTotal = item.quantity * item.unitCost;
                  return [
                    productName,
                    _currencyFormat.format(item.unitCost),
                    '${item.quantity}',
                    _currencyFormat.format(itemTotal),
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

              // Totals Row
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
                            pw.Text('Total Cost:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: charcoalColor)),
                            pw.Text(_currencyFormat.format(purchase.totalCost), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: charcoalColor)),
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

  /// Generates a clean text receipt for supplier purchase.
  static String generatePurchaseShareableText(Purchase purchase, String supplierName, List<Product> allProducts) {
    final productMap = {for (var p in allProducts) p.id: p};
    final buffer = StringBuffer();
    buffer.writeln('*📄 SUPPLIER STOCK PURCHASE*');
    buffer.writeln('------------------------------------------');
    buffer.writeln('*Date:* ${_dateFormat.format(purchase.purchaseDate)}');
    buffer.writeln('*Supplier:* $supplierName');
    buffer.writeln('------------------------------------------');

    var index = 1;
    for (final item in purchase.items) {
      final product = productMap[item.productId];
      final productName = product?.name ?? 'Unknown Product';
      final itemTotal = item.quantity * item.unitCost;
      buffer.writeln('$index. _${productName}_');
      buffer.writeln('    ${item.quantity} pcs x ₹${item.unitCost.toStringAsFixed(0)} = *₹${itemTotal.toStringAsFixed(0)}*');
      index++;
    }

    buffer.writeln('------------------------------------------');
    buffer.writeln('*Total Cost:*  ₹${purchase.totalCost.toStringAsFixed(0)}');
    buffer.writeln('------------------------------------------');
    buffer.writeln('Stock updated successfully in inventory.');

    return buffer.toString();
  }

  /// Shares purchase bill text.
  static Future<void> sharePurchaseBillText(Purchase purchase, String supplierName, List<Product> allProducts) async {
    final text = generatePurchaseShareableText(purchase, supplierName, allProducts);
    await Share.share(
      text,
      subject: 'Stock Purchase Bill — $supplierName',
    );
  }

  /// Generates a PDF Account Statement for a supplier.
  static Future<Uint8List> generateSupplierLedgerStatementPdf(Supplier supplier, List<SupplierLedgerEntry> entries) async {
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
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SUPPLIER ACCOUNT STATEMENT',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: charcoalColor,
                        ),
                      ),
                      pw.Text(
                        'Smart Business Ledger',
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
                        'WE OWE: ${_currencyFormat.format(supplier.pendingAmount)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: supplier.pendingAmount > 0 ? PdfColors.red : PdfColors.green,
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
                          'SUPPLIER DETAILS:',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: roseGoldColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          supplier.name,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: charcoalColor,
                          ),
                        ),
                        if (supplier.phone.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Phone: ${supplier.phone}',
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
                          'STATEMENT DETAILS:',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: roseGoldColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Generated Date: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 32),

              // Transactions Table
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
                headers: ['Date', 'Type', 'Total Cost', 'Paid Initially', 'Dues Added/Reduced'],
                data: entries.map((entry) {
                  final dateStr = DateFormat('dd-MM-yyyy').format(entry.date);
                  if (entry.type == 'purchase') {
                    final p = entry.entity as Purchase;
                    return [
                      dateStr,
                      'Purchase',
                      _currencyFormat.format(p.totalCost),
                      _currencyFormat.format(p.paidAmount),
                      _currencyFormat.format(p.balanceDue),
                    ];
                  } else {
                    final pm = entry.entity as SupplierPayment;
                    return [
                      dateStr,
                      'Payment Made (${pm.method.toUpperCase()})',
                      '-',
                      '-',
                      '-${_currencyFormat.format(pm.amount)}',
                    ];
                  }
                }).toList(),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
                cellStyle: pw.TextStyle(fontSize: 10, color: charcoalColor),
                cellDecoration: (int rowIndex, dynamic cellValue, int colIndex) {
                  return const pw.BoxDecoration(color: PdfColors.white);
                },
              ),
              pw.SizedBox(height: 24),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 8),
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

  /// Generates a clean text ledger statement optimized for WhatsApp.
  static String generateSupplierLedgerStatementText(Supplier supplier, List<SupplierLedgerEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln('*📄 SUPPLIER ACCOUNT STATEMENT*');
    buffer.writeln('------------------------------------------');
    buffer.writeln('*Supplier:* ${supplier.name}');
    if (supplier.phone.isNotEmpty) {
      buffer.writeln('*Phone:* ${supplier.phone}');
    }
    buffer.writeln('*Current We Owe Balance:* *₹${supplier.pendingAmount.toStringAsFixed(0)}*');
    buffer.writeln('------------------------------------------');
    buffer.writeln('*Recent Ledger History:*');
    buffer.writeln('');

    final limit = entries.length.clamp(0, 10);
    for (var i = 0; i < limit; i++) {
      final entry = entries[i];
      final dateStr = DateFormat('dd-MM-yyyy').format(entry.date);
      if (entry.type == 'purchase') {
        final p = entry.entity as Purchase;
        buffer.writeln('• $dateStr: *Stock Purchase*');
        buffer.writeln('  Total: ₹${p.totalCost.toStringAsFixed(0)} | Paid: ₹${p.paidAmount.toStringAsFixed(0)}');
        final dues = p.balanceDue;
        if (dues > 0) {
          buffer.writeln('  Remaining Purchase Dues: *₹${dues.toStringAsFixed(0)}*');
        }
      } else {
        final pm = entry.entity as SupplierPayment;
        buffer.writeln('• $dateStr: *Payment Made (${pm.method.toUpperCase()})*');
        buffer.writeln('  Amount: *₹${pm.amount.toStringAsFixed(0)}*');
      }
      buffer.writeln('');
    }

    buffer.writeln('------------------------------------------');
    buffer.writeln('Please review the statement. Thank you!');
    return buffer.toString();
  }

  /// Shares the supplier statement text.
  static Future<void> shareSupplierLedgerStatement(Supplier supplier, List<SupplierLedgerEntry> entries) async {
    final text = generateSupplierLedgerStatementText(supplier, entries);
    await Share.share(
      text,
      subject: 'Supplier Account Statement — ${supplier.name}',
    );
  }
}
