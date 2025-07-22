import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';

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
      final response = await client.from('sub_kategori').select('*, kategori(*)');
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
      final query = client
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
          ''');
         

      if (_dateRange != null) {
        query
          .gte('tanggal', _dateRange!.start.toIso8601String())
          .lte('tanggal', _dateRange!.end.toIso8601String());
      }
       query.order('tanggal', ascending: false);

      final response = await query;
      
      // Transform data for easier display
       final List<Map<String, dynamic>> transformedData = (response as List).map((item) {
      final details = (item['receipt_details'] as List?)?.firstOrNull;
      return {
        'id': item['id'],
        'tanggal': item['tanggal'],
        'no_faktur': item['no_faktur'],
        'total_harga': item['total_harga'],
        'product': details?['product_batches']?['products'],
        'distributor': details?['product_batches']?['distributors'],
        'batch_code': details?['product_batches']?['batch_code'],
        'exp': details?['product_batches']?['exp'],
        'qty_diterima': details?['qty_diterima'],
        'satuan': details?['product_batches']?['products']?['satuan'],
      };
    }).toList();

      setState(() {
        barangMasuk = List<Map<String, dynamic>>.from(transformedData);
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
      final query = client
          .from('outgoings')
          .select('''
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
       final List<Map<String, dynamic>> transformedData = (response as List).map((item) {
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
    }).toList();

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
     final query = client
      .from('product_batches')
      .select('''
        *,
        products!inner(
          nama_produk,
          kode_produk,
          satuan,
          sub_kategori_id,
          sub_kategori!inner(
            nama,
            kategori_id,
            kategori(nama)
          )
        )
      )''');

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
  
  

    final List<Map<String, dynamic>> transformedData = (response as List).map((item) {
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
    }).toList();

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
        headers = ['Tanggal', 'No Faktur', 'Produk', 'Batch', 'Qty', 'Satuan', 'Distributor', 'Expired', 'Total Harga'];
        fieldNames = ['tanggal', 'no_faktur', 'product.nama_produk', 'batch_code', 'qty_diterima', 'satuan', 'distributor.nama', 'exp', 'total_harga'];
        break;
      case 'Barang Keluar':
        headers = ['Tanggal', 'No Faktur', 'Produk', 'Batch', 'Qty', 'Satuan', 'Tujuan', 'Expired'];
        fieldNames = ['tanggal', 'no_faktur', 'product.nama_produk', 'batch_code', 'qty_keluar', 'satuan', 'tujuan', 'exp'];
        break;
      case 'Stok Produk':
        headers = ['Kode Produk', 'Nama Produk', 'Batch', 'Qty Sisa', 'Qty Keluar', 'Satuan', 'Sub Kategori', 'Expired'];
        fieldNames = ['kode_produk', 'nama_produk', 'batch_code', 'qty_sisa', 'qty_keluar', 'satuan', 'sub_kategori', 'exp'];
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
          sheet.getRangeByIndex(i + 2, j + 1).setText(DateFormat('dd/MM/yyyy').format(DateTime.parse(value.toString())));
        } 
        else if ((field.contains('harga') || field.contains('qty')) && value != null) {
          // Safe number conversion
          final numValue = value is num ? value 
                       : value is String ? num.tryParse(value) ?? 0 
                       : 0;
          sheet.getRangeByIndex(i + 2, j + 1).setNumber(numValue.toDouble());
          
          // Format as currency for harga fields
          if (field.contains('harga')) {
            sheet.getRangeByIndex(i + 2, j + 1).numberFormat = r'"Rp"#,##0.00';
          }
        } 
        else {
          sheet.getRangeByIndex(i + 2, j + 1).setText(value?.toString() ?? '');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tidak ada data untuk diekspor')),
    );
    return;
  }

  try {
    if (!await requestStoragePermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Izin penyimpanan ditolak')),
      );
      return;
    }

    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    List<String> headers;
    List<String> fieldNames;

    switch (title) {
      case 'Barang Masuk':
        headers = ['Tanggal', 'No Faktur', 'Produk', 'Batch', 'Qty', 'Satuan', 'Distributor', 'Expired', 'Total Harga'];
        fieldNames = ['tanggal', 'no_faktur', 'product.nama_produk', 'batch_code', 'qty_diterima', 'satuan', 'distributor.nama', 'exp', 'total_harga'];
        break;
      case 'Barang Keluar':
        headers = ['Tanggal', 'No Faktur', 'Produk', 'Batch', 'Qty', 'Satuan', 'Tujuan', 'Expired'];
        fieldNames = ['tanggal', 'no_faktur', 'product.nama_produk', 'batch_code', 'qty_keluar', 'satuan', 'tujuan', 'exp'];
        break;
      case 'Stok Produk':
        headers = ['Kode Produk', 'Nama Produk', 'Batch', 'Qty Sisa', 'Qty Keluar', 'Satuan', 'Sub Kategori', 'Expired'];
        fieldNames = ['products.kode_produk', 'products.nama_produk', 'batch_code', 'qty_sisa', 'qty_keluar', 'products.satuan', 'sub_kategori.nama', 'exp'];
        break;
      default:
        headers = data.first.keys.toList();
        fieldNames = headers;
    }

   final pdfData = data.map((row) {
  return fieldNames.map((field) {
    final value = _getNestedValue(row, field);
    if (field == 'tanggal' && value != null && value is String) {
      try {
        return DateFormat('dd/MM/yyyy').format(DateTime.parse(value));
      } catch (e) {
        return value; // fallback jika format tanggal tidak valid
      }
    } else if (field.contains('harga') && value != null) {
  final numValue = value is num
      ? value
      : value is String
          ? num.tryParse(value) ?? 0
          : 0;
  return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(numValue);
}
    return value?.toString() ?? '-';
  }).toList();
}).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Laporan $title',
                  style: pw.TextStyle(font: boldFont, fontSize: 18),
                ),
                pw.Text(
                  'Tanggal: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(font: font),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            if (dateRange != null)
              pw.Text(
                'Periode: ${DateFormat('dd/MM/yyyy').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange.end)}',
                style: pw.TextStyle(font: font),
              ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: headers,
              data: pdfData,
              headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.teal),
              cellStyle: pw.TextStyle(font: font),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              cellPadding: pw.EdgeInsets.all(5),
              columnWidths: {
                for (var i = 0; i < headers.length; i++) i: pw.FlexColumnWidth(1)
              },
            ),
            pw.SizedBox(height: 30),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Hormat kami,', style: pw.TextStyle(font: font)),
                  pw.SizedBox(height: 40),
                  pw.Text('(Admin)', style: pw.TextStyle(font: boldFont)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    await _saveFile(bytes, '$title.pdf');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF berhasil diekspor ke folder Download')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal ekspor PDF: $e')),
    );
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
      if (await Permission.storage.isPermanentlyDenied || await Permission.manageExternalStorage.isPermanentlyDenied) {
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
          onPressed: () => exportToPdf(context,data, title,null),
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
        child: Text(
          'Tidak ada data',
          style: TextStyle(color: Colors.grey),
        ),
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
              DataCell(Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(item['tanggal'])))),
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
              DataCell(Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(item['tanggal'])))),
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
              DataCell(Text('${item['qty_sisa']} ${item['products']?['satuan'] ?? ''}')),
              DataCell(Text('${item['qty_keluar']} ${item['products']?['satuan'] ?? ''}')),
              DataCell(Text(item['exp'] != null 
                ? DateFormat('dd/MM/yyyy').format(DateTime.parse(item['exp']))
                : '-')),
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
                Wrap(
                  spacing: 8,
                  children: [
                    _buildDateRangeChip(),
                  ],
                ),
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
                Wrap(
                  spacing: 8,
                  children: [
                    _buildDateRangeChip(),
                  ],
                ),
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
                // SizedBox(height: 10),
                // _buildSubKategoriDropdown(),
                // SizedBox(height: 10),
                // Wrap(
                //   spacing: 8,
                //   children: [
                //     _buildSubKategoriChip(),
                //   ],
                // ),
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