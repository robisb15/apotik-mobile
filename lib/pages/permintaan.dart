import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/form/barcode_masuk.dart';
import 'package:flutter_application_1/pages/form/entry_manual.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PermintaanBarangPage extends StatefulWidget {
  @override
  _PermintaanBarangPageState createState() => _PermintaanBarangPageState();
}

class _PermintaanBarangPageState extends State<PermintaanBarangPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  String? _filterStatus;
  String? _filterSupplier;
  String? _filterCategory;
  String? _filterSubCategory;
     DateTime? selectedStartDate;
DateTime? selectedEndDate;

  List<Map<String, dynamic>> _requests = [];
  final List<String> _suppliers = [];
  final List<String> _categories = [];
  final List<String> _subCategories = [];
  bool _isLoading = true;
  final Map<String, bool> _expandedDates = {};

  // Color Scheme
  final Color primaryColor = Color(0xFF03A6A1);
  final Color primaryLightColor = Color(0xFFE0F7F6);
  final Color accentColor = Color(0xFFFF7D33);
  final Color dangerColor = Color(0xFFF44336);
  final Color successColor = Color(0xFF4CAF50);

  // Medicine type icons mapping
  final Map<String, IconData> _medicineIcons = {
    'tablet': Icons.medication,
    'capsule': Icons.medication_outlined,
    'syrup': Icons.liquor,
    'injection': Icons.medical_services,
    'drops': Icons.water_drop,
    'default': Icons.medical_services,
  };

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);

 final receipts = await Supabase.instance.client
    .from('receipts')
    .select()
    .filter('deleted_at', 'is', null);
    final details = await supabase.from('receipt_details').select();
     final batches = await supabase.from('product_batches').select('*, products(*, sub_kategori(*, kategori(*)))');
    final distributors = await supabase.from('distributors').select();

    List<Map<String, dynamic>> results = [];

    for (var receipt in receipts) {
      final relatedDetails = details.where(
        (d) => d['receipt_id'] == receipt['id'],
      );

      for (var detail in relatedDetails) {
        final batch = batches.firstWhere(
          (b) => b['id'] == detail['product_batch_id'],
          orElse: () => {
            'batch_code': '-',
            'exp': null,
            'products': {
              'nama_produk': '-',
              'satuan': '-',
              'tag': '-',
              'jenis': 'default',
              'sub_kategori': {
                'nama': '-',
                'kategori': {'nama': '-'}
              }
            }
          },
        );
        final distributor = distributors.firstWhere(
          (d) => d['id'] == detail['distributor_id'],
          orElse: () => {'nama': '-'},
        );
 final product = batch['products'] ?? {};
        final totalHarga = receipt['total_harga'];
        final subKategori = product['sub_kategori']?['nama'] ?? '-';
        final kategori = product['sub_kategori']?['kategori']?['nama'] ?? '-';

        // Add to filter lists if not already present
        if (!_suppliers.contains(distributor['nama'])) {
          _suppliers.add(distributor['nama']);
        }
        if (!_categories.contains(kategori)) {
          _categories.add(kategori);
        }
        if (!_subCategories.contains(subKategori)) {
          _subCategories.add(subKategori);
        }

        results.add({
          'kode_batch': detail['batch_code'] ?? '-',
          'no_faktur': receipt['no_faktur'] ?? '-',
          'distributor': distributor['nama'],
          'tanggal': receipt['tanggal'],
          'formatted_date': DateFormat('dd/MM/yyyy').format(DateTime.parse(receipt['tanggal'])),
          'nama_produk': product['nama_produk'] ?? '-',
          'jenis': product['jenis'] ?? 'default',
          'qty': detail['qty_diterima'] ?? 0,
          'exp': detail['exp'],
          'total_harga': totalHarga,
          'status': 'Pending',
          'satuan': product['satuan'] ?? '-',
          'tag': product['tag'] ?? '-',
          'keterangan': receipt['catatan'] ?? '-',
          'kategori': kategori,
          'sub_kategori': subKategori,
        });
      }
    }

    // Initialize expanded state for each date
    final uniqueDates = results.map((r) => r['tanggal']).toSet();
    for (var date in uniqueDates) {
      _expandedDates[date] = false;
    }

    setState(() {
      _requests = results;
      _isLoading = false;
    });
  }
  void _toggleExpandDate(String date) {
    setState(() {
      _expandedDates[date] = !_expandedDates[date]!;
    });
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Data'),
        content: Text('Yakin ingin menghapus barang masuk ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dangerColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
String formatHarga(dynamic hargaRaw) {
  // Konversi ke string dan hilangkan titik/koma
  final cleaned = hargaRaw.toString().replaceAll(RegExp(r'[^\d]'), '');
  
  // Parse ke int
  final total = int.tryParse(cleaned) ?? 0;

  // Format ke mata uang Indonesia
  return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(total);
}
  Future<void> _deleteReceipt(String noFaktur) async {
   try {
    final receipt = await supabase
        .from('receipts')
        .select('id')
        .eq('no_faktur', noFaktur)
        .maybeSingle();

    if (receipt != null && receipt['id'] != null) {
      final receiptId = receipt['id'];

      // Ambil semua product_batch_id dari receipt_details
      final receiptDetails = await supabase
          .from('receipt_details')
          .select('product_batch_id')
          .eq('receipt_id', receiptId);

      final productBatchIds = receiptDetails
          .map((detail) => detail['product_batch_id'])
          .where((id) => id != null)
          .toList();

      // Hapus receipt_details terlebih dahulu
      await supabase
          .from('receipt_details')
          .delete()
          .eq('receipt_id', receiptId);

      // Hapus product_batches berdasarkan ID yang diperoleh
      if (productBatchIds.isNotEmpty) {
        await supabase
            .from('product_batches')
            .delete()
            .inFilter('id', productBatchIds);
      }

      // Hapus receipt
      await supabase.from('receipts').delete().eq('id', receiptId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data berhasil dihapus'),
          backgroundColor: successColor,
        ),
      );

      await _loadRequests();
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal menghapus data'),
        backgroundColor: dangerColor,
      ),
    );
    print('Delete error: $e');
  }
  }

  IconData _getMedicineIcon(String jenis) {
    return _medicineIcons[jenis.toLowerCase()] ?? _medicineIcons['default']!;
  }

  @override
   Widget build(BuildContext context) {
    final searchText = _searchController.text.toLowerCase();

    final filteredRequests = _requests.where((request) {
      final statusMatch = _filterStatus == null || request['status'] == _filterStatus;
      final supplierMatch = _filterSupplier == null || request['distributor'] == _filterSupplier;
      final categoryMatch = _filterCategory == null || request['kategori'] == _filterCategory;
      final subCategoryMatch = _filterSubCategory == null || request['sub_kategori'] == _filterSubCategory;

      // Search functionality
      final searchMatch = searchText.isEmpty ||
          request['nama_produk'].toString().toLowerCase().contains(searchText) ||
          request['kode_batch'].toString().toLowerCase().contains(searchText) ||
          request['no_faktur'].toString().toLowerCase().contains(searchText);

      // Date filtering
      final requestDate = DateTime.tryParse(request['tanggal'] ?? '') ?? DateTime.now();
      final dateMatch = (selectedStartDate == null || requestDate.isAfter(selectedStartDate!.subtract(Duration(days: 1)))) &&
          (selectedEndDate == null || requestDate.isBefore(selectedEndDate!.add(Duration(days: 1))));

      return statusMatch && supplierMatch && categoryMatch && subCategoryMatch && searchMatch && dateMatch;
    }).toList();

    // Group by date
    final groupedRequests = <String, List<Map<String, dynamic>>>{};
    for (var request in filteredRequests) {
      final date = request['tanggal'];
      if (!groupedRequests.containsKey(date)) {
        groupedRequests[date] = [];
      }
      groupedRequests[date]!.add(request);
    }

    // Sort dates in descending order
    final sortedDates = groupedRequests.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text('Barang Masuk'),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () => _showAddMenu(context),
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari barang masuk...',
                          prefixIcon: Icon(Icons.search, color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedStartDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => selectedStartDate = picked);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  selectedStartDate == null
                                      ? 'Dari Tanggal'
                                      : DateFormat('dd/MM/yyyy').format(selectedStartDate!),
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedEndDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => selectedEndDate = picked);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  selectedEndDate == null
                                      ? 'Sampai Tanggal'
                                      : DateFormat('dd/MM/yyyy').format(selectedEndDate!),
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          if (selectedStartDate != null || selectedEndDate != null)
                            IconButton(
                              icon: Icon(Icons.clear, color: dangerColor),
                              onPressed: () {
                                setState(() {
                                  selectedStartDate = null;
                                  selectedEndDate = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filteredRequests.length} data ditemukan',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                ),
                Expanded(
                  child: filteredRequests.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada data yang ditemukan',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: sortedDates.length,
                          itemBuilder: (context, index) {
                            final date = sortedDates[index];
                            final requests = groupedRequests[date]!;
                            final formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id-ID')
                                .format(DateTime.parse(date));
                            
                            return _buildDateGroup(date, formattedDate, requests);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDateGroup(String date, String formattedDate, List<Map<String, dynamic>> requests) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryLightColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today,
                color: primaryColor,
                size: 20,
              ),
            ),
            title: Text(
              formattedDate,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            trailing: Icon(
              _expandedDates[date]! ? Icons.expand_less : Icons.expand_more,
              color: primaryColor,
            ),
            onTap: () => _toggleExpandDate(date),
          ),
          if (_expandedDates[date]!) ...[
            Divider(height: 1),
            ...requests.map((request) => _buildRequestItem(request)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> data) {
    return Dismissible(
      key: ValueKey('${data['no_faktur']}_${data['kode_batch']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: dangerColor,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async => await _confirmDelete(context),
      onDismissed: (direction) async => await _deleteReceipt(data['no_faktur']),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: primaryLightColor,
            radius: 20,
            child: Icon(
              _getMedicineIcon(data['jenis']),
              color: primaryColor,
            ),
          ),
          title: Text(
            data['nama_produk'],
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${data['qty']} ${data['satuan']} • ${data['distributor']}',
            style: TextStyle(fontSize: 12),
          ),
          trailing: Text(
            data['formatted_date'],
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('No. Faktur', data['no_faktur']),
                  _buildDetailRow('Kode Batch', data['kode_batch']),
                  _buildDetailRow('Kategori', data['kategori']),
                  _buildDetailRow('Sub Kategori', data['sub_kategori']??'-'),
                  _buildDetailRow('Tag', data['tag']??'-'),
                  if (data['exp'] != null)
                    _buildDetailRow(
                      'Expired',
                      DateFormat('dd/MM/yyyy').format(DateTime.parse(data['exp'])),
                      isWarning: true,
                    ),
                  _buildDetailRow(
                    'Harga',
                    '${formatHarga(data['total_harga'])}',
                    isBold: true,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Keterangan:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(data['keterangan']),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false, bool isWarning = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isWarning ? dangerColor : Colors.grey[800],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMenu(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.qr_code_scanner, color: primaryColor),
              title: Text('Scan Barcode'),
              onTap: () => Navigator.pop(context, 'scan'),
            ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Icons.edit, color: primaryColor),
              title: Text('Entry Manual'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );

    if (result == 'scan') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ScanBarcodePage()),
      );
    } else if (result == 'manual') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EntryManualPage()),
      );
    }
    await _loadRequests();
  }

  void _showFilterDialog() {
    String? selectedStatus = _filterStatus;
    String? selectedSupplier = _filterSupplier;
    String? selectedCategory = _filterCategory;
    String? selectedSubCategory = _filterSubCategory;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Filter Barang Masuk', style: TextStyle(color: primaryColor)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
             
             
              DropdownButtonFormField<String>(
                value: selectedSupplier,
                decoration: InputDecoration(
                  labelText: 'Supplier',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text('Semua Supplier')),
                  ..._suppliers.map(
                    (supplier) => DropdownMenuItem(value: supplier, child: Text(supplier)),
                  ),
                ],
                onChanged: (value) => selectedSupplier = value,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text('Semua Kategori')),
                  ..._categories.map(
                    (category) => DropdownMenuItem(value: category, child: Text(category)),
                  ),
                ],
                onChanged: (value) => selectedCategory = value,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSubCategory,
                decoration: InputDecoration(
                  labelText: 'Sub Kategori',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text('Semua Sub Kategori')),
                  ..._subCategories.map(
                    (subCategory) => DropdownMenuItem(value: subCategory, child: Text(subCategory)),
                  ),
                ],
                onChanged: (value) => selectedSubCategory = value,
              ),
              SizedBox(height: 16),
Text('Tanggal Masuk', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
SizedBox(height: 8),
Row(
  children: [
    Expanded(
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedStartDate ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            setState(() => selectedStartDate = picked);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            selectedStartDate == null ? 'Dari Tanggal' : DateFormat('dd/MM/yyyy').format(selectedStartDate!),
          ),
        ),
      ),
    ),
    SizedBox(width: 8),
    Expanded(
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedEndDate ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            setState(() => selectedEndDate = picked);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            selectedEndDate == null ? 'Sampai Tanggal' : DateFormat('dd/MM/yyyy').format(selectedEndDate!),
          ),
        ),
      ),
    ),
  ],
),
            ],
          ),
        ),
        actions: [
        TextButton(
  onPressed: () {
    setState(() {
      _filterStatus = null;
      _filterSupplier = null;
      _filterCategory = null;
      _filterSubCategory = null;
      selectedStartDate = null;
      selectedEndDate = null;
    });
    Navigator.pop(context);
  },
  child: Text('Reset', style: TextStyle(color: primaryColor)),
),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _filterStatus = selectedStatus;
                _filterSupplier = selectedSupplier;
                _filterCategory = selectedCategory;
                _filterSubCategory = selectedSubCategory;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text('Terapkan'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}