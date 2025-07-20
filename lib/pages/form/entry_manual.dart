import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class EntryManualPage extends StatefulWidget {
  @override
  _EntryManualPageState createState() => _EntryManualPageState();
}

class _EntryManualPageState extends State<EntryManualPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _distributors = [];

  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _selectedDistributor;

  final _batchController = TextEditingController();
  final _expController = TextEditingController();
  final _qtyController = TextEditingController();
  final _fakturController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _catatanController = TextEditingController();
  final _hargaController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitData();
  }

  Future<void> _loadInitData() async {
    setState(() => _isLoading = true);
    final prodRes = await supabase
        .from('products')
        .select('id,nama_produk,produsen');
    final distRes = await supabase.from('distributors').select('id,nama');
    setState(() {
      _products = List<Map<String, dynamic>>.from(prodRes);
      _distributors = List<Map<String, dynamic>>.from(distRes);
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
            'tanggal': DateFormat('yyyy-MM-dd')
                .parse(_tanggalController.text)
                .toIso8601String(), // ✅ ubah ke string ISO
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
            'exp': DateFormat('yyyy-MM-dd')
                .parse(_expController.text)
                .toIso8601String(), // ✅ ubah ke string ISO
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
        ).parse(_expController.text).toIso8601String(), // ✅ ubah ke string ISO
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Entry Batch Produk Masuk'),
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
                      value: _selectedProduct,
                      items: _products.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text('${p['nama_produk']} – ${p['produsen']}'),
                        );
                      }).toList(),
                      decoration: InputDecoration(
                        labelText: 'Pilih Produk',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null) return 'Produk wajib dipilih';
                        return null;
                      },
                      onChanged: (v) => setState(() => _selectedProduct = v),
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
                      validator: (v) {
                        if (v == null) return 'Distributor wajib dipilih';
                        return null;
                      },
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
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Kode batch wajib diisi';
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _expController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Tanggal Expired',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Tanggal expired wajib diisi';
                        return null;
                      },
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
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _qtyController,
                      decoration: InputDecoration(
                        labelText: 'Qty Masuk',
                        border: OutlineInputBorder(),
                        suffixText: 'pcs',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Qty wajib diisi';
                        if (int.tryParse(v) == null)
                          return 'Qty harus berupa angka';
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _hargaController,
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
                          return 'Total harga harus berupa angka';
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _fakturController,
                      decoration: InputDecoration(
                        labelText: 'No Faktur',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'No faktur wajib diisi';
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _tanggalController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Tanggal Masuk',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Tanggal masuk wajib diisi';
                        return null;
                      },
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
    );
  }
}
