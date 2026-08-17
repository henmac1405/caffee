import 'package:flutter/material.dart';

class ReportMenuScreen extends StatelessWidget {
  const ReportMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Pusat Administrasi & Laporan',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4E342E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildMenuCard(
              context,
              title: 'Laporan Omset\nper-Shift',
              icon: Icons.assignment_turned_in_rounded,
              color: Colors.orange,
              route: '/report',
            ),
            _buildMenuCard(
              context,
              title: 'Penjualan\nper-Produk',
              icon: Icons.coffee_rounded,
              color: Colors.brown,
              route: '/report_product',
            ),
            _buildMenuCard(
              context,
              title: 'Performansi\nper-Cabang',
              icon: Icons.storefront_rounded,
              color: Colors.blue,
              route: '/report_branch',
            ),
            _buildMenuCard(
              context,
              title: 'Grafik\nPendapatan',
              icon: Icons.bar_chart_rounded,
              color: Colors.green,
              route: '/report_chart',
            ),
            _buildMenuCard(
              context,
              title: 'Reprint Nota\nTransaksi',
              icon: Icons.print_rounded,
              color: Colors.purple,
              route: '/reprint_invoice',
            ),
            _buildMenuCard(
              context,
              title: 'Void / Hapus\nTransaksi',
              icon: Icons.delete_forever_rounded,
              color: Colors.red,
              route: '/void_transaction',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required String route}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        onTap: () {
          // PERBAIKAN: Navigasi langsung tanpa interseptor dialog login lagi
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF4E342E)),
            ),
          ],
        ),
      ),
    );
  }
}
