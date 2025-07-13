import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  // Dummy data
  final List<InventoryItem> inventoryItems = [
    InventoryItem("Paracetamol 500mg", "OBT-001", 150, 25, 175, "Tablet"),
    InventoryItem("Amoxicillin 500mg", "OBT-002", 80, 20, 100, "Kapsul"),
    InventoryItem("Cetirizine 10mg", "OBT-003", 120, 30, 150, "Tablet"),
    InventoryItem("Omeprazole 20mg", "OBT-004", 90, 10, 100, "Kapsul"),
    InventoryItem("Vitamin C 500mg", "OBT-005", 200, 50, 250, "Tablet"),
  ];

  final List<StockRequest> stockRequests = [
    StockRequest("REQ-001", "Paracetamol 500mg", 50, "Pending"),
    StockRequest("REQ-002", "Amoxicillin 500mg", 30, "Diproses"),
    StockRequest("REQ-003", "Vitamin C 500mg", 100, "Selesai"),
  ];

  final List<StockReceipt> stockReceipts = [
    StockReceipt("REC-001", "Paracetamol 500mg", 25, "12/06/2023"),
    StockReceipt("REC-002", "Omeprazole 20mg", 10, "10/06/2023"),
    StockReceipt("REC-003", "Cetirizine 10mg", 30, "08/06/2023"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Dashboard Apotek'),
        centerTitle: true,
        backgroundColor: const Color(0xFF03A6A1),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with stats
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF03A6A1), Color(0xFF0288A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(Icons.inventory, "Total Obat", "1,245"),
                  _buildStatItem(Icons.request_page, "Permintaan", "24"),
                  _buildStatItem(Icons.local_shipping, "Penerimaan", "15"),
                  _buildStatItem(Icons.warning, "Hampir Habis", "8"),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Quick Actions
            Text('Aksi Cepat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Row(
              children: [
                _buildQuickAction(Icons.add, "Tambah Obat", Colors.green),
                _buildQuickAction(Icons.search, "Cari Obat", Colors.blue),
                _buildQuickAction(Icons.barcode_reader, "Scan Barcode", Colors.orange),
                _buildQuickAction(Icons.report, "Laporan", Colors.purple),
              ],
            ),
            SizedBox(height: 25),

            // Inventory Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Stok Obat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  child: Text('Lihat Semua', style: TextStyle(color: Color(0xFF03A6A1))),
                  onPressed: () {},
                ),
              ],
            ),
            SizedBox(height: 10),
            Container(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: inventoryItems.length,
                itemBuilder: (context, index) {
                  return _buildInventoryCard(inventoryItems[index]);
                },
              ),
            ),
            SizedBox(height: 25),

            // Two columns layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stock Requests
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Permintaan Barang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton(
                            child: Text('Lihat Semua', style: TextStyle(color: Color(0xFF03A6A1), fontSize: 12)),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: stockRequests.map((request) => _buildRequestItem(request)).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 15),

                // Recent Receipts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Penerimaan Terakhir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton(
                            child: Text('Lihat Semua', style: TextStyle(color: Color(0xFF03A6A1), fontSize: 12)),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: stockReceipts.map((receipt) => _buildReceiptItem(receipt)).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Color(0xFF03A6A1),
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String title, String value) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white),
        ),
        SizedBox(height: 5),
        Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(title, style: TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color) {
    return Expanded(
      child: InkWell(
        onTap: () {},
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(height: 5),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[800]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 15),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, 2),
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
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.medical_services, size: 20, color: Color(0xFF03A6A1)),
              ),
              Text(item.stock.toString(), style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 10),
          Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 5),
          Text("Kode: ${item.code}", style: TextStyle(fontSize: 12, color: Colors.grey)),
          SizedBox(height: 10),
          LinearProgressIndicator(
            value: item.stock / (item.stock + 50), // dummy max value
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF03A6A1)),
          ),
          SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Tersedia", style: TextStyle(fontSize: 10)),
              Text("${item.stock} ${item.unit}", style: TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestItem(StockRequest request) {
    Color statusColor;
    switch (request.status) {
      case "Pending":
        statusColor = Colors.orange;
        break;
      case "Diproses":
        statusColor = Colors.blue;
        break;
      case "Selesai":
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.itemName, style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text("ID: ${request.requestId}", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(request.quantity.toString(), style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  request.status,
                  style: TextStyle(color: statusColor, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptItem(StockReceipt receipt) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF03A6A1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(receipt.itemName, style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text("ID: ${receipt.receiptId}", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(receipt.quantity.toString(), style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 2),
              Text(receipt.date, style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

// Data Models
class InventoryItem {
  final String name;
  final String code;
  final int stock;
  final int incoming;
  final int total;
  final String unit;

  InventoryItem(this.name, this.code, this.stock, this.incoming, this.total, this.unit);
}

class StockRequest {
  final String requestId;
  final String itemName;
  final int quantity;
  final String status;

  StockRequest(this.requestId, this.itemName, this.quantity, this.status);
}

class StockReceipt {
  final String receiptId;
  final String itemName;
  final int quantity;
  final String date;

  StockReceipt(this.receiptId, this.itemName, this.quantity, this.date);
}