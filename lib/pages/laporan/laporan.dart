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

class InventoryTabsPage extends StatefulWidget {
  @override
  _InventoryTabsPageState createState() => _InventoryTabsPageState();
}

class _InventoryTabsPageState extends State<InventoryTabsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final client = Supabase.instance.client;

  // Filter
  DateTime? startDate;
  DateTime? endDate;
  int? selectedSubKategoriId;

  // Data
  List<Map<String, dynamic>> barangMasuk = [];
  List<Map<String, dynamic>> barangKeluar = [];
  List<Map<String, dynamic>> stokProduk = [];
  List<Map<String, dynamic>> subKategoris = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadSubKategoris();
  }

  Future<void> loadSubKategoris() async {
    final response = await client.from('sub_kategori').select('id, nama');
    setState(() {
      subKategoris = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
    }
  }

  Future<void> fetchBarangMasuk() async {
    final query = client
        .from('receipts')
        .select('''
      id,
      tanggal,
      no_faktur,
      total_harga,
      receipt_details (
        qty_diterima,
        batch_code,
        exp,
        distributor_id,
        product_id,
        products (
          nama_produk,
          kode_produk,
          satuan
        ),
        distributors (
          nama
        )
      )
    ''')
        .filter('deleted_at', 'is', null);

    if (startDate != null) {
      query.gte('tanggal', startDate!.toIso8601String());
    }
    if (endDate != null) {
      query.lte('tanggal', endDate!.toIso8601String());
    }

    final response = await query;

    setState(() {
      barangMasuk = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> fetchBarangKeluar() async {
    final response = await client.rpc(
      'get_barang_keluar',
      params: {
        'start': startDate?.toIso8601String(),
        'end': endDate?.toIso8601String(),
      },
    );
    setState(() {
      barangKeluar = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> fetchStokProduk() async {
    final response = await client
        .from('product_batches')
        .select('*, products(nama_produk), sub_kategori_id')
        .filter('deleted_at', 'is', null)
        .filter('products.sub_kategori_id', 'is', selectedSubKategoriId);
    setState(() {
      stokProduk = List<Map<String, dynamic>>.from(response);
    });
    if (response != null) {
      setState(() {
        stokProduk = List<Map<String, dynamic>>.from(response);
      });
    } else {
      setState(() {
        stokProduk = [];
      });
    }
  }

  Future<void> exportToExcel(
    List<Map<String, dynamic>> data,
    String title,
  ) async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = title;
    final headers = data.first.keys.toList();
    for (var i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }
    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      for (var j = 0; j < headers.length; j++) {
        sheet.getRangeByIndex(i + 2, j + 1).setText('${row[headers[j]]}');
      }
    }
    final bytes = workbook.saveAsStream();
    workbook.dispose();
    await _saveFile(bytes, '$title.xlsx', context);
  }

  Future<void> exportToPdf(
    List<Map<String, dynamic>> data,
    String title,
    BuildContext context, // pastikan context dikirim
    String userName, // nama user untuk ditandatangani
  ) async {
    final pdf = pw.Document();

    final headers = data.first.keys.toList();
    final table = pw.Table.fromTextArray(
      headers: headers,
      data: data
          .map((row) => headers.map((h) => '${row[h]}').toList())
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
      border: pw.TableBorder.all(color: PdfColors.grey700),
      headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
      cellHeight: 25,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ✅ Judul
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.left,
            ),
            pw.SizedBox(height: 20),

            // ✅ Tabel
            table,
            pw.Spacer(),

            // ✅ Tanda tangan di kanan bawah
            pw.Align(
              alignment: pw.Alignment.bottomRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Hormat Kami,'),
                  pw.SizedBox(height: 50), // ruang untuk ttd
                  pw.Text(
                    userName,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    await _saveFile(bytes, '$title.pdf', context);
  }

  Future<void> _saveFile(
    List<int> bytes,
    String fileName,
    BuildContext context,
  ) async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    bool granted = false;

    if (Platform.isAndroid) {
      if (sdkInt >= 33) {
        final status = await Permission.videos
            .request(); // atau Permission.mediaLibrary jika butuh umum
        granted = status.isGranted;
      } else {
        final status = await Permission.storage.request();
        granted = status.isGranted;
      }
    }

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin penyimpanan ditolak'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      /// ✅ Gunakan direktori Download publik
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final file = File(p.join(downloadDir.path, fileName));
      await file.writeAsBytes(bytes);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Disimpan di ${file.path}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan file: $e')));
    }
  }

  Widget _buildFilterButton({required VoidCallback onFilter}) {
    return ElevatedButton.icon(
      onPressed: onFilter,
      icon: Icon(Icons.filter_alt),
      label: Text("Filter"),
    );
  }

  Widget _buildExportButtons(List<Map<String, dynamic>> data, String label) {
    if (data.isEmpty) return SizedBox.shrink();
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () => exportToExcel(data, label),
          icon: Icon(Icons.file_copy),
          label: Text("Excel"),
        ),
        SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () => exportToPdf(data, label, context, 'admin'),
          icon: Icon(Icons.picture_as_pdf),
          label: Text("PDF"),
        ),
      ],
    );
  }

  Widget _buildList(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return Center(child: Text("Belum ada data"));
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        return ListTile(
          title: Text(item.values.first.toString()),
          subtitle: Text(item.toString()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manajemen Barang"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Barang Masuk'),
            Tab(text: 'Barang Keluar'),
            Tab(text: 'Stok Produk'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Barang Masuk
          Column(
            children: [
              ElevatedButton(
                onPressed: pickDateRange,
                child: Text("Pilih Tanggal"),
              ),
              _buildFilterButton(onFilter: fetchBarangMasuk),
              _buildExportButtons(barangMasuk, "BarangMasuk"),
              Expanded(child: _buildList(barangMasuk)),
            ],
          ),
          // Barang Keluar
          Column(
            children: [
              ElevatedButton(
                onPressed: pickDateRange,
                child: Text("Pilih Tanggal"),
              ),
              _buildFilterButton(onFilter: fetchBarangKeluar),
              _buildExportButtons(barangKeluar, "BarangKeluar"),
              Expanded(child: _buildList(barangKeluar)),
            ],
          ),
          // Stok Produk
          Column(
            children: [
              DropdownButton<int>(
                hint: Text("Pilih Sub Kategori"),
                value: selectedSubKategoriId,
                onChanged: (val) => setState(() => selectedSubKategoriId = val),
                items: subKategoris
                    .map(
                      (e) => DropdownMenuItem<int>(
                        value: e['id'],
                        child: Text(e['nama']),
                      ),
                    )
                    .toList(),
              ),
              _buildFilterButton(onFilter: fetchStokProduk),
              _buildExportButtons(stokProduk, "StokProduk"),
              Expanded(child: _buildList(stokProduk)),
            ],
          ),
        ],
      ),
    );
  }
}
