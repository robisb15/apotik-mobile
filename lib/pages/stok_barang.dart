// File: stok_barang_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StokBarangPage extends StatefulWidget {
  @override
  _StokBarangPageState createState() => _StokBarangPageState();
}

class _StokBarangPageState extends State<StokBarangPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> inventoryItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStokBarang();
  }

  Future<void> fetchStokBarang() async {
    final batches = await supabase
        .from('product_batches')
        .select(
          'qty_sisa, qty_masuk, qty_keluar, batch_code, products(nama_produk, satuan)',
        ).filter('deleted_at','is',null);

    List<Map<String, dynamic>> listItems = [];

    for (final batch in batches) {
      final product = batch['products'] ?? {};
      final qtySisa = (batch['qty_sisa'] as num?)?.toInt() ?? 0;
      final qtyMasuk = (batch['qty_masuk'] as num?)?.toInt() ?? 0;

      listItems.add({
        'name': product['nama_produk'] ?? 'Tanpa Nama',
        'code': batch['batch_code'],
        'stock': qtySisa,
        'incoming': qtyMasuk,
        'total': qtyMasuk,
        'unit': product['satuan'] ?? '',
      });
    }

    setState(() {
      inventoryItems = listItems;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daftar Stok Barang'),
        backgroundColor: Color(0xFF03A6A1),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: inventoryItems.length,
              itemBuilder: (context, index) {
                final item = inventoryItems[index];
                return _buildInventoryCard(item);
              },
            ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.medical_services, color: Color(0xFF03A6A1)),
                  SizedBox(width: 8),
                  Text(
                    item['name'],
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                '${item['stock']} ${item['unit']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text('Kode Batch: ${item['code']}'),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: item['stock'] / (item['total'] + 0.001),
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF03A6A1)),
          ),
        ],
      ),
    );
  }
}
