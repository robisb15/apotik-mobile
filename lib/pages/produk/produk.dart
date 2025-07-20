import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class ProductPage extends StatefulWidget {
  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _subKategori = [];
  List<Map<String, dynamic>> _kategori = [];
  bool _isLoading = true;
  String _getKategoriName(int? subKategoriId) {
    final sub = _subKategori.firstWhere(
      (s) => s['id'] == subKategoriId,
      orElse: () => {},
    );
    if (sub.isEmpty) return '-';
    final kategoriId = sub['kategori_id'];
    final kategori = _kategori.firstWhere(
      (k) => k['id'] == kategoriId,
      orElse: () => {},
    );
    return kategori['nama'] ?? '-';
  }

  String _getSubKategoriName(int? id) {
    final found = _subKategori.firstWhere(
      (s) => s['id'] == id,
      orElse: () => {},
    );
    return found['nama'] ?? '-';
  }

  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedManufacturer;
  bool _hasScanned = false;
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.delayed(300.ms);

    try {
      final productsRes = await supabase.from('products').select();
      final kategoriRes = await supabase.from('kategori').select('id, nama');
      final subKategoriRes = await supabase
          .from('sub_kategori')
          .select('id, nama, kategori_id'); // tambahkan kategori_id

      setState(() {
        _products = List<Map<String, dynamic>>.from(productsRes);
        _subKategori = List<Map<String, dynamic>>.from(subKategoriRes);
        _selectedCategory = null;
        _selectedManufacturer = null;
        _kategori = List<Map<String, dynamic>>.from(kategoriRes);
      });
    } catch (e) {
      print('Error fetching data: $e');
      _showErrorSnackbar('Gagal memuat data');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<String> get _categories {
    final categories = _products
        .map((p) => p['tag']?.toString())
        .where((e) => e != null && e.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return categories.whereType<String>().toList();
  }

  

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((product) {
      final name = (product['nama_produk'] ?? '').toString().toLowerCase();
      final category = (product['tag'] ?? '').toString().toLowerCase();
      

      final matchesSearch = name.contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == null ||
          category == _selectedCategory!.toLowerCase();
    

      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Manajemen Produk'),
        backgroundColor: Color(0xFF03A6A1),
        centerTitle: true,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : Column(
              children: [
                _buildSearchFilterCard(),
                SizedBox(height: 8),
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? _buildEmptyState()
                      : _buildProductList(),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Color(0xFF03A6A1)),
          ),
          SizedBox(height: 16),
          Text('Memuat data...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSearchFilterCard() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari produk...',
                      prefixIcon: Icon(Icons.search, color: Color(0xFF03A6A1)),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (_) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Entry Manual'),
                            onTap: () {
                              Navigator.pop(context);
                              _showAddProductDialog(context);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.qr_code_scanner),
                            title: Text('Scan Barcode'),
                            onTap: () {
                              Navigator.pop(context);
                              _scanBarcodeAndOpenForm(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF03A6A1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.all(12),
                  ),
                  child: Icon(Icons.add, color: Colors.white),
                ).animate().scale(duration: 300.ms),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedCategory,
                    items: _categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                  ),
                ),
               
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Tidak ada produk ditemukan',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 8),
          TextButton(
            onPressed: () => _showAddProductDialog(context),
            child: Text('Tambah Produk'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return ListView.builder(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return Card(
              margin: EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFF03A6A1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF03A6A1),
                  ),
                ),
                title: Text(
                  product['nama_produk'] ?? '-',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                 
                   

                    Text(
                      'Kategori: ${_getKategoriName(product['sub_kategori_id'])}',
                    ),
                    Text(
                      'Sub Kategori: ${_getSubKategoriName(product['sub_kategori_id'])}',
                    ),
                    Text('Barcode: ${product['barcode'] ?? '-'}'),
                    Text(
                      'Harga: Rp${NumberFormat('#,###', 'id_ID').format(product['harga_jual'] ?? 0)} / ${product['satuan'] ?? '-'}',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAddProductDialog(context, existingProduct: product);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                  ],
                ),
              ),
            )
            .animate()
            .fadeIn(delay: (100 * index).ms)
            .slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
      },
    );
  }

  // 📦 Barcode Scanner Trigger
  void _scanBarcodeAndOpenForm(BuildContext context) {
    _hasScanned = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: SizedBox(
          width: 300,
          height: 400,
          child: Column(
            children: [
              Text(
                'Pindai Barcode',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (barcodeCapture) {
                    if (_hasScanned) return;
                    _hasScanned = true;
                    final String? code = barcodeCapture.barcodes.first.rawValue;
                    if (code != null) {
                      Navigator.pop(context);
                      _showAddProductDialog(context, scannedBarcode: code);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📝 Dialog Tambah Produk
  void _showAddProductDialog(
    BuildContext context, {
    String? scannedBarcode,
    Map<String, dynamic>? existingProduct,
  }) {
    final _formKey = GlobalKey<FormState>();

    try {
      final TextEditingController _namaController = TextEditingController(
        text: existingProduct?['nama_produk'] ?? '',
      );
     
    
      final TextEditingController _hargaController = TextEditingController(
        text: existingProduct?['harga_jual']?.toString() ?? '',
      );
      final TextEditingController _tagController = TextEditingController(
        text: existingProduct?['tag'] ?? '',
      );
      final TextEditingController _barcodeController = TextEditingController(
        text: (scannedBarcode ?? existingProduct?['barcode'] ?? '').toString(),
      );
      final TextEditingController _satuanController = TextEditingController(
        text: existingProduct?['satuan'] ?? '',
      );

      int? selectedSubKategoriId;
      final rawSub = existingProduct?['sub_kategori_id'];
      if (rawSub != null) {
        selectedSubKategoriId = rawSub is int
            ? rawSub
            : int.tryParse(rawSub.toString());
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      existingProduct != null ? "Edit Produk" : "Tambah Produk",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _namaController,
                      decoration: InputDecoration(
                        labelText: 'Nama Produk',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    
                    SizedBox(height: 12),
                   
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _hargaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Harga Jual',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _satuanController,
                      decoration: InputDecoration(
                        labelText: 'Satuan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        labelText: 'Barcode',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        labelText: 'Tag / Kategori',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value:
                          _subKategori.any(
                            (e) => e['id'] == selectedSubKategoriId,
                          )
                          ? selectedSubKategoriId
                          : null,
                     items: _subKategori
    .map((sub) {
      final kategori = _kategori.firstWhere(
        (k) => k['id'] == sub['kategori_id'],
        orElse: () => {'nama': '-'},
      );
      final label =
          '${kategori['nama'] ?? '-'} - ${sub['nama'] ?? '-'}';
      return DropdownMenuItem<int>(
        value: sub['id'] as int,
        child: Text(label),
      );
    })
    .toList(),
                      decoration: InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => selectedSubKategoriId = val,
                      validator: (v) => v == null ? 'Pilih kategori' : null,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          try {
                            final hargaText = _hargaController.text.trim();
                            final harga = int.tryParse(hargaText);
                            final barcodeText = _barcodeController.text.trim();
                            final dataToSave = {
                              'nama_produk': _namaController.text ?? '',
                             
                              'harga_jual': harga ?? 0,
                              'tag': _tagController.text ?? '',
                              'sub_kategori_id': selectedSubKategoriId ?? '',
                              'barcode': barcodeText.isEmpty
                                  ? null
                                  : barcodeText,
                              'satuan': _satuanController.text ?? '',
                            };

                            if (existingProduct != null &&
                                existingProduct['id'] != null) {
                              await supabase
                                  .from('products')
                                  .update(dataToSave)
                                  .eq('id', existingProduct['id']);
                            } else {
                              await supabase
                                  .from('products')
                                  .insert(dataToSave);
                            }

                            Navigator.pop(context);
                            _fetchData();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  existingProduct != null
                                      ? 'Produk berhasil diperbarui'
                                      : 'Produk berhasil ditambahkan',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e, stackTrace) {
                            _showErrorSnackbar(
                              existingProduct != null
                                  ? 'Gagal memperbarui produk'
                                  : 'Gagal menyimpan produk',
                            );
                            print('Save error: $e');
                            print('Stack trace: $stackTrace');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF03A6A1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        "Simpan",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e, stackTrace) {
      _showErrorSnackbar('Gagal membuka form produk');
      print('Form open error: $e');
      print('Stack trace: $stackTrace');
    }
  }
}
