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

  List<Map<String, dynamic>> _dataKeluar = [];
  final List<String> _tujuanList = [];
  String? _filterStatus;
  String? _filterTujuan;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBarangKeluar();
  }

  Future<void> _loadBarangKeluar() async {
    setState(() => _isLoading = true);

    final outgoings = await supabase.from('outgoings').select();
    final details = await supabase.from('outgoing_details').select();
    final batches = await supabase.from('product_batches').select();
    final products = await supabase.from('products').select();

    List<Map<String, dynamic>> results = [];

    for (var keluar in outgoings) {
      final keluarId = keluar['id'];
      final relatedDetails = details.where((d) => d['outgoing_id'] == keluarId);

      for (var detail in relatedDetails) {
        final batch = batches.firstWhere(
          (b) => b['id'] == detail['product_batch_id'],
          orElse: () => {},
        );

        final product = products.firstWhere(
          (p) => p['id'] == batch['product_id'],
          orElse: () => {'nama_produk': '-', 'satuan': '-'},
        );

        final tujuan = keluar['tujuan'] ?? '-';
        if (!_tujuanList.contains(tujuan)) {
          _tujuanList.add(tujuan);
        }

        results.add({
          'kode_batch': batch['batch_code'] ?? '-',
          'no_faktur': keluar['no_faktur'] ?? '-',
          'tanggal': DateFormat(
            'dd/MM/yyyy',
          ).format(DateTime.parse(keluar['tanggal'])),
          'nama_produk': product['nama_produk'] ?? '-',
          'qty': detail['qty_keluar'] ?? 0,
          'satuan': product['satuan'] ?? '-',
          'exp': batch['exp'],
          'total_harga': keluar['total_harga'],
          'tujuan': tujuan,
          'status': 'Selesai',
        });
      }
    }

    setState(() {
      _dataKeluar = results;
      _isLoading = false;
    });
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Data'),
        content: Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

        await supabase
            .from('outgoing_details')
            .delete()
            .eq('outgoing_id', outgoingId);
        await supabase.from('outgoings').delete().eq('id', outgoingId);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Data berhasil dihapus')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus data')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = _dataKeluar.where((item) {
      final statusMatch =
          _filterStatus == null || item['status'] == _filterStatus;
      final tujuanMatch =
          _filterTujuan == null || item['tujuan'] == _filterTujuan;
      return statusMatch && tujuanMatch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Barang Keluar'),
        centerTitle: true,
        backgroundColor: Color(0xFF03A6A1),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),

      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari produk...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Color(0xFF03A6A1),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.add_circle,
                          color: Color(0xFF03A6A1),
                          size: 32,
                        ),
                        onSelected: (value) async {
                          if (value == 'scan') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScanBarangKeluarPage(),
                              ),
                            );
                          } else if (value == 'manual') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EntryManualBarangKeluarPage(),
                              ),
                            );
                          }
                          _loadBarangKeluar(); // Refresh data
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'scan',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.qr_code_scanner,
                                  color: Color(0xFF03A6A1),
                                ),
                                SizedBox(width: 8),
                                Text('Scan Barcode'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'manual',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Color(0xFF03A6A1)),
                                SizedBox(width: 8),
                                Text('Entry Manual'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: filteredData.isEmpty
                      ? Center(
                          child: Text(
                            'Belum ada data barang keluar.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredData.length,
                          itemBuilder: (context, index) {
                            final item = filteredData[index];
                            return Dismissible(
                              key: ValueKey(
                                '${item['no_faktur']}_${item['kode_batch']}',
                              ),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (_) => _confirmDelete(context),
                              onDismissed: (_) async {
                                await _deleteOutgoing(item['no_faktur']);
                                setState(() => _dataKeluar.remove(item));
                              },
                              child: _buildCard(item),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCard(Map<String, dynamic> data) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Produk & Exp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data['nama_produk'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF03A6A1),
                  ),
                ),
                if (data['exp'] != null)
                  Text(
                    'Exp: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(data['exp']))}',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
            Divider(),
            Text('Kode Batch: ${data['kode_batch']}'),
            Text('No. Faktur: ${data['no_faktur']}'),
            Text('Tujuan: ${data['tujuan']}'),
            Text('Tanggal Keluar: ${data['tanggal']}'),
            Text('Jumlah: ${data['qty']} ${data['satuan']}'),
            Text(
              'Total: Rp ${data['total_harga']}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    String? selectedStatus = _filterStatus;
    String? selectedTujuan = _filterTujuan;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Filter Barang Keluar',
          style: TextStyle(color: Color(0xFF03A6A1)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
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
              ),
              items: [
                DropdownMenuItem(value: null, child: Text('Semua Tujuan')),
                ..._tujuanList.map(
                  (t) => DropdownMenuItem(value: t, child: Text(t)),
                ),
              ],
              onChanged: (value) => selectedTujuan = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterStatus = null;
                _filterTujuan = null;
              });
              Navigator.pop(context);
            },
            child: Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _filterStatus = selectedStatus;
                _filterTujuan = selectedTujuan;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF03A6A1)),
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
