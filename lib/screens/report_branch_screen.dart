import 'package:flutter/material.dart';
import 'package:caffee/services/setting_session.dart';
import '../database/apihelper.dart';

class ReportBranchScreen extends StatelessWidget {
  const ReportBranchScreen({super.key});

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
        title: const Text('Performa per-Cabang',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4E342E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>?>(
        // Ubah pemanggilan future menjadi:
        future: api.getBranchPerformanceReport(
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
                child: Text("Tidak ada data performa cabang hari ini."));
          }

          final branches = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: branches.length,
            itemBuilder: (context, idx) {
              final branch = branches[idx];
              double total =
                  double.tryParse(branch['omset_total'].toString()) ?? 0;
              double tunai =
                  double.tryParse(branch['omset_tunai'].toString()) ?? 0;
              double qris =
                  double.tryParse(branch['omset_qris'].toString()) ?? 0;

              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              branch['nama_cabang'].toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF4E342E)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              branch['id_cabang'].toString(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      Text(branch['alamat_cabang'].toString(),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('💵 Omset Tunai:',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black54)),
                          Text(formatRupiah(tunai),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('📱 Omset QRIS:',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black54)),
                          Text(formatRupiah(qris),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('📈 Total Pendapatan:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            formatRupiah(total),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF2E7D32)),
                          ),
                        ],
                      ),
                    ],
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
