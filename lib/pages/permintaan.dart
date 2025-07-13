import 'package:flutter/material.dart';

class PermintaanBarangPage extends StatefulWidget {
  @override
  _PermintaanBarangPageState createState() => _PermintaanBarangPageState();
}

class _PermintaanBarangPageState extends State<PermintaanBarangPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedMedicine;
  String? _selectedSupplier;
  String _requestStatus = 'Pending';

  // Dummy data
  final List<String> _medicines = [
    'Paracetamol 500mg',
    'Amoxicillin 500mg',
    'Cetirizine 10mg',
    'Omeprazole 20mg',
    'Vitamin C 500mg'
  ];

  final List<String> _suppliers = [
    'Supplier Farmasi Sejahtera',
    'PT. Medika Utama',
    'CV. Bintang Farmasi',
    'Apotek Jaya Mandiri'
  ];

  final List<Map<String, dynamic>> _requests = [
    {
      'id': 'REQ-001',
      'medicine': 'Paracetamol 500mg',
      'quantity': 50,
      'supplier': 'Supplier Farmasi Sejahtera',
      'date': '12/06/2023',
      'status': 'Pending',
    },
    {
      'id': 'REQ-002',
      'medicine': 'Amoxicillin 500mg',
      'quantity': 30,
      'supplier': 'PT. Medika Utama',
      'date': '10/06/2023',
      'status': 'Diproses',
    },
    {
      'id': 'REQ-003',
      'medicine': 'Vitamin C 500mg',
      'quantity': 100,
      'supplier': 'CV. Bintang Farmasi',
      'date': '08/06/2023',
      'status': 'Selesai',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Permintaan Barang'),
        centerTitle: true,
        backgroundColor: Color(0xFF03A6A1),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari permintaan...',
                prefixIcon: Icon(Icons.search, color: Color(0xFF03A6A1)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              onChanged: (value) {
                // Implementasi fitur pencarian
              },
            ),
          ),

          // List Permintaan
          Expanded(
            child: ListView.builder(
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final request = _requests[index];
                return _buildRequestCard(request);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRequestDialog,
        backgroundColor: Color(0xFF03A6A1),
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    Color statusColor;
    switch (request['status']) {
      case 'Pending':
        statusColor = Colors.orange;
        break;
      case 'Diproses':
        statusColor = Colors.blue;
        break;
      case 'Selesai':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ID & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(request['id'],
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700])),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    request['status'],
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              request['medicine'],
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.local_shipping, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  request['supplier'],
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      request['date'],
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  '${request['quantity']} pcs',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF03A6A1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRequestDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Buat Permintaan Baru',
              style: TextStyle(color: Color(0xFF03A6A1))),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Pilih Obat',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.medical_services, color: Color(0xFF03A6A1)),
                    ),
                    value: _selectedMedicine,
                    items: _medicines.map((medicine) {
                      return DropdownMenuItem(
                        value: medicine,
                        child: Text(medicine),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMedicine = value;
                      });
                    },
                    validator: (value) => value == null ? 'Pilih obat' : null,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Pilih Supplier',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business, color: Color(0xFF03A6A1)),
                    ),
                    value: _selectedSupplier,
                    items: _suppliers.map((supplier) {
                      return DropdownMenuItem(
                        value: supplier,
                        child: Text(supplier),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSupplier = value;
                      });
                    },
                    validator: (value) => value == null ? 'Pilih supplier' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Jumlah',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.format_list_numbered, color: Color(0xFF03A6A1)),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Masukkan jumlah';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Masukkan angka yang valid';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Catatan (Opsional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note, color: Color(0xFF03A6A1)),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info_outline, color: Color(0xFF03A6A1)), // Ganti dari Icons.status
                    ),
                    value: _requestStatus,
                    items: ['Pending', 'Diproses', 'Selesai'].map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _requestStatus = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Permintaan berhasil dibuat'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF03A6A1)),
              child: Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showFilterDialog() {
    String? filterStatus;
    String? filterSupplier;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Filter Permintaan',
              style: TextStyle(color: Color(0xFF03A6A1))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Filter Berdasarkan Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('Semua Status')),
                    ...['Pending', 'Diproses', 'Selesai'].map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    filterStatus = value;
                  },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Filter Berdasarkan Supplier',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('Semua Supplier')),
                    ..._suppliers.map((supplier) {
                      return DropdownMenuItem(
                        value: supplier,
                        child: Text(supplier),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    filterSupplier = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Reset', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                // Filter logic goes here
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF03A6A1)),
              child: Text('Terapkan'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
