import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CategoryManagementPage extends StatefulWidget {
  @override
  _CategoryManagementPageState createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _categoryNameController = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  int? _editingIndex;
  String? role;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final supabase = Supabase.instance.client;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('users')
          .select('role')
          .eq('user_id', userId) // pastikan kolom user_id ada di tabel
          .maybeSingle(); // gunakan maybeSingle agar tidak throw error otomatis
      if (response == null) {
        // Data user tidak ditemukan
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data user tidak ditemukan.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Data ditemukan, simpan ke state
      if (mounted) {
        setState(() {
          role = response['role'];
        });
      }
    } catch (e) {
      // Tangani error lainnya
      print('Gagal mengambil data user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat memuat data.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    await Future.delayed(500.ms); // Small delay for animation
    try {
      final response = await supabase
          .from('kategori')
          .select()
          .filter('deleted_at', 'is', null);

      setState(() {
        _categories = response
            .map((item) => {'id': item['id'], 'nama': item['nama']})
            .toList()
            .cast<Map<String, dynamic>>();
      });
    } catch (e) {
      print('Gagal memuat kategori: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data kategori'),
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

  Future<void> _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      final name = _categoryNameController.text;
      try {
        if (_editingIndex == null) {
          await supabase.from('kategori').insert({'nama': name});
        } else {
          final id = _categories[_editingIndex!]['id'];
          await supabase.from('kategori').update({'nama': name}).eq('id', id);
        }

        Navigator.pop(context);
        _categoryNameController.clear();
        _editingIndex = null;
        _fetchCategories();
      } catch (e) {
        print('Gagal menyimpan kategori: $e');
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
  }

  Future<void> _deleteCategory(int index) async {
    final id = _categories[index]['id'];
    try {
      final now = DateTime.now().toIso8601String();
      await supabase.from('kategori').update({'deleted_at': now}).eq('id', id);
      _fetchCategories();
    } catch (e) {
      print('Gagal menghapus kategori: $e');
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
  }

  void _showCategoryForm(BuildContext context, [int? index]) {
    _editingIndex = index;
    if (index != null) {
      _categoryNameController.text = _categories[index]['nama'];
    } else {
      _categoryNameController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
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
                index == null ? 'Tambah Kategori' : 'Edit Kategori',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF03A6A1),
                ),
              ),
              SizedBox(height: 24),
              TextFormField(
                controller: _categoryNameController,
                decoration: InputDecoration(
                  labelText: 'Nama Kategori',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
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
                validator: (value) => value == null || value.isEmpty
                    ? 'Nama kategori wajib diisi'
                    : null,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF03A6A1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    index == null ? 'Simpan' : 'Update',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ).then((_) {
      _categoryNameController.clear();
      _editingIndex = null;
    });
  }

  void _confirmDelete(int index) {
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
                'Hapus Kategori',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Yakin ingin menghapus ${_categories[index]['nama']}?',
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
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteCategory(index);
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
              'Daftar Kategori',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF03A6A1),
              ),
            ),
            if (role == 'admin') ...[
              ElevatedButton.icon(
                onPressed: () => _showCategoryForm(context),
                icon: Icon(Icons.add, size: 18),
                label: Text('Tambah'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF03A6A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildCategoryList() {
    if (_isLoading) {
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

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('Belum ada kategori', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            if (role == 'admin') ...[
              TextButton(
                onPressed: () => _showCategoryForm(context),
                child: Text('Tambah Kategori'),
              ),
            ],
          ],
        ).animate().fadeIn(),
      );
    }

    return ListView.builder(
      physics: BouncingScrollPhysics(),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
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
                  child: Icon(Icons.category, color: Color(0xFF03A6A1)),
                ),
                title: Text(
                  category['nama'],
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (role == 'admin') ...[
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          color: Colors.grey[600],
                        ),
                        onPressed: () => _showCategoryForm(context, index),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red[400],
                        ),
                        onPressed: () => _confirmDelete(index),
                      ),
                    ],
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
    _categoryNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Manajemen Kategori'),
        backgroundColor: Color(0xFF03A6A1),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeader(),
            SizedBox(height: 16),
            Expanded(child: _buildCategoryList()),
          ],
        ),
      ),
    );
  }
}
