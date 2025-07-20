// Entry manual untuk Barang Keluar (dengan pilihan batch)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class EntryManualBarangKeluarPage extends StatefulWidget {
  @override
  _EntryManualBarangKeluarPageState createState() =>
      _EntryManualBarangKeluarPageState();
}

class _EntryManualBarangKeluarPageState
    extends State<EntryManualBarangKeluarPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _batches = [];
  Map<String, dynamic>? _selectedBatch;

  final _qtyController = TextEditingController();
  final _fakturController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _tujuanController = TextEditingController();
  final _totalHargaController = TextEditingController();
  final _catatanController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    final res = await supabase
        .from('product_batches')
        .select(
          'id, batch_code, exp, product_id, products(nama_produk, barcode, produsen),qty_sisa,qty_masuk,qty_keluar',
        );

    setState(() {
      _batches = List<Map<String, dynamic>>.from(res);
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate() || _selectedBatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pastikan semua data terisi dengan benar')),
      );
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      final tanggal = DateFormat('yyyy-MM-dd').parse(_tanggalController.text);
      final outgoing = await supabase
          .from('outgoings')
          .insert({
            'no_faktur': _fakturController.text,
            'tanggal': tanggal.toIso8601String(),
            'tujuan': _tujuanController.text,
            'user_id': user.id,
            'total_harga': int.parse(
              _totalHargaController.text.replaceAll('.', ''),
            ),
            'catatan': _catatanController.text,
          })
          .select()
          .single();

      await supabase.from('outgoing_details').insert({
        'outgoing_id': outgoing['id'],
        'product_batch_id': _selectedBatch!['id'],
        'qty_keluar': int.parse(_qtyController.text),
      });
      // Update qty_keluar dan qty_sisa di product_batches
      final batchId = _selectedBatch!['id'];

      // Ambil data qty_keluar dan qty_masuk sebelumnya
      final batchData = await supabase
          .from('product_batches')
          .select('qty_masuk, qty_keluar')
          .eq('id', batchId)
          .single();

      final qtyMasuk = batchData['qty_masuk'] ?? 0;
      final qtyKeluarLama = batchData['qty_keluar'] ?? 0;
      final qtyKeluarBaru = qtyKeluarLama + int.parse(_qtyController.text);
      final qtySisaBaru = qtyMasuk - qtyKeluarBaru;

      await supabase
          .from('product_batches')
          .update({'qty_keluar': qtyKeluarBaru, 'qty_sisa': qtySisaBaru})
          .eq('id', batchId);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Data berhasil disimpan')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Entry Manual Barang Keluar'),
        backgroundColor: Color(0xFF03A6A1),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedBatch,
                      items: _batches.map((batch) {
                        final product = batch['products'];
                        return DropdownMenuItem(
                          value: batch,
                          child: Text(
                            '${batch['batch_code']} - ${product['nama_produk']}',
                          ),
                        );
                      }).toList(),
                      decoration: InputDecoration(
                        labelText: 'Pilih Kode Batch',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _selectedBatch = v),
                      validator: (v) => v == null ? 'Pilih batch' : null,
                    ),
                    if (_selectedBatch != null) ...[
                      SizedBox(height: 16),
                      _buildInfoRow(
                        'Nama Produk',
                        _selectedBatch!['products']['nama_produk'] ?? '',
                      ),
                      _buildInfoRow(
                        'Barcode',
                        (_selectedBatch!['products']['barcode'] ?? '')
                            .toString(),
                      ),
                      _buildInfoRow(
                        'Produsen',
                        _selectedBatch!['products']['produsen'] ?? '',
                      ),
                      _buildInfoRow(
                        'Stok Tersisa',
                        '${_selectedBatch!['qty_sisa'] ?? ''}',
                      ),
                      _buildInfoRow(
                        'Tanggal Exp',
                        DateFormat(
                          'dd/MM/yyyy',
                        ).format(DateTime.parse(_selectedBatch!['exp'] ?? '')),
                      ),
                    ],
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _qtyController,
                      decoration: InputDecoration(
                        labelText: 'Qty Keluar',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _tujuanController,
                      decoration: InputDecoration(
                        labelText: 'Tujuan',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Tujuan wajib diisi'
                          : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _fakturController,
                      decoration: InputDecoration(
                        labelText: 'No Faktur',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _tanggalController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Tanggal Keluar',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null)
                          _tanggalController.text = DateFormat(
                            'yyyy-MM-dd',
                          ).format(picked);
                      },
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Tanggal wajib diisi'
                          : null,
                    ),
                    SizedBox(height: 24),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _totalHargaController,
                      decoration: InputDecoration(
                        labelText: 'Total Harga (Rp)',
                        border: OutlineInputBorder(),
                        prefixText: 'Rp ',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Total harga wajib diisi';
                        if (int.tryParse(v.replaceAll('.', '')) == null)
                          return 'Total harga harus angka';
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _catatanController,
                      decoration: InputDecoration(
                        labelText: 'Catatan',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),

                    ElevatedButton(
                      onPressed: _saveData,
                      child: Text('Simpan Data'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48),
                        backgroundColor: Color(0xFF03A6A1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _fakturController.dispose();
    _tanggalController.dispose();
    _tujuanController.dispose();
    _totalHargaController.dispose();
    _catatanController.dispose();
    super.dispose();
  }
}
