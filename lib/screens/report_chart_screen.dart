import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:caffee/services/setting_session.dart';
import '../database/apihelper.dart';

class ReportChartScreen extends StatelessWidget {
  const ReportChartScreen({super.key});

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
        title: const Text('Grafik Pendapatan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4E342E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>?>(
        future: api.getRevenueChartReport(
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
                child: Text("Belum ada data pendapatan 7 hari terakhir."));
          }

          final rawData = snapshot.data!;

          // Konversi data API ke format koordinat grafik (FlSpot)
          List<FlSpot> spots = [];
          double maxRevenue = 100000; // Standar batas atas grafik harian

          for (int i = 0; i < rawData.length; i++) {
            double revenue =
                double.tryParse(rawData[i]['total_omset'].toString()) ?? 0.0;
            spots.add(FlSpot(i.toDouble(), revenue));
            if (revenue > maxRevenue) maxRevenue = revenue;
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tren Omset 7 Hari Terakhir (${SettingSession.id_cabang})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF4E342E)),
                ),
                const SizedBox(height: 24),

                // WIDGET UTAMA GRAFIK LINEAR ( fl_chart )
                SizedBox(
                  height: 300,
                  child: LineChart(
                    LineChartData(
                      gridData:
                          const FlGridData(show: true, drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < rawData.length) {
                                // Potong nama hari menjadi 3 huruf (e.g. Monday -> Mon)
                                String day = rawData[index]['nama_hari']
                                    .toString()
                                    .substring(0, 3);
                                return Text(day,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey));
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                              color: Colors.grey.shade300, width: 1)),
                      minX: 0,
                      maxX: (rawData.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxRevenue *
                          1.2, // Beri ruang kosong 20% di atas titik tertinggi
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xFF2E7D32),
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF2E7D32).withOpacity(0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const Text('Rincian Nominal Harian:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),

                // LIST DAFTAR TULISAN DI BAWAH GRAFIK
                Expanded(
                  child: ListView.builder(
                    itemCount: rawData.length,
                    itemBuilder: (context, idx) {
                      final dayData = rawData[idx];
                      double totalDay =
                          double.tryParse(dayData['total_omset'].toString()) ??
                              0;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(dayData['nama_hari'].toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text(dayData['tanggal'].toString(),
                              style: const TextStyle(fontSize: 11)),
                          trailing: Text(
                            formatRupiah(totalDay),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
