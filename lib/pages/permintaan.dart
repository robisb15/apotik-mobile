
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:excel/excel.dart' as exceldata;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'form/entry_manual.dart';
import 'form/barcode_masuk.dart';

class GroupedBarangMasukPage extends StatefulWidget {
  @override
  State<GroupedBarangMasukPage> createState() => _GroupedBarangMasukPageState();
}

class _GroupedBarangMasukPageState extends State<GroupedBarangMasukPage> {
  final supabase = Supabase.instance.client;
  final Color primaryColor = Color(0xFF03A6A1);
  final Color accentColor = Color(0xFF4DB6AC);
  final Map<String, bool> _expandedDates = {};
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _receipts = [];
  String _searchQuery = '';
  int _totalAllFaktur = 0;
  int _totalFaktur = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _confirmDeleteReceipt(
    String receiptId,
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
      await _deleteReceipt(receiptId, items);
    }
  }

  Future<void> _deleteReceipt(
    String receiptId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      setState(() => _isLoading = true);

      // 1. Get all receipt_details for this receipt
      final receiptDetails = await supabase
          .from('receipt_details')
          .select()
          .eq('receipt_id', receiptId);

      // 2. Soft delete all product batches in receipt_details
      for (final detail in receiptDetails) {
        await supabase
            .from('product_batches')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', detail['product_batch_id']);
      }

      // 3. Soft delete all receipt_details
      await supabase
          .from('receipt_details')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('receipt_id', receiptId);

      // 4. Soft delete the receipt
      await supabase
          .from('receipts')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', receiptId);

      // 5. Reload data
      await _loadData();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Faktur berhasil dihapus')));
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

            // Tombol Download Template
            ElevatedButton.icon(
              onPressed: _downloadTemplateExcel,
              icon: Icon(Icons.download),
              label: Text('Download Template Excel'),
            ),

            SizedBox(height: 16),

            // Tombol Pilih File
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
      // Android 13+
      final permissionStatus = await Permission.manageExternalStorage.request();
      return permissionStatus.isGranted;
    } else {
      // Android < 13
      final permissionStatus = await Permission.storage.request();
      return permissionStatus.isGranted;
    }
  }

  Future<void> _downloadTemplateExcel() async {
    try {
      // Minta izin akses penyimpanan
      if (!await requestStoragePermission()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Izin penyimpanan ditolak')));
        return;
      }

      // Baca file dari assets
      final byteData = await rootBundle.load('assets/datamasuk.xlsx');

      // Tentukan folder simpan
      final downloadDir = Directory('/storage/emulated/0/Download');

      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final filePath = '${downloadDir.path}/datamasuk.xlsx';
      final file = File(filePath);

      // Tulis file
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

    // Jika nilai numerik → kemungkinan serial Excel
    if (value is num) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        ((value - 25569) * 86400000).toInt(), // 25569 = epoch Excel
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

    // Fallback jika tidak bisa diparse
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
        if (sheet.rows.length <= 1) continue; // Skip if only header or empty

        for (int i = 1; i < sheet.rows.length; i++) {
          try {
            final row = sheet.rows[i];

            if (row.length < 9) {
              // Minimum 9 columns expected
              errorCount++;
              print('1');
              continue;
            }

            // Parse with null safety
            final noFaktur = row[0]?.value?.toString()?.trim() ?? '';
            final tanggal = row[1]?.value?.toString()?.trim() ?? '';
            final namaProduk = row[2]?.value?.toString()?.trim() ?? '';
            final distributor = row[3]?.value?.toString()?.trim() ?? '';
            final batchNumber = row[4]?.value?.toString()?.trim() ?? '';
            final expDate = row[5]?.value?.toString()?.trim() ?? '';
            final satuan = row[6]?.value?.toString()?.trim() ?? 'pcs';
            final jumlah = int.tryParse(row[7]?.value?.toString() ?? '') ?? 0;
            final subtotal = int.tryParse(row[8]?.value?.toString() ?? '') ?? 0;

            // Validate required fields
            if (noFaktur.isEmpty ||
                tanggal.isEmpty ||
                namaProduk.isEmpty ||
                distributor.isEmpty ||
                batchNumber.isEmpty) {
              errorCount++;
              print(2);
              continue;
            }

            final tanggalFormat = parseTanggalDinamis(tanggal);
            final formattedExp = parseTanggalDinamis(expDate);

            // Process product
            final product = await _findOrCreateProduct(namaProduk, satuan);
            if (product['id'] == null) {
              errorCount++;
              print('3');
              continue;
            }

            // Process distributor
            final distributorId = await _findOrCreateDistributor(distributor);

            if (distributorId == null) {
              errorCount++;
              print('4');
              continue;
            }

            // Create product batch
            final batchResponse = await supabase.from('product_batches').insert(
              {
                'batch_code': batchNumber,
                'product_id': product['id'],
                'distributor_id': distributorId,
                'exp': formattedExp,
                'qty_masuk': jumlah,
                'qty_keluar': 0,
                'qty_sisa': jumlah, // Initial sisa equals masuk
              },
            ).select();

            if (batchResponse.isEmpty) {
              errorCount++;
              print('5');
              continue;
            }
            final batchId = batchResponse[0]['id'];

            // Handle receipt
            final existing = await supabase
                .from('receipts')
                .select()
                .eq('no_faktur', noFaktur)
                .maybeSingle();

            Map<String, dynamic> receipt;
            if (existing != null) {
              final existingTotalRaw = existing['total_harga'];
              final existingTotal = existingTotalRaw is num
                  ? existingTotalRaw
                  : int.tryParse(existingTotalRaw.toString()) ?? 0;
              final updatedTotal = existingTotal + subtotal;

              final updateResponseList = await supabase
                  .from('receipts')
                  .update({
                    'total_harga': updatedTotal,
                    'tanggal': tanggalFormat,
                  })
                  .eq('no_faktur', noFaktur)
                  .select();

              if (updateResponseList.isEmpty) {
                throw Exception(
                  'Gagal update receipt dengan no_faktur $noFaktur',
                );
              }

              receipt = updateResponseList.first;
            } else {
              final insertResponseList =
                  await supabase.from('receipts').insert({
                    'tanggal': tanggalFormat,
                    'no_faktur': noFaktur,
                    'total_harga': subtotal,
                  }).select();

              if (insertResponseList.isEmpty) {
                throw Exception(
                  'Gagal insert receipt dengan no_faktur $noFaktur',
                );
              }

              receipt = insertResponseList.first;
            }

            // Create receipt detail
            await supabase.from('receipt_details').insert({
              'receipt_id': receipt['id'],
              'product_batch_id': batchId,
              'distributor_id': distributorId,
              'qty_diterima': jumlah,
              'subtotal': subtotal,
            });

            successCount++;
          } catch (e) {
            debugPrint('Error processing row $i: $e');
            errorCount++;
            print('6');
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

  Future<Map<String, dynamic>> _findOrCreateProduct(
    String namaProduk,
    String satuan,
  ) async {
    try {
      final existingList = await supabase
          .from('products')
          .select()
          .eq('nama_produk', namaProduk);

      if (existingList.isNotEmpty) {
        return existingList.first;
      }

      final insertResponseList = await supabase.from('products').insert({
        'nama_produk': namaProduk,
        'satuan': satuan,
      }).select();

      if (insertResponseList.isEmpty) {
        throw Exception('Gagal insert produk $namaProduk');
      }

      return insertResponseList.first;
    } catch (e) {
      debugPrint('Error _findOrCreateProduct: $e');
      return {};
    }
  }

  Future<int?> _findOrCreateDistributor(String namaDistributor) async {
    try {
      final existingList = await supabase
          .from('distributors')
          .select()
          .eq('nama', namaDistributor);

      if (existingList.isNotEmpty) {
        return existingList.first['id'];
      }

      final insertResponseList = await supabase.from('distributors').insert({
        'nama': namaDistributor,
      }).select();

      if (insertResponseList.isEmpty) {
        throw Exception('Gagal insert distributor $namaDistributor');
      }

      return insertResponseList.first['id'];
    } catch (e) {
      debugPrint('Error _findOrCreateDistributor: $e');
      return null;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _receipts = await supabase
        .from('receipts')
        .select()
        .filter('deleted_at', 'is', null);

    final details = await supabase.from('receipt_details').select();
    final dataFaktur = await supabase
        .from('receipts')
        .select()
        .filter('deleted_at', 'is', null);
    final batches = await supabase
        .from('product_batches')
        .select('*, products(*, sub_kategori(*, kategori(*)))');

    final distributors = await supabase.from('distributors').select();

    List<Map<String, dynamic>> results = [];

    // Calculate total of all invoices
    _totalAllFaktur = _receipts.fold<int>(0, (sum, receipt) {
      final raw = receipt['total_harga'];
      if (raw == null) return sum;
      final cleaned = raw.toString().replaceAll(RegExp(r'[^\d]'), '');
      final parsed = num.tryParse(cleaned) ?? 0;
      return sum + parsed.toInt();
    });
    _totalFaktur = dataFaktur.length;

    for (var receipt in _receipts) {
      final relatedDetails = details.where(
        (d) => d['receipt_id'] == receipt['id'],
      );

      for (var detail in relatedDetails) {
        final batch = batches.firstWhere(
          (b) => b['id'] == detail['product_batch_id'],
          orElse: () => {
            'products': {
              'nama_produk': '-',
              'satuan': '-',
              'tag': '-',
              'jenis': '-',
              'sub_kategori': {
                'nama': '-',
                'kategori': {'nama': '-'},
              },
            },
          },
        );

        final distributor = distributors.firstWhere(
          (d) => d['id'] == detail['distributor_id'],
          orElse: () => {'nama': '-'},
        );

        final product = batch['products'] ?? {};
        final tanggal = receipt['tanggal'] ?? '-';

        results.add({
          'tanggal': tanggal,
          'formatted_date': DateFormat(
            'dd/MM/yyyy',
          ).format(DateTime.tryParse(tanggal) ?? DateTime.now()),
          'no_faktur': receipt['no_faktur'] ?? '-',
          'id': '${receipt['id'] ?? '-'}',
          'harga_faktur': receipt['total_harga'] ?? '-',
          'qty': detail['qty_diterima'] ?? 0,
          'total_harga': receipt['total_harga'], // Take from receipts table
          'nama_produk': product['nama_produk'] ?? '-',
          'satuan': product['satuan'] ?? '-',
          'distributor': distributor['nama'],
          'jenis': product['jenis'],
          'kode_batch': batch['batch_code'] ?? '-',
          'kategori': product['sub_kategori']?['kategori']?['nama'] ?? '-',
          'sub_kategori': product['sub_kategori']?['nama'] ?? '-',
          'tag': product['tag'] ?? '-',
          'subtotal': detail['subtotal'] ?? 0,
          'exp': detail['exp'] ?? '-',
          'keterangan': receipt['catatan'] ?? '-',
        });
      }
    }

    final uniqueDates = results.map((r) => r['tanggal']).toSet();
    for (var date in uniqueDates) {
      _expandedDates[date] = false;
    }

    setState(() {
      _requests = results;
      _filtered = results;
      _isLoading = false;
    });
  }

  DateTimeRange? _selectedDateRange;

  void _filterByDateRange(DateTimeRange? range) {
    setState(() {
      _selectedDateRange = range;
      if (range == null) {
        _filtered = _requests;
      } else {
        _filtered = _requests.where((item) {
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
      _filtered = _requests
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

  @override
  Widget build(BuildContext context) {
    final groupedRequests = <String, Map<String, List<Map<String, dynamic>>>>{};

    for (var request in _filtered) {
      final date = request['tanggal'] ?? '-';
      final noFaktur = request['no_faktur'] ?? '-';

      groupedRequests[date] ??= {};
      groupedRequests[date]![noFaktur] ??= [];
      groupedRequests[date]![noFaktur]!.add(request);
    }

    final sortedDates = groupedRequests.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Barang Masuk',
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
            tooltip: 'Entry Manual',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EntryManualPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.qr_code_scanner, size: 28),
            tooltip: 'Scan Barcode',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EntryScanBarcodePage()),
              );
            },
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
          // Total faktur display
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
                    SizedBox(height: 8), // Jarak antar baris (opsional)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Pembelian:',
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
                          ? 'Tidak ada data barang masuk'
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
                  final fakturMap = groupedRequests[date]!;
                  final formattedDate = DateFormat(
                    'EEEE, dd MMMM yyyy',
                    'id_ID',
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
      // Jumlahkan qty semua item (boleh karena qty memang per-item)
      totalAllQty += items.fold<int>(0, (sum, item) {
        final qty = item['qty'];
        return sum + ((qty is num) ? qty.toInt() : 0);
      });

      // Ambil harga_faktur hanya dari satu item (karena itu total per faktur)
      final raw = items.first['harga_faktur'];
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

    // Get the total_harga from the first item (since all items in this group share the same receipt)
    final receiptTotal = items.isNotEmpty
        ? items.first['harga_faktur'] ?? 0
        : 0;

    // Get receipt ID from first item
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
                    _confirmDeleteReceipt(receiptId, noFaktur, items),
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
        children: items.map((item) => _buildRequestItem(item)).toList(),
      ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> data) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            _buildInfoRow('EXP', '${data['exp']}'),
            _buildInfoRow(
              'Kategori',
              '${data['kategori']} > ${data['sub_kategori']}',
            ),
            _buildInfoRow('Tag', '${data['tag'] ?? '-'}'),
            _buildInfoRow('Subtotal', '${formatHarga(data['subtotal'] ?? 0)}'),
            _buildInfoRow('Distributor', data['distributor']),
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
