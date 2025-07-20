import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementPage extends StatefulWidget {
  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  Map<String, dynamic>? _editingUser;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final response = await supabase.from('users').select().order('id');
    setState(() {
      _users = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
    });
  }

  Future<void> _saveUser() async {
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text.trim();
      final email = '$username@apotik.com';
      final password = _passwordController.text.trim();
      final nama = _nameController.text;

      try {
        if (_editingUser == null) {
          // 🟢 Sign up via Supabase Auth
          final authResponse = await supabase.auth.signUp(
            email: email,
            password: password,
          );

          final userId = authResponse.user?.id;
          if (userId == null) throw 'Gagal membuat akun pengguna.';

          // 🔵 Simpan ke tabel users
          await supabase.from('users').insert({
            'user_id': userId,
            'nama': nama,
            'username': username,
            'email': email,
            'role': 'staff',
          });
        } else {
          // 🔧 Update data pengguna (tidak ubah akun Auth)
          await supabase
              .from('users')
              .update({'nama': nama, 'username': username, 'email': email})
              .eq('id', _editingUser!['id']);
        }

        Navigator.pop(context);
        _resetForm();
        await _loadUsers();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    }
  }

  Future<void> _deleteUser(int id) async {
    await supabase.from('users').delete().eq('id', id);
    await _loadUsers();
  }

  void _resetForm() {
    _nameController.clear();
    _usernameController.clear();
    _editingUser = null;
  }

  void _showUserForm([Map<String, dynamic>? user]) {
    _editingUser = user;
    if (user != null) {
      _nameController.text = user['nama'];
      _usernameController.text = user['username'];
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
              children: [
                Text(
                  user == null ? 'Tambah Pengguna' : 'Edit Pengguna',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF03A6A1),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Wajib diisi' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_circle),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username wajib diisi';
                    }
                    if (value.contains(' ')) {
                      return 'Username tidak boleh mengandung spasi';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: _editingUser == null
                        ? 'Password'
                        : 'Password (Opsional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (value) {
                    if (_editingUser == null &&
                        (value == null || value.isEmpty)) {
                      return 'Password wajib diisi';
                    }
                    if (value != null && value.isNotEmpty && value.length < 6) {
                      return 'Minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF03A6A1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: Size(double.infinity, 48),
                  ),
                  child: Text(user == null ? 'Simpan' : 'Update'),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Pengguna'),
        content: Text('Yakin ingin menghapus ${user['nama']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteUser(user['id']);
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
        title: Text('Kelola Pengguna'),
        centerTitle: true,
        backgroundColor: Color(0xFF03A6A1),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? Center(child: Text('Belum ada pengguna.'))
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFF03A6A1).withOpacity(0.1),
                      child: Icon(Icons.person, color: Color(0xFF03A6A1)),
                    ),
                    title: Text(user['nama']),
                    subtitle: Text('${user['email']} (${user['role']})'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showUserForm(user),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(user),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserForm(),
        backgroundColor: Color(0xFF03A6A1),
        child: Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}
