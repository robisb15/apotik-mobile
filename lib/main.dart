import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/distributor/distributor.dart';
import 'package:flutter_application_1/pages/kategori/kategori.dart';
import 'package:flutter_application_1/pages/laporan/laporan.dart';
import 'package:flutter_application_1/pages/produk/produk.dart';
import 'package:flutter_application_1/pages/subkategori/subkategori.dart';
import 'package:flutter_application_1/pages/user/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
   await Supabase.initialize(
    url: 'https://znwwcmndzaeuncxexjxt.supabase.co', // Ganti dengan URL Supabase milikmu
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpud3djbW5kemFldW5jeGV4anh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzOTkxODksImV4cCI6MjA2Nzk3NTE4OX0.oWVyw8ocP6rfdEJ9XTVskTXXwhw4Z9RbwZZj9BPjDx0', // Ganti dengan anon key Supabase kamu
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login & Navigation App',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/home': (context) => HomePage(),
        '/produk': (context) => ProductPage(),
        '/kategori': (context) => CategoryManagementPage(),
        '/subkategori': (context) => SubKategoriManagementPage(),
        '/user': (context) => UserManagementPage(),
        '/distributor': (context) => DistributorManagementPage(),
        '/laporan': (context) => InventoryTabsPage()
      },
    );
  }
}
