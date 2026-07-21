import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Exports all business data for a selected month into a single `.xlsx` file
/// with 7 sheets: Sales, Payments Received, Purchases, Supplier Payments,
/// Customers, Products, Suppliers.
///
/// Uses cache-first Firestore queries so it works fully offline.
class ExcelExportHelper {
  static final _db = FirebaseFirestore.instance;
  static final _currencyFmt = NumberFormat('#,##0.00', 'en_IN');
  static final _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  // ─── Public API ──────────────────────────────────────────────

  /// Generates an Excel file for the given [month]/[year] and opens
  /// the system share sheet so the operator can send it via WhatsApp, etc.
  static Future<void> exportMonthlyExcel({
    required int year,
    required int month,
  }) async {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 1); // works even for Dec→Jan
    final monthLabel = DateFormat('MMMM_yyyy').format(monthStart);

    // ── 1. Fetch all data in parallel ──────────────────────────
    final results = await Future.wait([
      _getCollectionData('sales'),          // 0
      _getCollectionData('payments'),       // 1
      _getCollectionData('purchases'),      // 2
      _getCollectionData('supplierPayments'), // 3
      _getCollectionData('customers'),      // 4
      _getCollectionData('products'),       // 5
      _getCollectionData('suppliers'),      // 6
    ]);

    final allSales = results[0];
    final allPayments = results[1];
    final allPurchases = results[2];
    final allSupplierPayments = results[3];
    final allCustomers = results[4];
    final allProducts = results[5];
    final allSuppliers = results[6];

    // ── 2. Build name-lookup maps ──────────────────────────────
    final customerNames = <String, String>{};
    for (final c in allCustomers) {
      customerNames[c['id'] as String] = c['name'] as String? ?? 'Unknown';
    }

    final supplierNames = <String, String>{};
    for (final s in allSuppliers) {
      supplierNames[s['id'] as String] = s['name'] as String? ?? 'Unknown';
    }

    final productNames = <String, String>{};
    for (final p in allProducts) {
      productNames[p['id'] as String] = p['name'] as String? ?? 'Unknown';
    }

    // ── 3. Filter transaction data by month ────────────────────
    final monthlySales = _filterByDate(allSales, 'saleDate', monthStart, monthEnd);
    final monthlyPayments = _filterByDate(allPayments, 'paymentDate', monthStart, monthEnd);
    final monthlyPurchases = _filterByDate(allPurchases, 'purchaseDate', monthStart, monthEnd);
    final monthlySupplierPayments = _filterByDate(allSupplierPayments, 'paymentDate', monthStart, monthEnd);

    // ── 4. Build Excel workbook ────────────────────────────────
    final excel = Excel.createExcel();

    _buildSalesSheet(excel, monthlySales, customerNames);
    _buildPaymentsSheet(excel, monthlyPayments, customerNames);
    _buildPurchasesSheet(excel, monthlyPurchases, supplierNames, productNames);
    _buildSupplierPaymentsSheet(excel, monthlySupplierPayments, supplierNames);
    _buildCustomersSheet(excel, allCustomers);
    _buildProductsSheet(excel, allProducts);
    _buildSuppliersSheet(excel, allSuppliers);

    // Remove the default blank "Sheet1" that the library creates
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // ── 5. Save and share ──────────────────────────────────────
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to generate Excel file');

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/PapaDesk_$monthLabel.xlsx');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'PapaDesk Data — ${DateFormat('MMMM yyyy').format(monthStart)}',
    );
  }

  // ─── Firestore Helpers ───────────────────────────────────────

  /// Fetches all documents from [collectionName], trying cache first
  /// for offline reliability.
  static Future<List<Map<String, dynamic>>> _getCollectionData(String collectionName) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      // Cache first — works offline
      snap = await _db.collection(collectionName).get(const GetOptions(source: Source.cache));
    } catch (_) {
      // Cache miss — try server
      snap = await _db.collection(collectionName).get(const GetOptions(source: Source.server));
    }
    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Filters documents where [dateField] (stored as Timestamp epoch millis
  /// or Firestore Timestamp) falls within [start, end).
  static List<Map<String, dynamic>> _filterByDate(
    List<Map<String, dynamic>> docs,
    String dateField,
    DateTime start,
    DateTime end,
  ) {
    return docs.where((doc) {
      final raw = doc[dateField];
      DateTime? dt;
      if (raw is Timestamp) {
        dt = raw.toDate();
      } else if (raw is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(raw);
      }
      if (dt == null) return false;
      return !dt.isBefore(start) && dt.isBefore(end);
    }).toList();
  }

  /// Extracts a DateTime from a Firestore field that may be Timestamp or int.
  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  // ─── Header Style ───────────────────────────────────────────

  static CellStyle get _headerStyle => CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#FF4472C4'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFFFF'),
      );

  // ─── Sheet Builders ─────────────────────────────────────────

  static void _buildSalesSheet(
    Excel excel,
    List<Map<String, dynamic>> sales,
    Map<String, String> customerNames,
  ) {
    final sheet = excel['Sales'];
    final headers = ['Date', 'Customer Name', 'Items', 'Total Amount', 'Paid Amount', 'Balance Due', 'Created By'];

    // Header row
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }

    // Sort by date descending
    sales.sort((a, b) => _parseDate(b['saleDate']).compareTo(_parseDate(a['saleDate'])));

    for (var r = 0; r < sales.length; r++) {
      final s = sales[r];
      final row = r + 1;
      final date = _parseDate(s['saleDate']);
      final customerId = s['customerId'] as String? ?? '';
      final customerName = customerNames[customerId] ?? customerId;
      final items = _formatSaleItems(s['items']);
      final total = (s['totalAmount'] as num?)?.toDouble() ?? 0;
      final paid = (s['paidAmount'] as num?)?.toDouble() ?? 0;
      final balance = total - paid;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(_dateFmt.format(date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(customerName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(items);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = DoubleCellValue(total);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(paid);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = DoubleCellValue(balance);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = TextCellValue(s['createdBy'] as String? ?? '');
    }
  }

  static void _buildPaymentsSheet(
    Excel excel,
    List<Map<String, dynamic>> payments,
    Map<String, String> customerNames,
  ) {
    final sheet = excel['Payments Received'];
    final headers = ['Date', 'Customer Name', 'Amount', 'Method', 'Created By'];

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }

    payments.sort((a, b) => _parseDate(b['paymentDate']).compareTo(_parseDate(a['paymentDate'])));

    for (var r = 0; r < payments.length; r++) {
      final p = payments[r];
      final row = r + 1;
      final date = _parseDate(p['paymentDate']);
      final customerId = p['customerId'] as String? ?? '';
      final customerName = customerNames[customerId] ?? customerId;
      final amount = (p['amount'] as num?)?.toDouble() ?? 0;
      final method = (p['method'] as String? ?? 'cash').toUpperCase();

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(_dateFmt.format(date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(customerName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(amount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue(method);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue(p['createdBy'] as String? ?? '');
    }
  }

  static void _buildPurchasesSheet(
    Excel excel,
    List<Map<String, dynamic>> purchases,
    Map<String, String> supplierNames,
    Map<String, String> productNames,
  ) {
    final sheet = excel['Purchases'];
    final headers = ['Date', 'Supplier Name', 'Items', 'Total Cost', 'Paid Amount', 'Balance Due', 'Payment Method', 'Created By'];

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }

    purchases.sort((a, b) => _parseDate(b['purchaseDate']).compareTo(_parseDate(a['purchaseDate'])));

    for (var r = 0; r < purchases.length; r++) {
      final p = purchases[r];
      final row = r + 1;
      final date = _parseDate(p['purchaseDate']);
      final supplierId = p['supplierId'] as String? ?? '';
      final supplierName = supplierNames[supplierId] ?? supplierId;
      final items = _formatPurchaseItems(p['items'], productNames);
      final totalCost = (p['totalCost'] as num?)?.toDouble() ?? 0;
      final paidAmount = (p['paidAmount'] as num?)?.toDouble() ?? totalCost;
      final balance = (totalCost - paidAmount).clamp(0.0, double.infinity);
      final paymentMethod = (p['paymentMethod'] as String? ?? 'cash').toUpperCase();

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(_dateFmt.format(date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(supplierName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(items);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = DoubleCellValue(totalCost);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(paidAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = DoubleCellValue(balance);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = TextCellValue(paymentMethod);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = TextCellValue(p['createdBy'] as String? ?? '');
    }
  }

  static void _buildSupplierPaymentsSheet(
    Excel excel,
    List<Map<String, dynamic>> supplierPayments,
    Map<String, String> supplierNames,
  ) {
    final sheet = excel['Supplier Payments'];
    final headers = ['Date', 'Supplier Name', 'Amount', 'Method', 'Created By'];

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }

    supplierPayments.sort((a, b) => _parseDate(b['paymentDate']).compareTo(_parseDate(a['paymentDate'])));

    for (var r = 0; r < supplierPayments.length; r++) {
      final sp = supplierPayments[r];
      final row = r + 1;
      final date = _parseDate(sp['paymentDate']);
      final supplierId = sp['supplierId'] as String? ?? '';
      final supplierName = supplierNames[supplierId] ?? supplierId;
      final amount = (sp['amount'] as num?)?.toDouble() ?? 0;
      final method = (sp['method'] as String? ?? 'cash').toUpperCase();

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(_dateFmt.format(date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(supplierName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(amount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue(method);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue(sp['createdBy'] as String? ?? '');
    }
  }

  static void _buildCustomersSheet(Excel excel, List<Map<String, dynamic>> customers) {
    final sheet = excel['Customers'];
    final headers = ['Name', 'Phone', 'Address', 'Total Purchases', 'Pending Amount'];

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }

    // Sort alphabetically by name
    customers.sort((a, b) => ((a['name'] as String?) ?? '').compareTo((b['name'] as String?) ?? ''));

    for (var r = 0; r < customers.length; r++) {
      final c = customers[r];
      final row = r + 1;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(c['name'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(c['phone'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(c['address'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = DoubleCellValue((c['totalPurchases'] as num?)?.toDouble() ?? 0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue((c['pendingAmount'] as num?)?.toDouble() ?? 0);
    }
  }

  static void _buildProductsSheet(Excel excel, List<Map<String, dynamic>> products) {
    final sheet = excel['Products'];
    final headers = ['Name', 'Category', 'Purchase Price', 'Selling Price', 'Current Stock', 'Min Stock', 'Type'];

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }

    products.sort((a, b) => ((a['name'] as String?) ?? '').compareTo((b['name'] as String?) ?? ''));

    for (var r = 0; r < products.length; r++) {
      final p = products[r];
      final row = r + 1;
      final isOneOff = p['isOneOff'] as bool? ?? false;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(p['name'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(p['category'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue((p['purchasePrice'] as num?)?.toDouble() ?? 0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = DoubleCellValue((p['sellingPrice'] as num?)?.toDouble() ?? 0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = IntCellValue((p['currentStock'] as num?)?.toInt() ?? 0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = IntCellValue((p['minStock'] as num?)?.toInt() ?? 0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = TextCellValue(isOneOff ? 'One-Off' : 'Regular');
    }
  }

  static void _buildSuppliersSheet(Excel excel, List<Map<String, dynamic>> suppliers) {
    final sheet = excel['Suppliers'];
    final headers = ['Name', 'Phone', 'Pending Amount'];

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _headerStyle;
    }

    suppliers.sort((a, b) => ((a['name'] as String?) ?? '').compareTo((b['name'] as String?) ?? ''));

    for (var r = 0; r < suppliers.length; r++) {
      final s = suppliers[r];
      final row = r + 1;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(s['name'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(s['phone'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue((s['pendingAmount'] as num?)?.toDouble() ?? 0);
    }
  }

  // ─── Item Formatting ────────────────────────────────────────

  /// Formats sale items list like "Cover x2, Charger x1"
  static String _formatSaleItems(dynamic items) {
    if (items == null || items is! List || items.isEmpty) return '—';
    return items.map((item) {
      final map = item as Map<String, dynamic>;
      final name = map['productName'] as String? ?? 'Unknown';
      final qty = (map['quantity'] as num?)?.toInt() ?? 1;
      return '$name x$qty';
    }).join(', ');
  }

  /// Formats purchase items list like "Cover x10 @₹50, Charger x5 @₹120"
  static String _formatPurchaseItems(dynamic items, Map<String, String> productNames) {
    if (items == null || items is! List || items.isEmpty) return '—';
    return items.map((item) {
      final map = item as Map<String, dynamic>;
      final productId = map['productId'] as String? ?? '';
      final name = productNames[productId] ?? productId;
      final qty = (map['quantity'] as num?)?.toInt() ?? 1;
      final cost = (map['unitCost'] as num?)?.toDouble() ?? 0;
      return '$name x$qty @₹${_currencyFmt.format(cost)}';
    }).join(', ');
  }
}
