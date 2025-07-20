import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/form/barcode_keluar.dart';
import 'package:flutter_application_1/pages/form/entry_manual_keluar.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BarangKeluarPage extends StatefulWidget {
  @override
  _BarangKeluarPageState createState() => _BarangKeluarPageState();
}

class _BarangKeluarPageState extends State<BarangKeluarPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  String? _filterStatus;
  String? _filterTujuan;
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  List<Map<String, dynamic>> _outgoings = [];
  final List<String> _tujuanList = [];
  bool _isLoading = true;
  final Map<String, bool> _expandedDates = {};

  // Color Scheme
  final Color primaryColor = Color(0xFF03A6A1);
  final Color primaryLightColor = Color(0xFFE0F7F6);
  final Color accentColor = Color(0xFFFF7D33);
  final Color dangerColor = Color(0xFFF44336);
  final Color successColor = Color(0xFF4CAF50);

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
    _loadOutgoings();
  }

  Future<void> _loadOutgoings() async {
    setState(() => _isLoading = true);

    final outgoings = await supabase.from('outgoings').select();
    final details = await supabase.from('outgoing_details').select();
    final batches = await supabase.from('product_batches').select('*, products(*, sub_kategori(*, kategori(*)))');

    List<Map<String, dynamic>> results = [];

    for (var outgoing in outgoings) {
      final outgoingId = outgoing['id'];
      final relatedDetails = details.where((d) => d['outgoing_id'] == outgoingId);

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
                'kategori': {'nama': '-'}
              }
            }
          },
        );

        final product = batch['products'] ?? {};
        final totalHarga = outgoing['total_harga'];
        final subKategori = product['sub_kategori']?['nama'] ?? '-';
        final kategori = product['sub_kategori']?['kategori']?['nama'] ?? '-';
        final tujuan = outgoing['tujuan'] ?? '-';

        // Add to filter lists if not already present
        if (!_tujuanList.contains(tujuan)) {
          _tujuanList.add(tujuan);
        }

        results.add({
          'kode_batch': detail['batch_code'] ?? batch['batch_code'] ?? '-',
          'no_faktur': outgoing['no_faktur'] ?? '-',
          'tujuan': tujuan,
          'tanggal': outgoing['tanggal'],
          'formatted_date': DateFormat('dd/MM/yyyy').format(DateTime.parse(outgoing['tanggal'])),
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
        });
      }
    }

    // Initialize expanded state for each date
    final uniqueDates = results.map((r) => r['tanggal']).toSet();
    for (var date in uniqueDates) {
      _expandedDates[date] = false;
    }

    setState(() {
      _outgoings = results;
      _isLoading = false;
    });
  }

  void _toggleExpandDate(String date) {
    setState(() {
      _expandedDates[date] = !_expandedDates[date]!;
    });
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Data'),
        content: Text('Yakin ingin menghapus barang keluar ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dangerColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String formatHarga(dynamic hargaRaw) {
    final cleaned = hargaRaw.toString().replaceAll(RegExp(r'[^\d]'), '');
    final total = int.tryParse(cleaned) ?? 0;
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(total);
  }

  Future<void> _deleteOutgoing(String noFaktur) async {
  try {
    final outgoing = await supabase
        .from('outgoings')
        .select('id')
        .eq('no_faktur', noFaktur)
        .maybeSingle();

    if (outgoing != null && outgoing['id'] != null) {
      final outgoingId = outgoing['id'];

      // Get all outgoing details for this outgoing record
      final outgoingDetails = await supabase
          .from('outgoing_details')
          .select('product_batch_id, qty_keluar')
          .eq('outgoing_id', outgoingId);

      // First, update all related product batches
      for (var detail in outgoingDetails) {
        final batchId = detail['product_batch_id'];
        final qtyKeluar = detail['qty_keluar'] ?? 0;

        // Get current batch data
        final batch = await supabase
            .from('product_batches')
            .select('qty_keluar, qty_sisa')
            .eq('id', batchId)
            .single();

        if (batch != null) {
          final currentQtyKeluar = batch['qty_keluar'] ?? 0;
          final currentQtySisa = batch['qty_sisa'] ?? 0;

          // Calculate new quantities
          final newQtyKeluar = currentQtyKeluar - qtyKeluar;
          final newQtySisa = currentQtySisa + qtyKeluar;

          // Update the product batch
          await supabase
              .from('product_batches')
              .update({
                'qty_keluar': newQtyKeluar,
                'qty_sisa': newQtySisa
              })
              .eq('id', batchId);
        }
      }

      // Then delete the outgoing details
      await supabase
          .from('outgoing_details')
          .delete()
          .eq('outgoing_id', outgoingId);

      // Finally delete the outgoing record
      await supabase.from('outgoings').delete().eq('id', outgoingId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data berhasil dihapus dan stok diperbarui'),
          backgroundColor: successColor,
        ),
      );

      await _loadOutgoings();
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal menghapus data: ${e.toString()}'),
        backgroundColor: dangerColor,
      ),
    );
    print('Delete error: $e');
  }
}

  IconData _getMedicineIcon(String jenis) {
    return _medicineIcons[jenis.toLowerCase()] ?? _medicineIcons['default']!;
  }

  @override
  Widget build(BuildContext context) {
    final searchText = _searchController.text.toLowerCase();

    final filteredOutgoings = _outgoings.where((outgoing) {
      final statusMatch = _filterStatus == null || outgoing['status'] == _filterStatus;
      final tujuanMatch = _filterTujuan == null || outgoing['tujuan'] == _filterTujuan;

      // Search functionality
      final searchMatch = searchText.isEmpty ||
          outgoing['nama_produk'].toString().toLowerCase().contains(searchText) ||
          outgoing['kode_batch'].toString().toLowerCase().contains(searchText) ||
          outgoing['no_faktur'].toString().toLowerCase().contains(searchText);

      // Date filtering
      final outgoingDate = DateTime.tryParse(outgoing['tanggal'] ?? '') ?? DateTime.now();
      final dateMatch = (selectedStartDate == null || outgoingDate.isAfter(selectedStartDate!.subtract(Duration(days: 1)))) &&
          (selectedEndDate == null || outgoingDate.isBefore(selectedEndDate!.add(Duration(days: 1))));

      return statusMatch && tujuanMatch && searchMatch && dateMatch;
    }).toList();

    // Group by date
    final groupedOutgoings = <String, List<Map<String, dynamic>>>{};
    for (var outgoing in filteredOutgoings) {
      final date = outgoing['tanggal'];
      if (!groupedOutgoings.containsKey(date)) {
        groupedOutgoings[date] = [];
      }
      groupedOutgoings[date]!.add(outgoing);
    }

    // Sort dates in descending order
    final sortedDates = groupedOutgoings.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text('Barang Keluar'),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () => _showAddMenu(context),
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari barang keluar...',
                          prefixIcon: Icon(Icons.search, color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedStartDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => selectedStartDate = picked);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  selectedStartDate == null
                                      ? 'Dari Tanggal'
                                      : DateFormat('dd/MM/yyyy').format(selectedStartDate!),
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedEndDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => selectedEndDate = picked);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  selectedEndDate == null
                                      ? 'Sampai Tanggal'
                                      : DateFormat('dd/MM/yyyy').format(selectedEndDate!),
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          if (selectedStartDate != null || selectedEndDate != null)
                            IconButton(
                              icon: Icon(Icons.clear, color: dangerColor),
                              onPressed: () {
                                setState(() {
                                  selectedStartDate = null;
                                  selectedEndDate = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filteredOutgoings.length} data ditemukan',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                ),
                Expanded(
                  child: filteredOutgoings.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada data yang ditemukan',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: sortedDates.length,
                          itemBuilder: (context, index) {
                            final date = sortedDates[index];
                            final outgoings = groupedOutgoings[date]!;
                            final formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id-ID')
                                .format(DateTime.parse(date));
                            
                            return _buildDateGroup(date, formattedDate, outgoings);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDateGroup(String date, String formattedDate, List<Map<String, dynamic>> outgoings) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryLightColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today,
                color: primaryColor,
                size: 20,
              ),
            ),
            title: Text(
              formattedDate,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            trailing: Icon(
              _expandedDates[date]! ? Icons.expand_less : Icons.expand_more,
              color: primaryColor,
            ),
            onTap: () => _toggleExpandDate(date),
          ),
          if (_expandedDates[date]!) ...[
            Divider(height: 1),
            ...outgoings.map((outgoing) => _buildOutgoingItem(outgoing)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildOutgoingItem(Map<String, dynamic> data) {
    return Dismissible(
      key: ValueKey('${data['no_faktur']}_${data['kode_batch']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: dangerColor,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async => await _confirmDelete(context),
      onDismissed: (direction) async => await _deleteOutgoing(data['no_faktur']),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: primaryLightColor,
            radius: 20,
            child: Icon(
              _getMedicineIcon(data['jenis']),
              color: primaryColor,
            ),
          ),
          title: Text(
            data['nama_produk'],
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${data['qty']} ${data['satuan']} • ${data['tujuan']}',
            style: TextStyle(fontSize: 12),
          ),
          trailing: Text(
            data['formatted_date'],
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('No. Faktur', data['no_faktur']),
                  _buildDetailRow('Kode Batch', data['kode_batch']),
                  _buildDetailRow('Tujuan', data['tujuan']),
                  _buildDetailRow('Kategori', data['kategori']),
                  _buildDetailRow('Sub Kategori', data['sub_kategori']??'-'),
                  _buildDetailRow('Tag', data['tag']??'-'),
                  if (data['exp'] != null)
                    _buildDetailRow(
                      'Expired',
                      DateFormat('dd/MM/yyyy').format(DateTime.parse(data['exp'])),
                      isWarning: true,
                    ),
                  _buildDetailRow(
                    'Harga',
                    '${formatHarga(data['total_harga'])}',
                    isBold: true,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Keterangan:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(data['keterangan']),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false, bool isWarning = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isWarning ? dangerColor : Colors.grey[800],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
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
    await _loadOutgoings();
  }

  void _showFilterDialog() {
    String? selectedStatus = _filterStatus;
    String? selectedTujuan = _filterTujuan;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Filter Barang Keluar', style: TextStyle(color: primaryColor)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text('Semua Status')),
                  ...[
                    'Pending',
                    'Diproses',
                    'Selesai',
                  ].map((s) => DropdownMenuItem(value: s, child: Text(s))),
                ],
                onChanged: (value) => selectedStatus = value,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedTujuan,
                decoration: InputDecoration(
                  labelText: 'Tujuan',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text('Semua Tujuan')),
                  ..._tujuanList.map(
                    (t) => DropdownMenuItem(value: t, child: Text(t)),
                  ),
                ],
                onChanged: (value) => selectedTujuan = value,
              ),
              SizedBox(height: 16),
              Text('Tanggal Keluar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedStartDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => selectedStartDate = picked);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          selectedStartDate == null ? 'Dari Tanggal' : DateFormat('dd/MM/yyyy').format(selectedStartDate!),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedEndDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => selectedEndDate = picked);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          selectedEndDate == null ? 'Sampai Tanggal' : DateFormat('dd/MM/yyyy').format(selectedEndDate!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterStatus = null;
                _filterTujuan = null;
                selectedStartDate = null;
                selectedEndDate = null;
              });
              Navigator.pop(context);
            },
            child: Text('Reset', style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _filterStatus = selectedStatus;
                _filterTujuan = selectedTujuan;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text('Terapkan'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}