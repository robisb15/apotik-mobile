// ignore_for_file: unused_local_variable, use_key_in_widget_constructors, use_build_context_synchronously, deprecated_member_use, unnecessary_brace_in_string_interps

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:excel/excel.dart' as exceldata;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'form/barcode_keluar.dart';
import 'form/entry_manual_keluar.dart';

class BarangKeluarPage extends StatefulWidget {
  @override
  State<BarangKeluarPage> createState() => _BarangKeluarPageState();
}

class _BarangKeluarPageState extends State<BarangKeluarPage> {
  final supabase = Supabase.instance.client;
  final Color primaryColor = Color(0xFF03A6A1);
  final Color accentColor = Color(0xFF4DB6AC);
  final Map<String, bool> _expandedDates = {};
  bool _isLoading = true;
  List<Map<String, dynamic>> _outgoings = [];
  List<Map<String, dynamic>> _filtered = [];
  String _searchQuery = '';
  int _totalAllFaktur = 0;
  int _totalFaktur = 0;
  DateTimeRange? _selectedDateRange;

  // Medicine type icons mapping
  final Map<String, IconData> _medicineIcons = {
    'tablet': Icons.medication,
    'capsule': Icons.medication_outlined,
    'syrup': Icons.liquor,
    'injection': Icons.medical_services,
    'drops': Icons.water_drop,
    'default': Icons.medical_services,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _confirmDeleteOutgoing(
    String outgoingId,
    String noFaktur,
    List<Map<String, dynamic>> items,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Faktur?'),
        content: Text('Apakah Anda yakin ingin menghapus faktur $noFaktur?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteOutgoing(outgoingId, items);
    }
  }

  Future<void> _deleteOutgoing(
    String outgoingId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      setState(() => _isLoading = true);

      // 1. Get all outgoing_details for this outgoing
      final outgoingDetails = await supabase
          .from('outgoing_details')
          .select()
          .eq('outgoing_id', outgoingId);

      // 2. Update product batches (return stock)
      for (final detail in outgoingDetails) {
        final batchId = detail['product_batch_id'];
        final qtyKeluar = detail['qty_keluar'] ?? 0;

        // Get current batch data
        final batch = await supabase
            .from('product_batches')
            .select('qty_keluar, qty_sisa')
            .eq('id', batchId)
            .single();

        final currentQtyKeluar = batch['qty_keluar'] ?? 0;
        final currentQtySisa = batch['qty_sisa'] ?? 0;

        // Calculate new quantities
        final newQtyKeluar = currentQtyKeluar - qtyKeluar;
        final newQtySisa = currentQtySisa + qtyKeluar;

        // Update the product batch
        await supabase
            .from('product_batches')
            .update({'qty_keluar': newQtyKeluar, 'qty_sisa': newQtySisa})
            .eq('id', batchId);
            }

      // 3. Delete outgoing details
      await supabase
          .from('outgoing_details')
          .delete()
          .eq('outgoing_id', outgoingId);

      // 4. Delete the outgoing record
      await supabase.from('outgoings').delete().eq('id', outgoingId);

      // 5. Reload data
      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Faktur berhasil dihapus dan stok diperbarui')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus faktur: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showImportDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Import Excel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Upload file Excel dengan format sesuai template'),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _downloadTemplateExcel,
              icon: Icon(Icons.download),
              label: Text('Download Template Excel'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _importExcel,
              child: Text('Pilih File Excel'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
        ],
      ),
    );
  }

  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      final permissionStatus = await Permission.manageExternalStorage.request();
      return permissionStatus.isGranted;
    } else {
      final permissionStatus = await Permission.storage.request();
      return permissionStatus.isGranted;
    }
  }

  Future<void> _downloadTemplateExcel() async {
    try {
      if (!await requestStoragePermission()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Izin penyimpanan ditolak')));
        return;
      }

      final byteData = await rootBundle.load('assets/datakeluar.xlsx');
      final downloadDir = Directory('/storage/emulated/0/Download');

      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final filePath = '${downloadDir.path}/datakeluar.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(byteData.buffer.asUint8List());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template berhasil disimpan di:\n$filePath')),
      );
    } catch (e) {
      debugPrint('Gagal download template: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan template'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String parseTanggalDinamis(dynamic value) {
    if (value == null) return '';

    if (value is num) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        ((value - 25569) * 86400000).toInt(),
        isUtc: true,
      );
      return DateFormat('dd MMM yyyy').format(date);
    }

    final raw = value.toString().trim();
    final possibleFormats = [
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'yyyy/MM/dd',
      'dd-MM-yyyy',
      'dd MMM yyyy',
      'd-MMM-yy',
    ];

    for (var format in possibleFormats) {
      try {
        final date = DateFormat(format).parseStrict(raw);
        return DateFormat('yyyy-MM-dd').format(date);
      } catch (_) {
        continue;
      }
    }

    return raw;
  }

  Future<void> _importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tidak ada file yang dipilih')));
        return;
      }

      setState(() => _isLoading = true);
      Navigator.pop(context);

      final file = result.files.single;
      if (file.bytes == null || file.bytes!.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('File kosong atau tidak valid')));
        return;
      }

      final excel = exceldata.Excel.decodeBytes(file.bytes!);
      int successCount = 0;
      int errorCount = 0;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        if (sheet.rows.length <= 1) continue;

        for (int i = 1; i < sheet.rows.length; i++) {
          try {
            final row = sheet.rows[i];
            if (row.length < 9) {
              errorCount++;
              continue;
            }

            final noFaktur = row[0]?.value?.toString().trim() ?? '';
            final tanggal = row[1]?.value?.toString().trim() ?? '';
            final namaProduk = row[2]?.value?.toString().trim() ?? '';
            final tujuan = row[3]?.value?.toString().trim() ?? '';
            final batchNumber = row[4]?.value?.toString().trim() ?? '';
            final expDate = row[5]?.value?.toString().trim() ?? '';
            final jumlah = int.tryParse(row[7]?.value?.toString() ?? '') ?? 0;
            final subtotal = int.tryParse(row[8]?.value?.toString() ?? '') ?? 0;

            if (noFaktur.isEmpty ||
                tanggal.isEmpty ||
                namaProduk.isEmpty ||
                tujuan.isEmpty ||
                batchNumber.isEmpty ||
                jumlah <= 0 ||
                subtotal < 0) {
              errorCount++;
              continue;
            }

            final tanggalFormat = parseTanggalDinamis(tanggal);
            final formattedExp = parseTanggalDinamis(expDate);

            // Cari batch produk
            final batchResponse = await supabase
                .from('product_batches')
                .select('id, qty_sisa, qty_keluar')
                .eq('batch_code', batchNumber)
                .limit(1);

            if (batchResponse.isEmpty || batchResponse.first['id'] == null) {
              errorCount++;
              continue;
            }

            final batch = batchResponse.first;
            final batchId = batch['id'];
            final qtySisa = batch['qty_sisa'] ?? 0;
            final qtyKeluar = batch['qty_keluar'] ?? 0;

            if (qtySisa < jumlah) {
              errorCount++;
              continue;
            }

            // Cek apakah faktur sudah ada
            final existingList = await supabase
                .from('outgoings')
                .select()
                .eq('no_faktur', noFaktur)
                .limit(1);

            Map<String, dynamic> outgoing;

            if (existingList.isNotEmpty) {
              final existing = existingList.first;

              final existingTotalRaw = existing['total_harga'];
              final existingTotal = existingTotalRaw is int
                  ? existingTotalRaw
                  : int.tryParse(existingTotalRaw.toString()) ?? 0;

              final updatedTotal = existingTotal + subtotal;

              final updateResponse = await supabase
                  .from('outgoings')
                  .update({
                    'total_harga': updatedTotal,
                    'tanggal': tanggalFormat,
                  })
                  .eq('no_faktur', noFaktur)
                  .select()
                  .single();

              outgoing = updateResponse;
            } else {
              final insertResponse = await supabase
                  .from('outgoings')
                  .insert({
                    'tanggal': tanggalFormat,
                    'no_faktur': noFaktur,
                    'total_harga': subtotal,
                    'tujuan': tujuan,
                  })
                  .select()
                  .single();

              outgoing = insertResponse;
            }

            // Buat detail barang keluar
            await supabase.from('outgoing_details').insert({
              'outgoing_id': outgoing['id'],
              'product_batch_id': batchId,
              'qty_keluar': jumlah,

              'subtotal': subtotal,
            });

            // Update stok batch
            await supabase
                .from('product_batches')
                .update({
                  'qty_keluar': qtyKeluar + jumlah,
                  'qty_sisa': qtySisa - jumlah,
                })
                .eq('id', batchId);

            successCount++;
          } catch (e) {
            debugPrint('Error processing row $i: $e');
            errorCount++;
            continue;
          }
        }
      }

      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import selesai: $successCount berhasil, $errorCount gagal',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Import error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error mengimport data: ${e.toString()}',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final outgoings = await supabase.from('outgoings').select();
    final details = await supabase.from('outgoing_details').select();
    final batches = await supabase
        .from('product_batches')
        .select('*, products(*, sub_kategori(*, kategori(*)))');

    List<Map<String, dynamic>> results = [];

    // Calculate total of all invoices
    _totalAllFaktur = outgoings.fold<int>(0, (sum, outgoing) {
      final raw = outgoing['total_harga'];
      if (raw == null) return sum;
      final cleaned = raw.toString().replaceAll(RegExp(r'[^\d]'), '');
      final parsed = num.tryParse(cleaned) ?? 0;
      return sum + parsed.toInt();
    });
    _totalFaktur = outgoings.length;

    for (var outgoing in outgoings) {
      final outgoingId = outgoing['id'];
      final relatedDetails = details.where(
        (d) => d['outgoing_id'] == outgoingId,
      );

      for (var detail in relatedDetails) {
        final batch = batches.firstWhere(
          (b) => b['id'] == detail['product_batch_id'],
          orElse: () => {
            'batch_code': '-',
            'exp': null,
            'products': {
              'nama_produk': '-',
              'satuan': '-',
              'tag': '-',
              'jenis': 'default',
              'sub_kategori': {
                'nama': '-',
                'kategori': {'nama': '-'},
              },
            },
          },
        );

        final product = batch['products'] ?? {};
        final totalHarga = outgoing['total_harga'];
        final subKategori = product['sub_kategori']?['nama'] ?? '-';
        final kategori = product['sub_kategori']?['kategori']?['nama'] ?? '-';
        final tujuan = outgoing['tujuan'] ?? '-';

        results.add({
          'kode_batch': detail['batch_code'] ?? batch['batch_code'] ?? '-',
          'no_faktur': outgoing['no_faktur'] ?? '-',
          'tujuan': tujuan,
          'tanggal': outgoing['tanggal'],
          'formatted_date': DateFormat(
            'dd/MM/yyyy',
          ).format(DateTime.parse(outgoing['tanggal'])),
          'nama_produk': product['nama_produk'] ?? '-',
          'jenis': product['jenis'] ?? 'default',
          'qty': detail['qty_keluar'] ?? 0,
          'exp': batch['exp'] ?? detail['exp'],
          'total_harga': totalHarga,
          'status': 'Selesai',
          'satuan': product['satuan'] ?? '-',
          'tag': product['tag'] ?? '-',
          'keterangan': outgoing['catatan'] ?? '-',
          'kategori': kategori,
          'sub_kategori': subKategori,
          'id': outgoing['id'].toString(),
        });
      }
    }

    final uniqueDates = results.map((r) => r['tanggal']).toSet();
    for (var date in uniqueDates) {
      _expandedDates[date] = false;
    }

    setState(() {
      _outgoings = results;
      _filtered = results;
      _isLoading = false;
    });
  }

  void _filterByDateRange(DateTimeRange? range) {
    setState(() {
      _selectedDateRange = range;
      if (range == null) {
        _filtered = _outgoings;
      } else {
        _filtered = _outgoings.where((item) {
          final tanggal = DateTime.tryParse(item['tanggal'] ?? '');
          return tanggal != null &&
              tanggal.isAfter(range.start.subtract(Duration(days: 1))) &&
              tanggal.isBefore(range.end.add(Duration(days: 1)));
        }).toList();
      }
    });
  }

  void _search(String query) {
    setState(() {
      _searchQuery = query;
      _filtered = _outgoings
          .where(
            (item) => (item['nama_produk'] ?? '')
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  void _toggleExpandDate(String date) {
    setState(() {
      _expandedDates[date] = !_expandedDates[date]!;
    });
  }

  String formatHarga(dynamic hargaRaw) {
    final cleaned =
        hargaRaw?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '0';
    final total = int.tryParse(cleaned) ?? 0;
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(total);
  }

  IconData _getMedicineIcon(String jenis) {
    return _medicineIcons[jenis.toLowerCase()] ?? _medicineIcons['default']!;
  }

  Future<void> _showAddMenu(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.qr_code_scanner, color: primaryColor),
              title: Text('Scan Barcode'),
              onTap: () => Navigator.pop(context, 'scan'),
            ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Icons.edit, color: primaryColor),
              title: Text('Entry Manual'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );

    if (result == 'scan') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ScanBarangKeluarPage()),
      );
    } else if (result == 'manual') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EntryManualBarangKeluarPage()),
      );
    }
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final groupedOutgoings =
        <String, Map<String, List<Map<String, dynamic>>>>{};

    for (var outgoing in _filtered) {
      final date = outgoing['tanggal'] ?? '-';
      final noFaktur = outgoing['no_faktur'] ?? '-';

      groupedOutgoings[date] ??= {};
      groupedOutgoings[date]![noFaktur] ??= [];
      groupedOutgoings[date]![noFaktur]!.add(outgoing);
    }

    final sortedDates = groupedOutgoings.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Barang Keluar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file, size: 28),
            tooltip: 'Import Excel',
            onPressed: _showImportDialog,
          ),
          IconButton(
            icon: Icon(Icons.add, size: 28),
            tooltip: 'Tambah Barang Keluar',
            onPressed: () => _showAddMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: 'Cari produk...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.date_range),
                    label: Text('Filter Tanggal'),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _selectedDateRange,
                      );
                      _filterByDateRange(picked);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (!_isLoading && _filtered.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Faktur:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          '${_totalFaktur} ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Penjualan:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          formatHarga(_totalAllFaktur),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 8),
          if (_isLoading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  strokeWidth: 3,
                ),
              ),
            )
          else if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2, size: 60, color: Colors.grey[300]),
                    SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? 'Tidak ada data barang keluar'
                          : 'Hasil pencarian tidak ditemukan',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: 16),
                itemCount: sortedDates.length,
                itemBuilder: (context, index) {
                  final date = sortedDates[index];
                  final fakturMap = groupedOutgoings[date]!;
                  final formattedDate = DateFormat(
                    'EEEE, dd MMMM yyyy',
                    'id-ID',
                  ).format(DateTime.tryParse(date) ?? DateTime.now());

                  return _buildDateGroup(date, formattedDate, fakturMap);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateGroup(
    String date,
    String formattedDate,
    Map<String, List<Map<String, dynamic>>> fakturMap,
  ) {
    int totalAllQty = 0;
    int totalAllHarga = 0;

    for (var items in fakturMap.values) {
      totalAllQty += items.fold<int>(0, (sum, item) {
        final qty = item['qty'];
        return sum + ((qty is num) ? qty.toInt() : 0);
      });

      final raw = items.first['total_harga'];
      if (raw != null) {
        final cleaned = raw.toString().replaceAll(RegExp(r'[^\d]'), '');
        final parsed = num.tryParse(cleaned) ?? 0;
        totalAllHarga += parsed.toInt();
      }
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.calendar_today, color: primaryColor),
        ),
        title: Text(
          formattedDate,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Qty: $totalAllQty'),
            Text(
              'Total Harga: ${formatHarga(totalAllHarga)}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: primaryColor,
              ),
            ),
          ],
        ),
        trailing: Icon(
          _expandedDates[date]! ? Icons.expand_less : Icons.expand_more,
          color: primaryColor,
        ),
        onExpansionChanged: (expanded) => _toggleExpandDate(date),
        children: [
          Divider(height: 1, indent: 16, endIndent: 16),
          ...fakturMap.entries.map((entry) {
            final noFaktur = entry.key;
            final items = entry.value;
            return _buildFakturGroup(noFaktur, items);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildFakturGroup(String noFaktur, List<Map<String, dynamic>> items) {
    final totalQty = items.fold<int>(0, (sum, item) {
      final qty = item['qty'];
      return sum + ((qty is num) ? qty.toInt() : 0);
    });

    final receiptTotal = items.isNotEmpty ? items.first['total_harga'] ?? 0 : 0;

    final receiptId = items.isNotEmpty ? items.first['id'] : null;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey[200]!, width: 2)),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Faktur: $noFaktur',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (receiptId != null)
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red[400], size: 20),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                onPressed: () =>
                    _confirmDeleteOutgoing(receiptId, noFaktur, items),
              ),
          ],
        ),
        subtitle: RichText(
          text: TextSpan(
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            children: [
              TextSpan(text: '${items.length} item • '),
              TextSpan(text: 'Qty: $totalQty • '),
              TextSpan(
                text: 'Total Faktur: ${formatHarga(receiptTotal)}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
        children: items.map((item) => _buildOutgoingItem(item)).toList(),
      ),
    );
  }

  Widget _buildOutgoingItem(Map<String, dynamic> data) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Icon(_getMedicineIcon(data['jenis']), color: primaryColor),
        ),
        title: Text(
          data['nama_produk'] ?? '-',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['formatted_date'] ?? '-',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 6),
            _buildInfoRow('Qty', '${data['qty'] ?? 0} ${data['satuan']}'),
            _buildInfoRow('Batch', '${data['kode_batch']}'),
            _buildInfoRow('Tujuan', '${data['tujuan']}'),
            _buildInfoRow('EXP', '${data['exp']}'),
            _buildInfoRow(
              'Kategori',
              '${data['kategori']} > ${data['sub_kategori']}',
            ),
            _buildInfoRow('Tag', '${data['tag'] ?? '-'}'),
            _buildInfoRow(
              'Total Harga',
              '${formatHarga(data['total_harga'] ?? 0)}',
            ),
            if ((data['keterangan'] ?? '').isNotEmpty)
              _buildInfoRow('Catatan', data['keterangan']),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.grey[700], fontSize: 12),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
