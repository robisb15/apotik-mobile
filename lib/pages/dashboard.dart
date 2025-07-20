import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/stok_barang.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class Dashboard extends StatefulWidget {
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> recentMasuk = [];
  List<Map<String, dynamic>> recentKeluar = [];

  int totalQty = 0;
  int totalMasuk = 0;
  int totalKeluar = 0;
  int hampirHabis = 0;
  List<Map<String, dynamic>> inventoryItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    await Future.wait([
      fetchDashboardData(),
      _loadBarangMasuk(),
      _loadBarangKeluar(),
    ]);
    setState(() => isLoading = false);
  }

  Future<void> _loadBarangMasuk() async {
    final receipts = await supabase.from('receipts').select();
    final details = await supabase.from('receipt_details').select();
    final products = await supabase.from('products').select();
    final distributors = await supabase.from('distributors').select();

    List<Map<String, dynamic>> results = [];

    for (var receipt in receipts) {
      final relatedDetails = details.where(
        (d) => d['receipt_id'] == receipt['id'],
      );

      for (var detail in relatedDetails) {
        final product = products.firstWhere(
          (p) => p['id'] == detail['product_id'],
          orElse: () => {'nama_produk': '-', 'satuan': '-'},
        );

        final distributor = distributors.firstWhere(
          (d) => d['id'] == detail['distributor_id'],
          orElse: () => {'nama': '-'},
        );

        results.add({
          'nama_produk': product['nama_produk'],
          'qty': detail['qty_diterima'],
          'satuan': product['satuan'],
          'tanggal': DateFormat(
            'dd/MM/yyyy',
          ).format(DateTime.parse(receipt['tanggal'])),
          'no_faktur': receipt['no_faktur'],
        });
      }
    }

    results.sort((a, b) => b['tanggal'].compareTo(a['tanggal']));
    setState(() {
      recentMasuk = results.take(5).toList();
    });
  }

  Future<void> _loadBarangKeluar() async {
    final outgoings = await supabase.from('outgoings').select();
    final details = await supabase.from('outgoing_details').select();
    final batches = await supabase.from('product_batches').select();
    final products = await supabase.from('products').select();

    List<Map<String, dynamic>> results = [];

    for (var keluar in outgoings) {
      final keluarId = keluar['id'];
      final relatedDetails = details.where((d) => d['outgoing_id'] == keluarId);

      for (var detail in relatedDetails) {
        final batch = batches.firstWhere(
          (b) => b['id'] == detail['product_batch_id'],
          orElse: () => {'batch_code': '-', 'exp': null, 'product_id': null},
        );

        final product = products.firstWhere(
          (p) => p['id'] == batch['product_id'],
          orElse: () => {'nama_produk': '-', 'satuan': '-'},
        );

        results.add({
          'nama_produk': product['nama_produk'],
          'qty': detail['qty_keluar'],
          'satuan': product['satuan'],
          'tanggal': DateFormat(
            'dd/MM/yyyy',
          ).format(DateTime.parse(keluar['tanggal'])),
          'no_faktur': keluar['no_faktur'],
        });
      }
    }

    results.sort((a, b) => b['tanggal'].compareTo(a['tanggal']));
    setState(() {
      recentKeluar = results.take(5).toList();
    });
  }

  Future<void> fetchDashboardData() async {
    final batches = await supabase
        .from('product_batches')
        .select(
          'qty_sisa, qty_masuk, qty_keluar, batch_code, products(nama_produk, satuan)',
        );

    int totalQtySisa = 0;
    int totalQtyMasuk = 0;
    int totalQtyKeluar = 0;
    int stokRendah = 0;
    List<Map<String, dynamic>> listItems = [];

    for (final batch in batches) {
      final product = batch['products'] ?? {};
      final qtySisa = (batch['qty_sisa'] as num?)?.toInt() ?? 0;
      final qtyMasuk = (batch['qty_masuk'] as num?)?.toInt() ?? 0;
      final qtyKeluar = (batch['qty_keluar'] as num?)?.toInt() ?? 0;

      totalQtySisa += qtySisa;
      totalQtyMasuk += qtyMasuk;
      totalQtyKeluar += qtyKeluar;
      if (qtySisa < 10) stokRendah++;

      listItems.add({
        'name': product['nama_produk'] ?? 'Tanpa Nama',
        'code': batch['batch_code'],
        'stock': qtySisa,
        'incoming': qtyMasuk,
        'total': qtyMasuk,
        'unit': product['satuan'] ?? '',
      });
    }

    setState(() {
      totalQty = totalQtySisa;
      totalMasuk = totalQtyMasuk;
      totalKeluar = totalQtyKeluar;
      hampirHabis = stokRendah;
      inventoryItems = listItems;
    });
  }

  Widget _buildBarangCard(Map<String, dynamic> data, {bool keluar = false}) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: keluar ? Colors.red[50] : Colors.green[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            keluar ? Icons.upload : Icons.download,
            color: keluar ? Colors.red[400] : Colors.green[400],
            size: 20,
          ),
        ),
        title: Text(
          data['nama_produk'],
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "${data['qty']} ${data['satuan']}",
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              data['tanggal'],
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              "Faktur: ${data['no_faktur']}",
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Dashboard Apotek',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Cards
              if (isLoading) _buildStatsLoading() else _buildStatsCards(),

              SizedBox(height: 24),

              // Inventory Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Stok Barang',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StokBarangPage(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size(50, 30),
                    ),
                    child: Text(
                      "Lihat Semua",
                      style: TextStyle(
                        color: Color(0xFF03A6A1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (isLoading)
                _buildInventoryLoading()
              else
                _buildInventoryCards(),

              SizedBox(height: 24),

              // Recent Incoming
              Text(
                'Barang Masuk Terbaru',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),
              if (isLoading)
                _buildRecentLoading()
              else
                ...recentMasuk.map((item) => _buildBarangCard(item)).toList(),

              SizedBox(height: 24),

              // Recent Outgoing
              Text(
                'Barang Keluar Terbaru',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),
              if (isLoading)
                _buildRecentLoading()
              else
                ...recentKeluar
                    .map((item) => _buildBarangCard(item, keluar: true))
                    .toList(),

              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.inventory_outlined,
            "Total",
            "$totalQty",
            Colors.blue,
          ),
          _buildStatItem(
            Icons.download_outlined,
            "Masuk",
            "$totalMasuk",
            Colors.green,
          ),
          _buildStatItem(
            Icons.upload_outlined,
            "Keluar",
            "$totalKeluar",
            Colors.orange,
          ),
          _buildStatItem(
            Icons.warning_amber_outlined,
            "Hampir Habis",
            "$hampirHabis",
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildInventoryCards() {
    return Container(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: inventoryItems.length,
        itemBuilder: (context, index) {
          final item = inventoryItems[index];
          return _buildInventoryCard(item);
        },
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final progressValue = item['stock'] / (item['total'] + 0.001);
    Color progressColor = Color(0xFF03A6A1);

    if (progressValue < 0.2) {
      progressColor = Colors.red[400]!;
    } else if (progressValue < 0.5) {
      progressColor = Colors.orange[400]!;
    }

    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Color(0xFF03A6A1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.medical_services_outlined,
                  size: 20,
                  color: Color(0xFF03A6A1),
                ),
              ),
              Text(
                item['stock'].toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            item['name'],
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.grey[800],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Text(
            "Kode: ${item['code']}",
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: progressValue,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            borderRadius: BorderRadius.circular(10),
            minHeight: 6,
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Tersedia",
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              Text(
                "${item['stock']} ${item['unit']}",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Loading Placeholders
  Widget _buildStatsLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            4,
            (index) => Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(height: 8),
                Container(width: 30, height: 16, color: Colors.white),
                SizedBox(height: 4),
                Container(width: 50, height: 12, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 180,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          itemBuilder: (context, index) => Container(
            width: 160,
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 32, height: 32, color: Colors.white),
                    Container(width: 30, height: 16, color: Colors.white),
                  ],
                ),
                SizedBox(height: 12),
                Container(width: 100, height: 16, color: Colors.white),
                SizedBox(height: 8),
                Container(width: 80, height: 12, color: Colors.white),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 6,
                  color: Colors.white,
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 40, height: 10, color: Colors.white),
                    Container(width: 40, height: 10, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(
          3,
          (index) => Card(
            margin: EdgeInsets.symmetric(vertical: 6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 120, height: 16, color: Colors.white),
                        SizedBox(height: 6),
                        Container(width: 80, height: 12, color: Colors.white),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(width: 60, height: 12, color: Colors.white),
                      SizedBox(height: 6),
                      Container(width: 80, height: 10, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
