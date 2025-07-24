// ignore_for_file: use_key_in_widget_constructors, unnecessary_type_check, unnecessary_null_comparison, library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DistributorManagementPage extends StatefulWidget {
  @override
  _DistributorManagementPageState createState() =>
      _DistributorManagementPageState();
}

class _DistributorManagementPageState extends State<DistributorManagementPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _distributors = [];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  Map<String, dynamic>? _editingDistributor;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDistributors();
  }

  Future<void> _loadDistributors() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase.from('distributors').select();
      if (response != null && response is List) {
        setState(() {
          _distributors = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      } else {
        setState(() {
          _distributors = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _distributors = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat data distributor')));
    }
  }

  Future<void> _saveDistributor() async {
    if (_formKey.currentState!.validate()) {
      final distributor = {
        'nama': _nameController.text,
        'alamat': _addressController.text,
        'kontak': _contactController.text,
      };

      if (_editingDistributor == null) {
        await supabase.from('distributors').insert(distributor);
      } else {
        await supabase
            .from('distributors')
            .update(distributor)
            .eq('id', _editingDistributor!['id']);
      }

      Navigator.pop(context);
      _resetForm();
      await _loadDistributors();
    }
  }

  Future<void> _deleteDistributor(String id) async {
    await supabase.from('distributors').delete().eq('id', id);
    await _loadDistributors();
  }

  void _resetForm() {
    _nameController.clear();
    _addressController.clear();
    _contactController.clear();
    _editingDistributor = null;
  }

  void _showDistributorForm(
    BuildContext context, [
    Map<String, dynamic>? distributor,
  ]) {
    _editingDistributor = distributor;
    if (distributor != null) {
      _nameController.text = distributor['nama'] ?? '';
      _addressController.text = distributor['alamat'] ?? '';
      _contactController.text = distributor['kontak'] ?? "";
    } else {
      _resetForm();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
                  distributor == null
                      ? 'Tambah Distributor'
                      : 'Edit Distributor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF03A6A1),
                  ),
                ),
                SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Distributor',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business, color: Color(0xFF03A6A1)),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Nama distributor wajib diisi'
                      : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Alamat',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.location_on,
                      color: Color(0xFF03A6A1),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Alamat wajib diisi'
                      : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _contactController,
                  decoration: InputDecoration(
                    labelText: 'Kontak',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone, color: Color(0xFF03A6A1)),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Kontak wajib diisi'
                      : null,
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveDistributor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF03A6A1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(distributor == null ? 'Simpan' : 'Update'),
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> dist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Distributor'),
        content: Text('Yakin ingin menghapus ${dist['nama']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteDistributor(dist['id']);
            },
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manajemen Distributor'),
        centerTitle: true,
        backgroundColor: Color(0xFF03A6A1),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildDistributorList(),
    );
  }

  Widget _buildDistributorList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Distributor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF03A6A1),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showDistributorForm(context),
                icon: Icon(Icons.add),
                label: Text('Tambah'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF03A6A1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDistributors,
              child: _distributors.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: 100),
                        Center(child: Text('Belum ada distributor')),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _distributors.length,
                      itemBuilder: (context, index) {
                        final dist = _distributors[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Color(0xFF03A6A1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.local_shipping,
                                color: Color(0xFF03A6A1),
                              ),
                            ),
                            title: Text(
                              dist['nama'] ?? '-',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dist['alamat'] ?? '-'),
                                Text('Kontak: ${dist['kontak'] ?? '-'}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () =>
                                      _showDistributorForm(context, dist),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDelete(dist),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    super.dispose();
  }
}
