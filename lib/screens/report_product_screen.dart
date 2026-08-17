import 'package:flutter/material.dart';
import 'package:caffee/services/setting_session.dart';
import '../database/apihelper.dart';

class ReportProductScreen extends StatelessWidget {
  const ReportProductScreen({super.key});

  String formatRupiah(double nominal) {
    String valueString = nominal.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${valueString.replaceAllMapped(reg, (Match match) => '${match.group(1)}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final ApiHelper api = ApiHelper();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Penjualan per-Produk',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4E342E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>?>(
        // Ubah pemanggilan future menjadi:
        future: api.getProductPerformanceReport(
            SettingSession.id_cabang, SettingSession.url_api),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4E342E)));
          }
          if (!snapshot.hasData ||
              snapshot.data == null ||
              snapshot.data!.isEmpty) {
            return const Center(
                child: Text("Belum ada transaksi produk hari ini."));
          }

          final products = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: products.length,
            itemBuilder: (context, idx) {
              final product = products[idx];
              double omset =
                  double.tryParse(product['total_omset'].toString()) ?? 0;
              int qty = int.tryParse(product['total_terjual'].toString()) ?? 0;

              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEFEBE9),
                    radius: 24,
                    child: Text(
                      product['icon_produk'] ?? '☕',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  title: Text(
                    product['nama_produk'].toString(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF4E342E)),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Kategori: ${product['kategori_produk']}\nTotal Omset: ${formatRupiah(omset)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$qty Terjual',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
