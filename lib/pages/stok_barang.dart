import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StokBarangPage extends StatefulWidget {
  @override
  _StokBarangPageState createState() => _StokBarangPageState();
}

class _StokBarangPageState extends State<StokBarangPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> inventoryItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  bool _isLoading = true;
  String searchText = '';
  String selectedSort = 'Nama (A-Z)';

  @override
  void initState() {
    super.initState();
    fetchStokBarang();
  }

  Future<void> fetchStokBarang() async {
    final batches = await supabase
        .from('product_batches')
        .select(
          'qty_sisa, qty_masuk, qty_keluar, batch_code, exp, products(nama_produk, satuan)',
        )
        .filter('deleted_at', 'is', null);

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
        'expired_at': batch['exp'],
      });
    }

    setState(() {
      inventoryItems = listItems;
      applyFilter();
      _isLoading = false;
    });
  }

  void applyFilter() {
    List<Map<String, dynamic>> temp = inventoryItems.where((item) {
      final name = item['name']?.toLowerCase() ?? '';
      final stock = item['stock'].toString();
      return name.contains(searchText.toLowerCase()) ||
          stock.contains(searchText);
    }).toList();

    switch (selectedSort) {
      case 'Nama (A-Z)':
        temp.sort((a, b) => a['name'].compareTo(b['name']));
        break;
      case 'Sisa Terbanyak':
        temp.sort((a, b) => b['stock'].compareTo(a['stock']));
        break;
      case 'Sisa Terkecil':
        temp.sort((a, b) => a['stock'].compareTo(b['stock']));
        break;
      case 'Expired Terdekat':
        temp.sort(
          (a, b) => DateTime.parse(
            a['expired_at'] ?? '2100-01-01',
          ).compareTo(DateTime.parse(b['expired_at'] ?? '2100-01-01')),
        );
        break;
      case 'Expired Terjauh':
        temp.sort(
          (a, b) => DateTime.parse(
            b['expired_at'] ?? '1900-01-01',
          ).compareTo(DateTime.parse(a['expired_at'] ?? '1900-01-01')),
        );
        break;
    }

    setState(() {
      filteredItems = temp;
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
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Cari produk atau stok...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          searchText = value;
                          applyFilter();
                        },
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Text("Urutkan: "),
                          SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSort,
                              items:
                                  [
                                    'Nama (A-Z)',
                                    'Sisa Terbanyak',
                                    'Sisa Terkecil',
                                    'Expired Terdekat',
                                    'Expired Terjauh',
                                  ].map((label) {
                                    return DropdownMenuItem(
                                      value: label,
                                      child: Text(label),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  selectedSort = value;
                                  applyFilter();
                                }
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(child: Text('Tidak ada data'))
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _buildInventoryCard(item);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final int stock = item['stock'];
    final int total = item['total'];
    final double progress = total > 0 ? stock / total : 0;
    final expiredDate = item['expired_at'];
    final formattedDate = expiredDate != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(expiredDate))
        : '-';

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
                '$stock ${item['unit']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text('Kode Batch: ${item['code']}'),
          SizedBox(height: 4),
          Text('Expired: $formattedDate'),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF03A6A1)),
          ),
        ],
      ),
    );
  }
}
