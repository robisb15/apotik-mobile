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
  List<Map<String, dynamic>> _productOutEntries = [];

  final _fakturController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _tujuanController = TextEditingController(text: '');
  final _catatanController = TextEditingController();

  int _totalKeseluruhan = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _addProductOutEntry();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    final res = await supabase.from('product_batches').select('''
      id, batch_code, exp, product_id, 
      products(nama_produk, barcode, produsen, harga_jual), 
      qty_sisa, qty_masuk, qty_keluar
    ''');

    setState(() {
      _batches = List<Map<String, dynamic>>.from(res);
      _isLoading = false;
    });
  }

  void _addProductOutEntry() {
    setState(() {
      _productOutEntries.add({
        'selectedBatch': null,
        'qtyController': TextEditingController(),
        'hargaJual': 0,
        'subtotal': 0,
      });
    });
  }

  void _removeProductOutEntry(int index) {
    setState(() {
      _productOutEntries.removeAt(index);
      _updateTotalHarga();
    });
  }

  void _updateTotalHarga() {
    int total = 0;
    for (final item in _productOutEntries) {
      final qtyText = item['qtyController'].text;
      final qty = int.tryParse(qtyText) ?? 0;
      final harga = item['hargaJual'] ?? 0;
      item['subtotal'] = (qty * harga).toInt();
      total += item['subtotal'] as int;
    }
    setState(() {
      _totalKeseluruhan = total;
    });
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pastikan semua input diisi dengan benar')),
      );
      return;
    }

    if (_productOutEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Minimal satu produk harus ditambahkan')),
      );
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      _updateTotalHarga();

      final outgoing = await supabase
          .from('outgoings')
          .insert({
            'no_faktur': _fakturController.text,
            'tanggal': _tanggalController.text,
            'tujuan': _tujuanController.text,
            'user_id': user.id,
            'total_harga': _totalKeseluruhan,
            'catatan': _catatanController.text,
          })
          .select()
          .single();

      for (final item in _productOutEntries) {
        final batch = item['selectedBatch'];
        final qty = int.parse(item['qtyController'].text);
        final harga = item['hargaJual'] ?? 0;
        final subtotal = qty * harga;

        await supabase.from('outgoing_details').insert({
          'outgoing_id': outgoing['id'],
          'product_batch_id': batch['id'],
          'qty_keluar': qty,
          'subtotal': subtotal,
        });

        final batchData = await supabase
            .from('product_batches')
            .select('qty_masuk, qty_keluar')
            .eq('id', batch['id'])
            .single();

        final qtyMasuk = batchData['qty_masuk'] ?? 0;
        final qtyKeluarLama = batchData['qty_keluar'] ?? 0;
        final qtyKeluarBaru = qtyKeluarLama + qty;
        final qtySisaBaru = qtyMasuk - qtyKeluarBaru;

        await supabase
            .from('product_batches')
            .update({'qty_keluar': qtyKeluarBaru, 'qty_sisa': qtySisaBaru})
            .eq('id', batch['id']);
      }

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
                    TextFormField(
                      controller: _fakturController,
                      decoration: InputDecoration(
                        labelText: 'No Faktur',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib isi faktur' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _tanggalController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Tanggal',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          _tanggalController.text = DateFormat(
                            'yyyy-MM-dd',
                          ).format(picked);
                        }
                      },
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib isi tanggal' : null,
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _tujuanController.text.isNotEmpty
                          ? _tujuanController.text
                          : null,
                      items: const [
                        DropdownMenuItem(value: 'Resep', child: Text('Resep')),
                        DropdownMenuItem(
                          value: 'Swamedikasi',
                          child: Text('Swamedikasi'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _tujuanController.text = value ?? '');
                      },
                      decoration: InputDecoration(
                        labelText: 'Tujuan',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Wajib pilih tujuan'
                          : null,
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
                    Text(
                      'Produk yang Dikeluarkan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ..._productOutEntries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildProductOutEntry(item, index);
                    }),
                    SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total: Rp $_totalKeseluruhan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _addProductOutEntry,
                      icon: Icon(Icons.add),
                      label: Text('Tambah Produk'),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveAll,
                      child: Text('Simpan Semua'),
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

  Widget _buildProductOutEntry(Map<String, dynamic> item, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Autocomplete<Map<String, dynamic>>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            // Tampilkan semua saat field kosong
            return _batches.where((batch) {
              final product = batch['products'];
              final nama = product['nama_produk']?.toLowerCase() ?? '';
              final batchCode = batch['batch_code']?.toLowerCase() ?? '';
              final search = textEditingValue.text.toLowerCase();
              return nama.contains(search) || batchCode.contains(search);
            });
          },
          displayStringForOption: (option) {
            final product = option['products'];
            return '${option['batch_code']} - ${product['nama_produk']}';
          },
          onSelected: (value) {
            setState(() {
              item['selectedBatch'] = value;
              item['hargaJual'] = value['products']['harga_jual'] ?? 0;
              _updateTotalHarga();
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            // Trik: trigger suggestion saat field di-tap
            return Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus && controller.text.isEmpty) {
                  controller.text = ' '; // trigger optionsBuilder
                  controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: controller.text.length),
                  );
                }
              },
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Pilih Batch',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    item['selectedBatch'] == null ? 'Wajib pilih batch' : null,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    final product = option['products'];
                    return ListTile(
                      title: Text(
                        '${option['batch_code']} - ${product['nama_produk']}',
                      ),
                      subtitle: Text(
                        'Exp: ${option['exp']}, Sisa: ${option['qty_sisa']}',
                      ),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            );
          },
        ),

        SizedBox(height: 8),
        TextFormField(
          controller: item['qtyController'],
          decoration: InputDecoration(
            labelText: 'Qty Keluar',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => _updateTotalHarga(),
          validator: (v) =>
              (v == null || int.tryParse(v) == null) ? 'Harus angka' : null,
        ),
        SizedBox(height: 8),
        Text('Subtotal: Rp ${item['subtotal']}'),
        SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _removeProductOutEntry(index),
            icon: Icon(Icons.delete, color: Colors.red),
            label: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ),
        Divider(),
      ],
    );
  }

  @override
  void dispose() {
    _fakturController.dispose();
    _tanggalController.dispose();
    _tujuanController.dispose();
    _catatanController.dispose();
    for (final item in _productOutEntries) {
      item['qtyController'].dispose();
    }
    super.dispose();
  }
}
