import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF03A6A6), Color(0xFF0288D1)],
          ),
        ),
        child: Column(
          children: [
            _buildUserHeader(context),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(height: 20),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.symmetric(horizontal: 15),
                        children: [
                          // Grup Manajemen Produk
                          _buildSectionHeader('Manajemen Produk'),
                          _buildMenuItem(
                            icon: Icons.inventory_2,
                            title: 'Data Produk',
                            color: Colors.teal[400]!,
                            onTap: () =>
                                Navigator.pushNamed(context, '/produk'),
                          ),
                          Divider(height: 1, indent: 60),
                          _buildMenuItem(
                            icon: Icons.category,
                            title: 'Kategori Produk',
                            color: Colors.orange[400]!,
                            onTap: () =>
                                Navigator.pushNamed(context, '/kategori'),
                          ),
                          Divider(height: 1, indent: 60),
                          _buildMenuItem(
                            icon: Icons.subtitles,
                            title: 'Sub Kategori',
                            color: Colors.purple[400]!,
                            onTap: () =>
                                Navigator.pushNamed(context, '/subkategori'),
                          ),
                          SizedBox(height: 20),

                          // Grup Manajemen Sistem
                          _buildSectionHeader('Manajemen Sistem'),
                          _buildMenuItem(
                            icon: Icons.people_alt,
                            title: 'Kelola User',
                            color: Colors.indigo[400]!,
                            onTap: () => Navigator.pushNamed(context, '/user'),
                          ),
                          Divider(height: 1, indent: 60),
                          _buildMenuItem(
                            icon: Icons.cabin,
                            title: 'Kelola Distributor',
                            color: Colors.blue[400]!,
                            onTap: () =>
                                Navigator.pushNamed(context, '/distributor'),
                          ),

                          SizedBox(height: 20),

                          // Grup Laporan
                          _buildSectionHeader('Laporan'),
                          _buildMenuItem(
                            icon: Icons.pie_chart,
                            title: 'Laporan Penjualan',
                            color: Colors.green[400]!,
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/laporan',
                            ),
                          ),
                          SizedBox(height: 20),

                          // Menu Logout
                          _buildLogoutButton(context),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.person, size: 30, color: Colors.white),
            ),
            SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Staf Apotek',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'staf@gmail.com',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Spacer(),
            IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications, color: Colors.white, size: 22),
              ),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 15, top: 10, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 10),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 10),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.exit_to_app, color: Colors.red, size: 22),
      ),
      title: Text(
        'Keluar Aplikasi',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.red,
        ),
      ),
      onTap: () => _showLogoutConfirmation(context),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    final outerContext = context;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.exit_to_app, color: Colors.red),
              SizedBox(width: 10),
              Text('Konfirmasi Logout'),
            ],
          ),
          content: Text('Anda yakin ingin keluar dari aplikasi?'),
          actions: [
            TextButton(
              child: Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Keluar', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await Supabase.instance.client.auth.signOut();
                  Navigator.pushReplacementNamed(outerContext, '/');
                } catch (e) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    SnackBar(
                      content: Text('Logout gagal: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
