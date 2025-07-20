import 'package:flutter/material.dart';
import 'pages/dashboard.dart';
import 'pages/permintaan.dart';
import 'pages/scan.dart';
import 'pages/keluar.dart';
import 'pages/lainnya.dart';

class HomePage extends StatefulWidget {
  final int initialIndex;
  const HomePage({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _currentIndex;

  final List<Widget> _pages = [
    Dashboard(),
    PermintaanBarangPage(),
    ScanPage(),
    BarangKeluarPage(),
    UserPage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.inbox), label: 'Masuk'),
          BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.outbox), label: 'Keluar'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Lainnya'),
        ],
      ),
    );
  }
}
