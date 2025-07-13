import 'package:flutter/material.dart';
import 'pages/dashboard.dart';
import 'pages/permintaan.dart';
import 'pages/page3.dart';
import 'pages/page4.dart';
import 'pages/lainnya.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final _pages = [Dashboard(), PermintaanBarangPage(), Page3(), Page4(), UserPage()];

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
          BottomNavigationBarItem(icon: Icon(Icons.document_scanner), label: 'Permintaan'),
          BottomNavigationBarItem(icon: Icon(Icons.camera), label: 'Page 3'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Page 4'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Lainnya'),
        ],
      ),
    );
  }
}
