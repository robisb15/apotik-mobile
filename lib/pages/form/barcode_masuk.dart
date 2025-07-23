import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EntryScanBarcodePage extends StatefulWidget {
  @override
  _EntryScanBarcodePageState createState() => _EntryScanBarcodePageState();
}

class _EntryScanBarcodePageState extends State<EntryScanBarcodePage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _fakturController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _catatanController = TextEditingController();

  List<Map<String, dynamic>> _distributors = [];
  Map<String, dynamic>? _selectedDistributor;

  List<Map<String, dynamic>> _scannedProducts = [];
  int _totalKeseluruhan = 0;

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

  Future<void> _scanBarcode() async {
    final result = await BarcodeScanner.scan();
    final barcode = result.rawContent;

    if (barcode.isNotEmpty) {
      final product = await supabase
          .from('products')
          .select()
          .eq('barcode', barcode)
          .maybeSingle();

      if (product != null) {
        setState(() {
          _scannedProducts.add({
            'product': product,
            'batchController': TextEditingController(),
            'expController': TextEditingController(),
            'qtyController': TextEditingController(),
            'subtotalController': TextEditingController(),
            'subtotal': 0,
          });
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk tidak ditemukan untuk barcode $barcode'),
          ),
        );
      }
    }
  }

  void _updateTotalKeseluruhan() {
    int total = 0;
    for (final item in _scannedProducts) {
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
    if (!_formKey.currentState!.validate() ||
        _selectedDistributor == null ||
        _scannedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lengkapi data dan tambahkan produk terlebih dahulu'),
        ),
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

      for (final item in _scannedProducts) {
        final product = item['product'];
        final batch = await supabase
            .from('product_batches')
            .insert({
              'product_id': product['id'],
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
        title: Text('Scan Barcode Produk Masuk'),
        backgroundColor: Colors.teal,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanBarcode,
        child: Icon(Icons.qr_code_scanner),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
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
                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _tanggalController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Tanggal Masuk',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2035),
                  );
                  if (date != null) {
                    _tanggalController.text = DateFormat(
                      'yyyy-MM-dd',
                    ).format(date);
                  }
                },
              ),
              SizedBox(height: 16),
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (text) => _distributors.where(
                  (d) =>
                      d['nama'].toLowerCase().contains(text.text.toLowerCase()),
                ),
                displayStringForOption: (d) => d['nama'],
                onSelected: (d) => setState(() => _selectedDistributor = d),
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Distributor',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            _selectedDistributor == null ? 'Wajib pilih' : null,
                      );
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
              ..._scannedProducts.map((item) {
                final product = item['product'];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Produk: ${product['nama_produk']}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: item['batchController'],
                      decoration: InputDecoration(
                        labelText: 'Kode Batch',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: item['qtyController'],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Qty',
                        suffixText: 'pcs',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || int.tryParse(v) == null
                          ? 'Wajib angka'
                          : null,
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: item['subtotalController'],
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updateTotalKeseluruhan(),
                      decoration: InputDecoration(
                        labelText: 'Subtotal (Rp)',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || int.tryParse(v) == null
                          ? 'Harus angka'
                          : null,
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: item['expController'],
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Tanggal Expired',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib isi' : null,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2035),
                        );
                        if (date != null) {
                          item['expController'].text = DateFormat(
                            'yyyy-MM-dd',
                          ).format(date);
                        }
                      },
                    ),
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _scannedProducts.remove(item);
                            _updateTotalKeseluruhan();
                          });
                        },
                        icon: Icon(Icons.delete, color: Colors.red),
                        label: Text(
                          'Hapus',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    Divider(thickness: 1.5),
                  ],
                );
              }).toList(),
              SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total Keseluruhan: Rp $_totalKeseluruhan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveAll,
                child: Text('Simpan Semua Data'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                  backgroundColor: Colors.teal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
