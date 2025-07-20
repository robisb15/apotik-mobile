// File: scan_barang_keluar_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanBarangKeluarPage extends StatefulWidget {
  @override
  _ScanBarangKeluarPageState createState() => _ScanBarangKeluarPageState();
}

class _ScanBarangKeluarPageState extends State<ScanBarangKeluarPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _selectedBatch;

  final _qtyController = TextEditingController();
  final _fakturController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _tujuanController = TextEditingController();
  final _totalHargaController = TextEditingController();
  final _catatanController = TextEditingController();

  bool _scannerVisible = true;
  bool _isLoading = false;

  Future<void> _onBarcodeDetected(String barcode) async {
    setState(() => _isLoading = true);
    try {
      // Cari product berdasarkan barcode
      final product = await supabase
          .from('products')
          .select('id, nama_produk, produsen, barcode')
          .eq('barcode', barcode)
          .maybeSingle();

      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk tidak ditemukan untuk barcode: $barcode'),
          ),
        );
        setState(() {
          _isLoading = false;
          _scannerVisible = true;
        });
        return;
      }

      // Cari batch berdasarkan product_id
      final batch = await supabase
          .from('product_batches')
          .select(
            'id, batch_code, exp, product_id, qty_sisa, qty_masuk, qty_keluar',
          )
          .eq('product_id', product['id'])
          .order('exp', ascending: true) // ambil yang terdekat expired
          .limit(1)
          .maybeSingle();

      if (batch == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Batch tidak ditemukan untuk produk: ${product['nama_produk']}',
            ),
          ),
        );
        setState(() {
          _isLoading = false;
          _scannerVisible = true;
        });
        return;
      }

      // Gabungkan data produk ke dalam batch
      batch['products'] = product;

      setState(() {
        _selectedBatch = batch;
        _scannerVisible = false;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
      setState(() {
        _isLoading = false;
        _scannerVisible = true;
      });
    }
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

      final batchId = _selectedBatch!['id'];
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
        title: Text('Scan Barang Keluar'),
        backgroundColor: Color(0xFF03A6A1),
      ),
      body: Column(
        children: [
          if (_scannerVisible)
            Expanded(
              flex: 1,
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: (capture) {
                      final barcode = capture.barcodes.firstOrNull?.rawValue;
                      if (barcode != null) _onBarcodeDetected(barcode);
                    },
                  ),
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => setState(() => _scannerVisible = true),
              icon: Icon(Icons.refresh),
              label: Text('Scan Ulang'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          if (!_scannerVisible && _selectedBatch != null)
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        '${_selectedBatch!['products']['nama_produk']} - ${_selectedBatch!['products']['produsen']}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Barcode: ${_selectedBatch!['products']['barcode']}',
                      ),
                      Text('Batch: ${_selectedBatch!['batch_code']}'),
                      Text('Stok Tersisa: ${_selectedBatch!['qty_sisa']}'),
                      Text(
                        'Expired: ${DateFormat('dd-MM-yyyy').format(DateTime.parse(_selectedBatch!['exp']))}',
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _qtyController,
                        decoration: InputDecoration(
                          labelText: 'Qty Keluar',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _tujuanController,
                        decoration: InputDecoration(
                          labelText: 'Tujuan',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _fakturController,
                        decoration: InputDecoration(
                          labelText: 'No Faktur',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null,
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
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _totalHargaController,
                        decoration: InputDecoration(
                          labelText: 'Total Harga (Rp)',
                          border: OutlineInputBorder(),
                          prefixText: 'Rp ',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null,
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
                      SizedBox(height: 24),
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
            ),
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
