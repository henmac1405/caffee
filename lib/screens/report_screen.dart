import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caffee/services/setting_session.dart'; // Pastikan package import sudah sesuai
import '../services/shift_provider.dart';
import '../database/apihelper.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  String formatRupiah(double nominal) {
    String valueString = nominal.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${valueString.replaceAllMapped(reg, (Match match) => '${match.group(1)}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final ApiHelper api = ApiHelper();
    final shiftProvider = Provider.of<ShiftProvider>(context);
    int currentShiftId = shiftProvider.activeShiftId ?? 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Laporan Omset Shift',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4E342E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: api.getShiftReport(
            currentShiftId, SettingSession.id_cabang, SettingSession.url_api),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4E342E)));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
                child: Text(
                    "Gagal memuat ringkasan omset shift aktif cabang ini."));
          }

          final report = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PANEL UTAMA DETAIL SHIFT
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Shift ID: #$currentShiftId',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.brown.shade50,
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(SettingSession.id_cabang,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4E342E))),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Text('Kasir : ${report['kasir'] ?? "-"}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Waktu Buka   : ${report['waktu_buka'] ?? "-"}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // DATA KAS DASAR
                _buildReportCard('💵 Modal Awal Laci', report['modal_awal']),
                _buildReportCard('☕ Omset Tunai Shift', report['omset_tunai']),
                _buildReportCard('📱 Omset QRIS Shift', report['omset_qris']),
                _buildReportCard(
                    '📉 Potongan Diskon Keluar', report['total_diskon'],
                    isRed: true),
                _buildReportCard(
                    '❌ Void Transaksi ${report['total_void_count']}x',
                    report['total_void_amount'],
                    isRed: true),
                const Divider(height: 24, thickness: 1.5),
                _buildReportCard(
                    '💰 Total Seharusnya Di Laci', report['total_laci'],
                    isBold: true),

                // =========================================================
                // INDIKATOR BARU 1: TOTAL PENDAPATAN PER KASIR / ID_USER
                // =========================================================
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('👥 Omset Pendapatan per-Kasir',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF4E342E))),
                ),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: (report['info_sales_user'] as List).map((u) {
                        double totalUser =
                            double.tryParse(u['total'].toString()) ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('ID User: ${u['id_user']}',
                                  style: const TextStyle(fontSize: 13)),
                              Text(formatRupiah(totalUser),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // =========================================================
                // INDIKATOR BARU 2: TOTAL PENJUALAN KATEGORI PER PRODUK
                // =========================================================
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('📊 Kuantitas & Omset per-Produk',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF4E342E))),
                ),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: (report['info_sales_product'] as List).map((p) {
                        double totalProd =
                            double.tryParse(p['total'].toString()) ?? 0;
                        int qtyProd = int.tryParse(p['qty'].toString()) ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: Text('${p['name']} (x$qtyProd)',
                                      style: const TextStyle(fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                              Text(formatRupiah(totalProd),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportCard(String title, dynamic amount,
      {bool isRed = false, bool isBold = false}) {
    double value = double.tryParse(amount.toString()) ?? 0.0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13)),
            Text(
              formatRupiah(value),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isBold ? 16 : 14,
                  color: isRed
                      ? Colors.red
                      : (isBold ? const Color(0xFF2E7D32) : Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }
}
