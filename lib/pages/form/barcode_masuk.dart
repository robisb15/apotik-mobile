// File: entry_manual_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanBarcodePage extends StatefulWidget {
  @override
  _ScanBarcodePageState createState() => _ScanBarcodePageState();
}

class _ScanBarcodePageState extends State<ScanBarcodePage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _selectedDistributor;

  final _batchController = TextEditingController();
  final _expController = TextEditingController();
  final _qtyController = TextEditingController();
  final _fakturController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _catatanController = TextEditingController();
  final _hargaController = TextEditingController();

  bool _isLoading = false;
  bool _scannerVisible = true;
  String? _barcodeData;
  List<Map<String, dynamic>> _distributors = [];

  @override
  void initState() {
    super.initState();
    _loadDistributors();
  }

  Future<void> _loadDistributors() async {
    final distRes = await supabase.from('distributors').select('id,nama');
    setState(() {
      _distributors = List<Map<String, dynamic>>.from(distRes);
    });
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    setState(() => _isLoading = true);
    final res = await supabase
        .from('products')
        .select('id,nama_produk,produsen,harga_jual,satuan,barcode')
        .eq('barcode', barcode)
        .limit(1)
        .maybeSingle();
    print('Barcode Detected: $barcode');
    setState(() {
      _scannerVisible = false;
      _barcodeData = barcode;
      _selectedProduct = res;
      _isLoading = false;
    });
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate() ||
        _selectedProduct == null ||
        _selectedDistributor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pastikan semua data diisi dengan benar')),
      );
      return;
    }

    try {
      final receipt = await supabase
          .from('receipts')
          .insert({
            'tanggal': DateFormat(
              'yyyy-MM-dd',
            ).parse(_tanggalController.text).toIso8601String(),
            'no_faktur': _fakturController.text,
            'total_harga': int.parse(_hargaController.text.replaceAll('.', '')),
            'catatan': _catatanController.text,
          })
          .select()
          .single();

      final batch = await supabase
          .from('product_batches')
          .insert({
            'product_id': _selectedProduct!['id'],
            'distributor_id': _selectedDistributor!['id'],
            'batch_code': _batchController.text,
            'exp': DateFormat(
              'yyyy-MM-dd',
            ).parse(_expController.text).toIso8601String(),
            'qty_masuk': int.parse(_qtyController.text),
            'qty_keluar': 0,
            'qty_sisa': int.parse(_qtyController.text),
          })
          .select()
          .single();

      await supabase.from('receipt_details').insert({
        'receipt_id': receipt['id'],
        'product_id': _selectedProduct!['id'],
        'distributor_id': _selectedDistributor!['id'],
        'exp': DateFormat(
          'yyyy-MM-dd',
        ).parse(_expController.text).toIso8601String(),
        'qty_diterima': int.parse(_qtyController.text),
        'batch_code': _batchController.text,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Data berhasil disimpan')));
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  void _resetForm() {
    setState(() {
      _selectedProduct = null;
      _selectedDistributor = null;
      _batchController.clear();
      _expController.clear();
      _qtyController.clear();
      _fakturController.clear();
      _tanggalController.clear();
      _catatanController.clear();
      _hargaController.clear();
      _scannerVisible = true;
      _barcodeData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Entry Batch Produk Masuk'),
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
                    onDetect: (barcodeCapture) {
                      final code =
                          barcodeCapture.barcodes.firstOrNull?.rawValue;
                      if (code != null) _onBarcodeDetected(code);
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
              onPressed: _resetForm,
              icon: Icon(Icons.refresh),
              label: Text('Scan Ulang'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          if (!_scannerVisible)
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        '${_selectedProduct?['nama_produk'] ?? 'Produk Tidak Diketahui'} – ${_selectedProduct?['produsen'] ?? ''}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Barcode : ${_selectedProduct?['barcode'] ?? 'Produk Tidak Diketahui'}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Rp${_selectedProduct?['harga_jual'] ?? '-'} / ${_selectedProduct?['satuan'] ?? ''}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      SizedBox(height: 16),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedDistributor,
                        items: _distributors.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text(d['nama']),
                          );
                        }).toList(),
                        decoration: InputDecoration(
                          labelText: 'Distributor',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null ? 'Wajib dipilih' : null,
                        onChanged: (v) =>
                            setState(() => _selectedDistributor = v),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _batchController,
                        decoration: InputDecoration(
                          labelText: 'Kode Batch',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _expController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Tanggal Expired',
                          border: OutlineInputBorder(),
                        ),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2035),
                          );
                          if (d != null)
                            _expController.text = DateFormat(
                              'yyyy-MM-dd',
                            ).format(d);
                        },
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _qtyController,
                        decoration: InputDecoration(
                          labelText: 'Qty Masuk',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _hargaController,
                        decoration: InputDecoration(
                          labelText: 'Total Harga',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
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
                          labelText: 'Tanggal Masuk',
                          border: OutlineInputBorder(),
                        ),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2035),
                          );
                          if (d != null)
                            _tanggalController.text = DateFormat(
                              'yyyy-MM-dd',
                            ).format(d);
                        },
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
                        onPressed: _saveAll,
                        child: Text('Simpan Semua Data'),
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
}
