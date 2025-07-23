// Pastikan import-nya ini ya
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
  List<Map<String, dynamic>> _productEntries = [];

  final _fakturController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _catatanController = TextEditingController();

  Map<String, dynamic>? _selectedDistributor;
  int _totalKeseluruhan = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitData();
    _addProductEntry(); // Tambah 1 entri default
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

  void _addProductEntry() {
    setState(() {
      _productEntries.add({
        'selectedProduct': null,
        'batchController': TextEditingController(),
        'expController': TextEditingController(),
        'qtyController': TextEditingController(),
        'subtotalController': TextEditingController(),
        'subtotal': 0,
      });
    });
  }

  void _removeProductEntry(int index) {
    setState(() {
      _productEntries.removeAt(index);
      _updateTotalKeseluruhan();
    });
  }

  void _updateTotalKeseluruhan() {
    int total = 0;
    for (final item in _productEntries) {
      final subtotalText = item['subtotalController'].text;
      final subtotal = int.tryParse(subtotalText) ?? 0;
      item['subtotal'] = subtotal;
      total += subtotal;
    }
    setState(() {
      _totalKeseluruhan = total;
    });
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate() || _selectedDistributor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pastikan semua input diisi dengan benar')),
      );
      return;
    }

    if (_productEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Minimal satu produk harus ditambahkan')),
      );
      return;
    }

    try {
      _updateTotalKeseluruhan();
      final receipt = await supabase
          .from('receipts')
          .insert({
            'tanggal': DateFormat(
              'yyyy-MM-dd',
            ).parse(_tanggalController.text).toIso8601String(),
            'no_faktur': _fakturController.text,
            'total_harga': _totalKeseluruhan,
            'catatan': _catatanController.text,
          })
          .select()
          .single();

      for (final item in _productEntries) {
        final batch = await supabase
            .from('product_batches')
            .insert({
              'product_id': item['selectedProduct']['id'],
              'distributor_id': _selectedDistributor!['id'],
              'batch_code': item['batchController'].text,
              'exp': DateFormat(
                'yyyy-MM-dd',
              ).parse(item['expController'].text).toIso8601String(),
              'qty_masuk': int.parse(item['qtyController'].text),
              'qty_keluar': 0,
              'qty_sisa': int.parse(item['qtyController'].text),
            })
            .select()
            .single();

        await supabase.from('receipt_details').insert({
          'receipt_id': receipt['id'],
          'product_batch_id': batch['id'],
          'distributor_id': _selectedDistributor!['id'],
          'exp': DateFormat(
            'yyyy-MM-dd',
          ).parse(item['expController'].text).toIso8601String(),
          'qty_diterima': int.parse(item['qtyController'].text),
          'batch_code': item['batchController'].text,
          'subtotal': item['subtotal'],
        });
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
                    _buildTextField(_fakturController, 'No Faktur'),
                    SizedBox(height: 16),
                    _buildDateField(_tanggalController, 'Tanggal Masuk'),
                    SizedBox(height: 16),
                    _buildDistributorField(),
                    SizedBox(height: 16),
                    _buildTextField(_catatanController, 'Catatan', maxLines: 2),
                    SizedBox(height: 24),
                    Text(
                      'Produk Masuk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ..._productEntries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Column(
                        children: [
                          SizedBox(height: 16),
                          _buildProductEntry(item),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _removeProductEntry(index),
                              icon: Icon(Icons.delete, color: Colors.red),
                              label: Text(
                                'Hapus',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                          Divider(),
                        ],
                      );
                    }),
                    SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total Keseluruhan: Rp $_totalKeseluruhan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _addProductEntry,
                      icon: Icon(Icons.add),
                      label: Text('Tambah Produk'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                      ),
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

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Wajib isi $label' : null,
      maxLines: maxLines,
    );
  }

  Widget _buildDateField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Wajib isi tanggal' : null,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2023),
          lastDate: DateTime(2035),
        );
        if (date != null)
          controller.text = DateFormat('yyyy-MM-dd').format(date);
      },
    );
  }

  Widget _buildDistributorField() {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        return _distributors.where(
          (d) => d['nama'].toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          ),
        );
      },
      displayStringForOption: (option) => option['nama'],
      onSelected: (value) => setState(() => _selectedDistributor = value),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Distributor',
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              _selectedDistributor == null ? 'Wajib pilih distributor' : null,
        );
      },
    );
  }

  Widget _buildProductEntry(Map<String, dynamic> item) {
    return Column(
      children: [
        Autocomplete<Map<String, dynamic>>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            return _products.where(
              (p) => p['nama_produk'].toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              ),
            );
          },
          displayStringForOption: (option) => option['nama_produk'],
          onSelected: (value) =>
              setState(() => item['selectedProduct'] = value),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Pilih Produk',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  item['selectedProduct'] == null ? 'Wajib pilih produk' : null,
            );
          },
        ),
        SizedBox(height: 8),
        _buildTextField(item['batchController'], 'Kode Batch'),
        SizedBox(height: 8),
        TextFormField(
          controller: item['qtyController'],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Qty Masuk',
            border: OutlineInputBorder(),
            suffixText: 'pcs',
          ),
          validator: (v) =>
              v == null || int.tryParse(v) == null ? 'Qty harus angka' : null,
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: item['subtotalController'],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Subtotal (Rp)',
            border: OutlineInputBorder(),
            prefixText: 'Rp ',
          ),
          onChanged: (_) => _updateTotalKeseluruhan(),
          validator: (v) => v == null || int.tryParse(v) == null
              ? 'Subtotal harus angka'
              : null,
        ),
        SizedBox(height: 8),
        _buildDateField(item['expController'], 'Tanggal Expired'),
      ],
    );
  }
}
