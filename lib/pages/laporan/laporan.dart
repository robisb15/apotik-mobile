import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:printing/printing.dart';


class InventoryTabsPage extends StatefulWidget {
  @override
  _InventoryTabsPageState createState() => _InventoryTabsPageState();
}

class _InventoryTabsPageState extends State<InventoryTabsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final client = Supabase.instance.client;
  final _scrollController = ScrollController();

  // Filter
  DateTimeRange? _dateRange;
  int? selectedSubKategoriId;
  String _searchQuery = '';

  // Data
  List<Map<String, dynamic>> barangMasuk = [];
  List<Map<String, dynamic>> barangKeluar = [];
  List<Map<String, dynamic>> stokProduk = [];
  List<Map<String, dynamic>> subKategoris = [];
  bool _isLoading = false;

  // Color scheme
  final Color primaryColor = Color(0xFF03A6A1);
  final Color accentColor = Color(0xFFFF7D33);
  final Color backgroundColor = Color(0xFFF5F5F5);
  final Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadSubKategoris();
    _tabController.addListener(_handleTabChange);
    _refreshData(); // Load initial data
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _searchQuery = '';
      });
      _refreshData();
    }
  }

  Future<void> loadSubKategoris() async {
    setState(() => _isLoading = true);
    try {
      final response = await client
          .from('sub_kategori')
          .select('*, kategori(*)');
      setState(() {
        subKategoris = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat sub kategori: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      _refreshData(); // Refresh data after date selection
    }
  }

  Future<void> fetchBarangMasuk() async {
    setState(() => _isLoading = true);
    try {
      final response = await client
          .from('receipts')
          .select('''
          id,
          tanggal,
          no_faktur,
          total_harga,
          receipt_details:receipt_details(
            qty_diterima,
            product_batches:product_batch_id(
              batch_code,
              exp,
              products:product_id(
                nama_produk,
                kode_produk,
                satuan
              ),
              distributors:distributor_id(
                nama
              )
            )
          )
        ''')
          .order('tanggal', ascending: false);

      // Transform data dengan benar
      final List<Map<String, dynamic>> transformedData = [];

      for (var item in response) {
        final detailsList = item['receipt_details'] as List?;
        if (detailsList != null && detailsList.isNotEmpty) {
          for (var detail in detailsList) {
            final batch = detail['product_batches'];
            transformedData.add({
              'id': item['id'],
              'tanggal': item['tanggal'],
              'no_faktur': item['no_faktur'],
              'total_harga': item['total_harga'],
              'product': batch?['products'],
              'distributor': batch?['distributors'],
              'batch_code': batch?['batch_code'],
              'exp': batch?['exp'],
              'qty_diterima': detail['qty_diterima'],
              'satuan': batch?['products']?['satuan'],
            });
          }
        }
      }

      setState(() {
        barangMasuk = transformedData;
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat barang masuk: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchBarangKeluar() async {
    setState(() => _isLoading = true);
    try {
      final query = client.from('outgoings').select('''
            id,
            tanggal,
            no_faktur,
            tujuan,
            outgoing_details:outgoing_details(
              qty_keluar,
              product_batches:product_batch_id(
                batch_code,
                exp,
                products:product_id(
                  nama_produk,
                  kode_produk,
                  satuan
                )
              )
            )
          ''');

      if (_dateRange != null) {
        query
            .gte('tanggal', _dateRange!.start.toIso8601String())
            .lte('tanggal', _dateRange!.end.toIso8601String());
      }
      query.order('tanggal', ascending: false);

      final response = await query;

      // Transform data
      final List<Map<String, dynamic>> transformedData = (response as List).map(
        (item) {
          final details = (item['outgoing_details'] as List?)?.firstOrNull;
          return {
            'id': item['id'],
            'tanggal': item['tanggal'],
            'no_faktur': item['no_faktur'],
            'tujuan': item['tujuan'],
            'product': details?['product_batches']?['products'],
            'batch_code': details?['product_batches']?['batch_code'],
            'exp': details?['product_batches']?['exp'],
            'qty_keluar': details?['qty_keluar'],
            'satuan': details?['product_batches']?['products']?['satuan'],
          };
        },
      ).toList();

      setState(() {
        barangKeluar = List<Map<String, dynamic>>.from(transformedData);
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat barang keluar: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchStokProduk() async {
    setState(() => _isLoading = true);
    try {
      final query = client.from('product_batches').select('''
  *,
  products(
    nama_produk,
    kode_produk,
    satuan,
    sub_kategori_id,
    sub_kategori(
      nama,
      kategori_id,
      kategori(nama)
    )
  )
''');

      // Filter berdasarkan sub_kategori_id
      if (selectedSubKategoriId != null) {
        query.eq('products.sub_kategori_id', selectedSubKategoriId!);
      }

      // Filter pencarian nama produk (case-insensitive)
      if (_searchQuery.isNotEmpty) {
        query.ilike('products.nama_produk', '%$_searchQuery%');
      }

      // Urutkan berdasarkan tanggal exp
      query.order('exp', ascending: true);

      final response = await query;
      print(response);

      final List<Map<String, dynamic>> transformedData = (response as List).map(
        (item) {
          return {
            'id': item['id'],
            'product_id': item['product_id'],
            'distributor_id': item['distributor_id'],
            'batch_code': item['batch_code'],
            'exp': item['exp'],
            'qty_masuk': item['qty_masuk'],
            'qty_keluar': item['qty_keluar'],
            'qty_sisa': item['qty_sisa'],
            'products': item['products'],
            'sub_kategori': item['sub_kategori'],
          };
        },
      ).toList();

      setState(() => stokProduk = transformedData);
    } catch (e) {
      _showErrorSnackbar('Gagal memuat stok produk: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> exportToExcel(
    List<Map<String, dynamic>> data,
    String title,
  ) async {
    if (data.isEmpty) {
      _showErrorSnackbar('Tidak ada data untuk diekspor');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final xlsio.Workbook workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = title;

      // Custom headers based on report type
      List<String> headers;
      List<String> fieldNames;

      switch (title) {
        case 'Barang Masuk':
          headers = [
            'Tanggal',
            'No Faktur',
            'Produk',
            'Batch',
            'Qty',
            'Satuan',
            'Distributor',
            'Expired',
            'Total Harga',
          ];
          fieldNames = [
            'tanggal',
            'no_faktur',
            'product.nama_produk',
            'batch_code',
            'qty_diterima',
            'satuan',
            'distributor.nama',
            'exp',
            'total_harga',
          ];
          break;
        case 'Barang Keluar':
          headers = [
            'Tanggal',
            'No Faktur',
            'Produk',
            'Batch',
            'Qty',
            'Satuan',
            'Tujuan',
            'Expired',
          ];
          fieldNames = [
            'tanggal',
            'no_faktur',
            'product.nama_produk',
            'batch_code',
            'qty_keluar',
            'satuan',
            'tujuan',
            'exp',
          ];
          break;
        case 'Stok Produk':
          headers = [
            'Kode Produk',
            'Nama Produk',
            'Batch',
            'Qty Sisa',
            'Qty Keluar',
            'Satuan',
            'Sub Kategori',
            'Expired',
          ];
          fieldNames = [
            'kode_produk',
            'nama_produk',
            'batch_code',
            'qty_sisa',
            'qty_keluar',
            'satuan',
            'sub_kategori',
            'exp',
          ];
          break;
        default:
          headers = data.first.keys.toList();
          fieldNames = headers;
      }

      // Add headers
      for (var i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
        sheet.getRangeByIndex(1, i + 1).cellStyle.bold = true;
        sheet.getRangeByIndex(1, i + 1).cellStyle.backColor = '#03A6A1';
        sheet.getRangeByIndex(1, i + 1).cellStyle.fontColor = '#FFFFFF';
      }

      // Add data with proper type handling
      for (var i = 0; i < data.length; i++) {
        final row = data[i];
        for (var j = 0; j < fieldNames.length; j++) {
          final field = fieldNames[j];
          final value = _getNestedValue(row, field);

          // Handle different field types
          if (field == 'tanggal' && value != null) {
            sheet
                .getRangeByIndex(i + 2, j + 1)
                .setText(
                  DateFormat(
                    'dd/MM/yyyy',
                  ).format(DateTime.parse(value.toString())),
                );
          } else if ((field.contains('harga') || field.contains('qty')) &&
              value != null) {
            // Safe number conversion
            final numValue = value is num
                ? value
                : value is String
                ? num.tryParse(value) ?? 0
                : 0;
            sheet.getRangeByIndex(i + 2, j + 1).setNumber(numValue.toDouble());

            // Format as currency for harga fields
            if (field.contains('harga')) {
              sheet.getRangeByIndex(i + 2, j + 1).numberFormat =
                  r'"Rp"#,##0.00';
            }
          } else {
            sheet
                .getRangeByIndex(i + 2, j + 1)
                .setText(value?.toString() ?? '');
          }
        }
      }

      // Auto fit columns
      for (var i = 1; i <= headers.length; i++) {
        sheet.autoFitColumn(i);
      }

      final bytes = workbook.saveAsStream();
      workbook.dispose();
      await _saveFile(bytes, '$title.xlsx');
      _showSuccessSnackbar('Excel berhasil diekspor');
    } catch (e) {
      _showErrorSnackbar('Gagal mengekspor ke Excel: $e');
      debugPrint('Error details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  dynamic _getNestedValue(Map<String, dynamic> map, String key) {
    final keys = key.split('.');
    dynamic value = map;
    for (var k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else {
        return null;
      }
    }
    return value;
  }

  Future<void> exportToPdf(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String title,
    DateTimeRange? dateRange,
  ) async {
    if (data.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tidak ada data untuk diekspor')));
      return;
    }

    try {
      // Create a PDF document
      final pdf = pw.Document();

      // Format values for display
      String formatValue(dynamic value, String field) {
        if (value == null) return '-';
        if (field == 'tanggal' && value is String) {
          try {
            return DateFormat('dd/MM/yyyy').format(DateTime.parse(value));
          } catch (_) {
            return value.toString();
          }
        } else if (field.contains('harga')) {
          final numValue = value is num
              ? value
              : num.tryParse(value.toString()) ?? 0;
          return NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(numValue);
        } else if (field == 'exp' && value is String) {
          try {
            return DateFormat('dd/MM/yyyy').format(DateTime.parse(value));
          } catch (_) {
            return value.toString();
          }
        }
        return value.toString();
      }

      // Prepare headers and data
      List<pw.Widget> tableRows = [];
      num totalHarga = 0;
      num totalQtyKeluar = 0;

      // Add title and date
      tableRows.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Laporan $title',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Tanggal: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      );

      // Add date range if available
      if (dateRange != null) {
        tableRows.add(
          pw.Text(
            'Periode: ${DateFormat('dd/MM/yyyy').format(dateRange.start)} - '
            '${DateFormat('dd/MM/yyyy').format(dateRange.end)}',
            style: pw.TextStyle(fontSize: 10),
          ),
        );
      }

      tableRows.add(pw.SizedBox(height: 20));

      // Create table header
      List<pw.Widget> headerCells = [];
      List<pw.Widget> dataCells = [];

      // Determine columns based on report type
      if (title == 'Barang Masuk') {
        headerCells.addAll([
          pw.Text(
            'Tanggal',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'No Faktur',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Produk',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(
            'Satuan',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Distributor',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Expired',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Total Harga',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ]);

        for (var item in data) {
          // Format date
          String formattedDate = '-';
          try {
            if (item['tanggal'] != null) {
              formattedDate = DateFormat(
                'dd/MM/yyyy',
              ).format(DateTime.parse(item['tanggal'].toString()).toLocal());
            }
          } catch (e) {
            debugPrint('Error formatting date: ${item['tanggal']}');
          }

          // Calculate total price
          String totalHargaStr = 'Rp 0';
          try {
            if (item['total_harga'] != null) {
              totalHargaStr = formatValue(item['total_harga'], 'harga');
              totalHarga += num.tryParse(item['total_harga'].toString()) ?? 0;
            }
          } catch (e) {
            debugPrint('Error formatting harga: ${item['total_harga']}');
          }

          dataCells.addAll([
            pw.Text(formattedDate),
            pw.Text(item['no_faktur']?.toString() ?? '-'),
            pw.Text(item['product']?['nama_produk']?.toString() ?? '-'),
            pw.Text(item['qty_diterima']?.toString() ?? '0'),
            pw.Text(item['satuan']?.toString() ?? '-'),
            pw.Text(item['distributor']?['nama']?.toString() ?? '-'),
            pw.Text(formatValue(item['exp'], 'exp')),
            pw.Text(totalHargaStr),
          ]);
        }
      } else if (title == 'Barang Keluar') {
        headerCells.addAll([
          pw.Text(
            'Tanggal',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'No Faktur',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Produk',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(
            'Satuan',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Tujuan',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Expired',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ]);

        for (var item in data) {
          final qty = item['qty_keluar'] ?? 0;
          totalQtyKeluar += (qty is num)
              ? qty
              : num.tryParse(qty.toString()) ?? 0;

          dataCells.addAll([
            pw.Text(formatValue(item['tanggal'], 'tanggal')),
            pw.Text(item['no_faktur']?.toString() ?? '-'),
            pw.Text(item['product']?['nama_produk']?.toString() ?? '-'),
            pw.Text(qty.toString()),
            pw.Text(item['satuan']?.toString() ?? '-'),
            pw.Text(item['tujuan']?.toString() ?? '-'),
            pw.Text(formatValue(item['exp'], 'exp')),
          ]);
        }
      } else if (title == 'Stok Produk') {
        headerCells.addAll([
          pw.Text(
            'Kode Produk',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Nama Produk',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Batch', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(
            'Qty Sisa',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Qty Keluar',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Satuan',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Sub Kategori',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Expired',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ]);

        for (var item in data) {
          dataCells.addAll([
            pw.Text(item['products']?['kode_produk']?.toString() ?? '-'),
            pw.Text(item['products']?['nama_produk']?.toString() ?? '-'),
            pw.Text(item['batch_code']?.toString() ?? '-'),
            pw.Text(item['qty_sisa']?.toString() ?? '0'),
            pw.Text(item['qty_keluar']?.toString() ?? '0'),
            pw.Text(item['products']?['satuan']?.toString() ?? '-'),
            pw.Text(item['sub_kategori']?['nama']?.toString() ?? '-'),
            pw.Text(formatValue(item['exp'], 'exp')),
          ]);
        }
      }

      // Create table
      tableRows.add(
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#03A6A1')),
              children: headerCells,
            ),
            // Data rows
            for (int i = 0; i < data.length; i++)
              pw.TableRow(
                decoration: i % 2 == 0
                    ? pw.BoxDecoration(color: PdfColor.fromHex('#F5F5F5'))
                    : null,
                children: [
                  for (int j = 0; j < headerCells.length; j++)
                    dataCells[i * headerCells.length + j],
                ],
              ),
          ],
        ),
      );

      // Add totals if applicable
      if (title == 'Barang Masuk') {
        tableRows.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(top: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Harga Keseluruhan: ${formatValue(totalHarga, 'harga')}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (title == 'Barang Keluar') {
        tableRows.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(top: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Barang Keluar: $totalQtyKeluar',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Add signature
      tableRows.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(top: 30),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Hormat kami,'),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '(Staff)',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      // Add the page to the document
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: tableRows,
            );
          },
        ),
      );

      // Save and share the PDF
      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: '$title.pdf');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF $title berhasil diekspor')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ekspor PDF: ${e.toString()}')),
      );
      debugPrint('Error exporting PDF: $e');
    }
  }

  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      // Android 13+
      final permissionStatus = await Permission.manageExternalStorage.request();
      return permissionStatus.isGranted;
    } else {
      // Android < 13
      final permissionStatus = await Permission.storage.request();
      return permissionStatus.isGranted;
    }
  }

  Future<void> _saveFile(List<int> bytes, String fileName) async {
    try {
      if (!await requestStoragePermission()) {
        _showErrorSnackbar('Izin penyimpanan diperlukan untuk menyimpan file.');
        if (await Permission.storage.isPermanentlyDenied ||
            await Permission.manageExternalStorage.isPermanentlyDenied) {
          await openAppSettings();
        }
        return;
      }

      // Simpan ke folder /storage/emulated/0/Download (folder root)
      final downloadDir = Directory('/storage/emulated/0/Download');

      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final filePath = '${downloadDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      if (await file.exists()) {
        _showSuccessSnackbar('File berhasil disimpan: $filePath');
        // Uncomment jika ingin membuka file langsung
        // await OpenFile.open(filePath);
      } else {
        _showErrorSnackbar('Gagal menyimpan file.');
      }
    } catch (e) {
      _showErrorSnackbar('Terjadi kesalahan saat menyimpan file: $e');
      debugPrint('Error saving file: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Widget _buildDateRangeChip() {
    if (_dateRange == null) return SizedBox.shrink();

    return Chip(
      backgroundColor: primaryColor.withOpacity(0.1),
      label: Text(
        '${DateFormat('dd MMM yyyy').format(_dateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}',
        style: TextStyle(color: primaryColor),
      ),
      deleteIcon: Icon(Icons.close, size: 16),
      onDeleted: () {
        setState(() => _dateRange = null);
        _refreshData();
      },
    );
  }

  Widget _buildSubKategoriChip() {
    if (selectedSubKategoriId == null) return SizedBox.shrink();

    final subKategori = subKategoris.firstWhere(
      (e) => e['id'] == selectedSubKategoriId,
      orElse: () => {'nama': 'Unknown'},
    );

    return Chip(
      backgroundColor: primaryColor.withOpacity(0.1),
      label: Text(
        '${subKategori['kategori']?['nama'] ?? 'Tanpa Kategori'} - ${subKategori['nama']}',
        style: TextStyle(color: primaryColor),
      ),
      deleteIcon: Icon(Icons.close, size: 16),
      onDeleted: () {
        setState(() => selectedSubKategoriId = null);
        fetchStokProduk();
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Cari...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        filled: true,
        contentPadding: EdgeInsets.symmetric(vertical: 12),
      ),
      onChanged: (value) {
        setState(() => _searchQuery = value);
        if (_tabController.index == 2) {
          fetchStokProduk();
        }
      },
    );
  }

  Widget _buildFilterButton(VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list, size: 20),
          SizedBox(width: 8),
          Text('Filter'),
        ],
      ),
    );
  }

  Widget _buildExportButtons(List<Map<String, dynamic>> data, String title) {
    if (data.isEmpty) return SizedBox.shrink();

    return Row(
      children: [
        ElevatedButton(
          onPressed: () => exportToExcel(data, title),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file, size: 20),
              SizedBox(width: 8),
              Text('Excel'),
            ],
          ),
        ),
        SizedBox(width: 10),
        ElevatedButton(
          onPressed: () {
            // Panggil exportToPdf dengan parameter yang sesuai
            if (title == "Barang Masuk") {
              exportToPdf(context, barangMasuk, "Barang Masuk", _dateRange);
            } else if (title == "Barang Keluar") {
              exportToPdf(context, barangKeluar, "Barang Keluar", _dateRange);
            } else if (title == "Stok Produk") {
              exportToPdf(context, stokProduk, "Stok Produk", null);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, size: 20),
              SizedBox(width: 8),
              Text('PDF'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> data, String type) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (data.isEmpty) {
      return Center(
        child: Text('Tidak ada data', style: TextStyle(color: Colors.grey)),
      );
    }

    List<DataColumn> columns;
    List<DataRow> rows;

    switch (type) {
      case 'masuk':
        columns = [
          DataColumn(label: Text('Tanggal')),
          DataColumn(label: Text('No Faktur')),
          DataColumn(label: Text('Produk')),
          DataColumn(label: Text('Qty', textAlign: TextAlign.center)),
          DataColumn(label: Text('Distributor')),
        ];

        rows = data.map((item) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  DateFormat(
                    'dd/MM/yyyy',
                  ).format(DateTime.parse(item['tanggal'])),
                ),
              ),
              DataCell(Text(item['no_faktur'] ?? '-')),
              DataCell(Text(item['product']?['nama_produk'] ?? '-')),
              DataCell(Text('${item['qty_diterima']} ${item['satuan'] ?? ''}')),
              DataCell(Text(item['distributor']?['nama'] ?? '-')),
            ],
          );
        }).toList();
        break;

      case 'keluar':
        columns = [
          DataColumn(label: Text('Tanggal')),
          DataColumn(label: Text('No Faktur')),
          DataColumn(label: Text('Produk')),
          DataColumn(label: Text('Qty', textAlign: TextAlign.center)),
          DataColumn(label: Text('Tujuan')),
        ];

        rows = data.map((item) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  DateFormat(
                    'dd/MM/yyyy',
                  ).format(DateTime.parse(item['tanggal'])),
                ),
              ),
              DataCell(Text(item['no_faktur'] ?? '-')),
              DataCell(Text(item['product']?['nama_produk'] ?? '-')),
              DataCell(Text('${item['qty_keluar']} ${item['satuan'] ?? ''}')),
              DataCell(Text(item['tujuan'] ?? '-')),
            ],
          );
        }).toList();
        break;

      case 'stok':
        columns = [
          DataColumn(label: Text('Produk')),
          DataColumn(label: Text('Batch')),
          DataColumn(label: Text('Sisa', textAlign: TextAlign.center)),
          DataColumn(label: Text('Keluar', textAlign: TextAlign.center)),
          DataColumn(label: Text('Expired')),
        ];

        rows = stokProduk.map((item) {
          return DataRow(
            cells: [
              DataCell(Text(item['products']?['nama_produk'] ?? '-')),
              DataCell(Text(item['batch_code'] ?? '-')),
              DataCell(
                Text(
                  '${item['qty_sisa']} ${item['products']?['satuan'] ?? ''}',
                ),
              ),
              DataCell(
                Text(
                  '${item['qty_keluar']} ${item['products']?['satuan'] ?? ''}',
                ),
              ),
              DataCell(
                Text(
                  item['exp'] != null
                      ? DateFormat(
                          'dd/MM/yyyy',
                        ).format(DateTime.parse(item['exp']))
                      : '-',
                ),
              ),
            ],
          );
        }).toList();
        break;

      default:
        columns = [];
        rows = [];
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns,
        rows: rows,
        headingRowColor: MaterialStateProperty.resolveWith<Color>(
          (states) => primaryColor.withOpacity(0.1),
        ),
        dataRowHeight: 48,
        headingRowHeight: 56,
        showBottomBorder: true,
        columnSpacing: 20,
      ),
    );
  }

  Widget _buildSubKategoriDropdown() {
    return DropdownButtonFormField<int>(
      value: selectedSubKategoriId,
      decoration: InputDecoration(
        labelText: 'Kategori',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('Semua Kategori')),
        ...subKategoris.map((e) {
          final kategoriNama = e['kategori']?['nama'] ?? 'Tanpa Kategori';
          final subKategoriNama = e['nama'] ?? '';
          return DropdownMenuItem(
            value: e['id'],
            child: Text('$kategoriNama - $subKategoriNama'),
          );
        }),
      ],
      onChanged: (value) {
        setState(() => selectedSubKategoriId = value);
        fetchStokProduk();
      },
    );
  }

  void _refreshData() {
    switch (_tabController.index) {
      case 0:
        fetchBarangMasuk();
        break;
      case 1:
        fetchBarangKeluar();
        break;
      case 2:
        fetchStokProduk();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Laporan Inventori"),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'Barang Masuk'),
            Tab(text: 'Barang Keluar'),
            Tab(text: 'Stok Produk'),
          ],
          onTap: (index) => _refreshData(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Barang Masuk
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSearchField()),
                    SizedBox(width: 10),
                    _buildFilterButton(pickDateRange),
                  ],
                ),
                SizedBox(height: 10),
                Wrap(spacing: 8, children: [_buildDateRangeChip()]),
                SizedBox(height: 16),
                _buildExportButtons(barangMasuk, "Barang Masuk"),
                SizedBox(height: 16),
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: _buildDataTable(barangMasuk, 'masuk'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Barang Keluar
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSearchField()),
                    SizedBox(width: 10),
                    _buildFilterButton(pickDateRange),
                  ],
                ),
                SizedBox(height: 10),
                Wrap(spacing: 8, children: [_buildDateRangeChip()]),
                SizedBox(height: 16),
                _buildExportButtons(barangKeluar, "Barang Keluar"),
                SizedBox(height: 16),
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: _buildDataTable(barangKeluar, 'keluar'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stok Produk
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSearchField()),
                    SizedBox(width: 10),
                    _buildFilterButton(fetchStokProduk),
                  ],
                ),
                SizedBox(height: 10),
                _buildSubKategoriDropdown(),
                SizedBox(height: 10),
                Wrap(spacing: 8, children: [_buildSubKategoriChip()]),
                SizedBox(height: 16),
                _buildExportButtons(stokProduk, "Stok Produk"),
                SizedBox(height: 16),
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: _buildDataTable(stokProduk, 'stok'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
