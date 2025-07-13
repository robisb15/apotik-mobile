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
            colors: [
              Color(0xFF03A6A1).withOpacity(0.8),
              Color(0xFF0288A1).withOpacity(0.9),
            ],
          ),
        ),
        child: Column(
          children: [
            // Header with user info
            _buildUserHeader(context),
            
            // Main content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 20),
                      Text(
                        'Selamat Datang,',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800]),
                      ),
                      Text(
                        'Apa yang ingin Anda lakukan hari ini?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600]),
                      ),
                      SizedBox(height: 40),
                      
                      // Action buttons
                      _buildActionButton(
                        context,
                        icon: Icons.medical_services,
                        label: 'Daftar Produk',
                        color: Color(0xFF03A6A1),
                        onPressed: () {
                          // Navigate to product list
                          Navigator.pushNamed(context, '/produk');
                        },
                      ),
                      SizedBox(height: 20),
                      _buildActionButton(
                        context,
                        icon: Icons.exit_to_app,
                        label: 'Logout',
                        color: Colors.red[400]!,
                        onPressed: () {
                          _showLogoutConfirmation(context);
                        },
                      ),
                      
                      // Additional info
                      Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          'Apotek Sehat v1.0',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12),
                        ),
                      ),
                    ],
                  ),
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
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withOpacity(0.3),
              child: Icon(
                Icons.person,
                size: 30,
                color: Colors.white),
            ),
            SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Apotek',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                ),
                Text(
                  'Staff Apotek',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14),
                ),
              ],
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                // Navigate to settings
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
       backgroundColor: color, 
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

void _showLogoutConfirmation(BuildContext context) {
  final outerContext = context; // simpan context luar untuk SnackBar

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Konfirmasi Logout'),
        content: Text('Anda yakin ingin keluar dari aplikasi?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            child: Text('Batal', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Logout', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.of(context).pop(); // Tutup dialog dulu

              try {
                await Supabase.instance.client.auth.signOut(); // Logout dari Supabase
                Navigator.pushReplacementNamed(outerContext, '/');
              } catch (e) {
                // Gunakan context luar, bukan context dialog
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