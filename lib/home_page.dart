import 'package:flutter/material.dart';
import 'pages/dashboard.dart';
import 'pages/permintaan.dart';
import 'pages/scan.dart';
import 'pages/keluar.dart';
import 'pages/lainnya.dart';

class HomePage extends StatelessWidget {
  final int initialIndex;

  const HomePage({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: initialIndex,
      length: 5,
      child: Scaffold(
        body: TabBarView(
          children: [
            Dashboard(),
            GroupedBarangMasukPage(),
            ScanPage(),
            BarangKeluarPage(),
            UserPage(),
          ],
        ),
        bottomNavigationBar: const Material(
          color: Color(0xFF03A6A1), // warna latar tab
          child: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white, // garis bawah aktif
            tabs: [
              Tab(icon: Icon(Icons.home), text: 'Dashboard'),
              Tab(icon: Icon(Icons.inbox), text: 'Masuk'),
              Tab(icon: Icon(Icons.document_scanner), text: 'Scan'),
              Tab(icon: Icon(Icons.outbox), text: 'Keluar'),
              Tab(icon: Icon(Icons.settings), text: 'Lainnya'),
            ],
          ),
        ),
      ),
    );
  }
}
