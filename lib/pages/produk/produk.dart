import 'package:flutter/material.dart';

class ProductPage extends StatefulWidget {
  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final List<Map<String, dynamic>> _products = [
    {
      'id': 'OBT-001',
      'name': 'Paracetamol 500mg',
      'category': 'Analgesik',
      'stock': 150,
      'price': 5000,
      'expiry': '12/2024',
      'image': 'assets/pills.png',
    },
    {
      'id': 'OBT-002',
      'name': 'Amoxicillin 500mg',
      'category': 'Antibiotik',
      'stock': 80,
      'price': 12000,
      'expiry': '10/2024',
      'image': 'assets/capsule.png',
    },
    // Tambahkan produk lainnya di sini...
  ];

  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((product) {
      final matchesSearch = product['name']
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'Semua' || product['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    final categories = ['Semua', ..._products.map((p) => p['category']).toSet().toList()];

    return Scaffold(
      appBar: AppBar(
        title: Text('Daftar Produk'),
        centerTitle: true,
        backgroundColor: Color(0xFF03A6A1),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showAddProductDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari produk...',
                    prefixIcon: Icon(Icons.search, color: Color(0xFF03A6A1)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          selectedColor: Color(0xFF03A6A1),
                          labelStyle: TextStyle(
                            color: _selectedCategory == category
                                ? Colors.white
                                : Colors.black,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : 'Semua';
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                return _buildProductCard(context, product);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProductDialog(context),
        backgroundColor: Color(0xFF03A6A1),
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {}, // Tambahkan logika detail jika diperlukan
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Color(0xFF03A6A1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.medical_services, color: Color(0xFF03A6A1)),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'],
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text('Kode: ${product['id']}',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.inventory, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('Stok: ${product['stock']}', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 16),
                        Icon(Icons.price_change, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('Rp ${product['price']}', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  'Exp: ${product['expiry']}',
                  style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tambah Produk Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: InputDecoration(labelText: 'Nama Produk')),
              TextField(decoration: InputDecoration(labelText: 'Kode Produk')),
              TextField(decoration: InputDecoration(labelText: 'Kategori')),
              TextField(
                decoration: InputDecoration(labelText: 'Stok'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Harga'),
                keyboardType: TextInputType.number,
              ),
              TextField(decoration: InputDecoration(labelText: 'Kadaluarsa (MM/YYYY)')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF03A6A1)),
            child: Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
