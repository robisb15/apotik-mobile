import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScanBarangKeluarPage extends StatefulWidget {
  @override
  _ScanBarangKeluarPageState createState() => _ScanBarangKeluarPageState();
}

class _ScanBarangKeluarPageState extends State<ScanBarangKeluarPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _fakturController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _tujuanController = TextEditingController();
  final _catatanController = TextEditingController();

  List<Map<String, dynamic>> _scannedItems = [];
  int _totalKeseluruhan = 0;

  String? _selectedTujuan;

  @override
  void initState() {
    super.initState();
    _selectedTujuan = _tujuanController.text.isNotEmpty
        ? _tujuanController.text
        : null;
  }

  Future<void> _scanBarcode() async {
    final result = await BarcodeScanner.scan();
    final barcode = result.rawContent;

    if (barcode.isEmpty) return;

    final product = await supabase
        .from('products')
        .select('id')
        .eq('barcode', barcode)
        .limit(1)
        .maybeSingle();

    if (product != null) {
      final batch = await supabase
          .from('product_batches')
          .select('''
            id, batch_code, exp, qty_sisa, qty_masuk, product_id,
            products(id, nama_produk, barcode, harga_jual)
          ''')
          .eq('product_id', product['id'])
          .limit(1)
          .maybeSingle();

      if (batch == null || batch['products'] == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Produk tidak ditemukan')));
        return;
      }

      setState(() {
        _scannedItems.add({
          'batch': batch,
          'qtyController': TextEditingController(),
          'subtotal': 0,
        });
      });
    }
  }

  void _updateTotal() {
    int total = 0;
    for (final item in _scannedItems) {
      final qty = int.tryParse(item['qtyController'].text) ?? 0;
      final harga = (item['batch']['products']['harga_jual'] ?? 0) as num;
      item['subtotal'] = (qty * harga).toInt();
      total += (item['subtotal'] as num).toInt();
    }
    setState(() {
      _totalKeseluruhan = total;
    });
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate() || _scannedItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lengkapi data terlebih dahulu')));
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      _updateTotal();

      final outgoing = await supabase
          .from('outgoings')
          .insert({
            'no_faktur': _fakturController.text,
            'tanggal': _tanggalController.text,
            'tujuan': _selectedTujuan,
            'catatan': _catatanController.text,
            'total_harga': _totalKeseluruhan,
            'user_id': user.id,
          })
          .select()
          .single();

      for (final item in _scannedItems) {
        final batch = item['batch'];
        final qty = int.parse(item['qtyController'].text);
        final subtotal = item['subtotal'];

        await supabase.from('outgoing_details').insert({
          'outgoing_id': outgoing['id'],
          'product_batch_id': batch['id'],
          'qty_keluar': qty,
          'subtotal': subtotal,
        });

        final qtyBaru = batch['qty_sisa'] - qty;
        await supabase
            .from('product_batches')
            .update({
              'qty_keluar': batch['qty_masuk'] - qtyBaru,
              'qty_sisa': qtyBaru,
            })
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
        title: Text('Scan Barang Keluar'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanBarcode,
        child: Icon(Icons.qr_code_scanner),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_fakturController, 'No Faktur', true),
              SizedBox(height: 16),
              TextFormField(
                controller: _tanggalController,
                readOnly: true,
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
                decoration: InputDecoration(
                  labelText: 'Tanggal',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Wajib isi tanggal' : null,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTujuan,
                decoration: InputDecoration(
                  labelText: 'Tujuan',
                  border: OutlineInputBorder(),
                ),
                items: ['Resep', 'Swamedikasi']
                    .map(
                      (tujuan) =>
                          DropdownMenuItem(value: tujuan, child: Text(tujuan)),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedTujuan = val;
                    _tujuanController.text = val ?? '';
                  });
                },
                validator: (val) =>
                    val == null || val.isEmpty ? 'Wajib pilih tujuan' : null,
              ),
              SizedBox(height: 16),
              _buildTextField(_catatanController, 'Catatan', false),
              SizedBox(height: 16),
              ..._scannedItems.map((item) => _buildScannedItem(item)).toList(),
              SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: Rp $_totalKeseluruhan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveAll,
                child: Text('Simpan Semua'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48),
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
    String label,
    bool isRequired,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      validator: (v) =>
          (isRequired && (v == null || v.isEmpty)) ? 'Wajib diisi' : null,
    );
  }

  Widget _buildScannedItem(Map<String, dynamic> item) {
    final batch = item['batch'];
    final product = batch['products'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text('Produk: ${product['nama_produk']} (${batch['batch_code']})'),
        SizedBox(height: 8),
        Text('Expired: ${batch['exp']}'),
        SizedBox(height: 8),
        Text('Stok Tersedia: ${batch['qty_sisa']}'),
        SizedBox(height: 8),
        TextFormField(
          controller: item['qtyController'],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Qty Keluar',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _updateTotal(),
          validator: (v) =>
              v == null || int.tryParse(v) == null ? 'Harus angka' : null,
        ),
        SizedBox(height: 8),
        Text('Subtotal: Rp ${item['subtotal']}'),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _scannedItems.remove(item);
                _updateTotal();
              });
            },
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
    for (final item in _scannedItems) {
      item['qtyController'].dispose();
    }
    super.dispose();
  }
}
