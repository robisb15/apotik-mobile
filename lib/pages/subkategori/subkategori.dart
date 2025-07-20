import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SubKategoriManagementPage extends StatefulWidget {
  @override
  _SubKategoriManagementPageState createState() =>
      _SubKategoriManagementPageState();
}

class _SubKategoriManagementPageState extends State<SubKategoriManagementPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subCategoryNameController =
      TextEditingController();
  int? _selectedCategoryId;
  int? _editingIndex;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.delayed(300.ms); // Small delay for animation

    try {
      final allKategoriRes = await supabase.from('kategori').select();
      final subKategoriRes = await supabase
          .from('sub_kategori')
          .select('id, nama, kategori_id')
          .filter('deleted_at', 'is', null);

      final usedCategoryIds = subKategoriRes
          .map((item) => item['kategori_id'] as int)
          .toSet();

      final kategoriFiltered = allKategoriRes.where((kategori) {
        return kategori['deleted_at'] == null ||
            usedCategoryIds.contains(kategori['id']);
      }).toList();

      setState(() {
        _categories = List<Map<String, dynamic>>.from(kategoriFiltered);
        _subCategories = List<Map<String, dynamic>>.from(subKategoriRes);
      });
    } catch (e) {
      print('Error fetch: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSubCategoryForm([int? index]) {
    _editingIndex = index;
    if (index != null) {
      final sub = _subCategories[index];
      _subCategoryNameController.text = sub['nama'];
      _selectedCategoryId = sub['kategori_id'];
    } else {
      _subCategoryNameController.clear();
      _selectedCategoryId = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  index == null ? 'Tambah Sub Kategori' : 'Edit Sub Kategori',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF03A6A1),
                  ),
                ),
                SizedBox(height: 24),
                DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: 'Kategori Induk',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF03A6A1)),
                    ),
                    prefixIcon: Icon(Icons.category, color: Color(0xFF03A6A1)),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 15,
                    ),
                  ),
                  items: _categories
                      .where((cat) => cat['deleted_at'] == null)
                      .map(
                        (cat) => DropdownMenuItem<int>(
                          value: cat['id'],
                          child: Text(cat['nama'] ?? '-'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                  validator: (val) =>
                      val == null ? 'Pilih kategori induk' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _subCategoryNameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Sub Kategori',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF03A6A1)),
                    ),
                    prefixIcon: Icon(
                      Icons.subdirectory_arrow_right,
                      color: Color(0xFF03A6A1),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 15,
                    ),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Wajib diisi' : null,
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveSubCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF03A6A1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      index == null ? 'Simpan' : 'Update',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      _subCategoryNameController.clear();
      _editingIndex = null;
    });
  }

  Future<void> _saveSubCategory() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'nama': _subCategoryNameController.text,
      'kategori_id': _selectedCategoryId,
    };

    try {
      if (_editingIndex == null) {
        await supabase.from('sub_kategori').insert(data);
      } else {
        final id = _subCategories[_editingIndex!]['id'];
        await supabase.from('sub_kategori').update(data).eq('id', id);
      }

      Navigator.pop(context);
      _editingIndex = null;
      _subCategoryNameController.clear();
      _fetchData();
    } catch (e) {
      print('Gagal simpan: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan data'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _deleteSubCategory(int index) async {
    final id = _subCategories[index]['id'];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_rounded, size: 48, color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Hapus Sub Kategori',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Yakin ingin menghapus ${_subCategories[index]['nama']}?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Batal'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await supabase
                              .from('sub_kategori')
                              .update({
                                'deleted_at': DateTime.now().toIso8601String(),
                              })
                              .eq('id', id);
                          _fetchData();
                        } catch (e) {
                          print('Gagal hapus: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal menghapus data'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text('Hapus'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daftar Sub Kategori',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF03A6A1),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showSubCategoryForm(),
              icon: Icon(Icons.add, size: 18),
              label: Text('Tambah'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF03A6A1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildSubCategoryList() {
    if (_subCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.subdirectory_arrow_right,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Belum ada sub kategori',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => _showSubCategoryForm(),
              child: Text('Tambah Sub Kategori'),
            ),
          ],
        ).animate().fadeIn(),
      );
    }

    return ListView.builder(
      physics: BouncingScrollPhysics(),
      itemCount: _subCategories.length,
      itemBuilder: (context, index) {
        final sub = _subCategories[index];
        final kategori = _categories.firstWhere(
          (k) => k['id'] == sub['kategori_id'],
          orElse: () => {'nama': '-'},
        );

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
                    Icons.subdirectory_arrow_right,
                    color: Color(0xFF03A6A1),
                  ),
                ),
                title: Text(
                  sub['nama'],
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Kategori: ${kategori['nama']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: Colors.grey[600]),
                      onPressed: () => _showSubCategoryForm(index),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                      onPressed: () => _deleteSubCategory(index),
                    ),
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

  @override
  void dispose() {
    _subCategoryNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Manajemen Sub Kategori'),
        backgroundColor: Color(0xFF03A6A1),
        centerTitle: true,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: _isLoading
          ? Center(
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
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildHeader(),
                  SizedBox(height: 16),
                  Expanded(child: _buildSubCategoryList()),
                ],
              ),
            ),
    );
  }
}
