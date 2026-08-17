import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../database/apihelper.dart'; // Sesuaikan folder helper Anda
import 'package:caffee/services/setting_session.dart';

// Penampung Sesi Global Anda

class VoidTransactionScreen extends StatefulWidget {
  const VoidTransactionScreen({super.key});

  @override
  State<VoidTransactionScreen> createState() => _VoidTransactionScreenState();
}

class _VoidTransactionScreenState extends State<VoidTransactionScreen> {
  ApiHelper API = new ApiHelper();
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  final formatRupiah =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchTransactionsToday();
  }

  // Tarik daftar riwayat belanja hari ini via API untuk cabang terkait
  Future<void> _fetchTransactionsToday() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse(
            '${SettingSession.url_api}transaction/history_today?id_cabang=${SettingSession.id_cabang}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _transactions = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Gagal menarik data nota');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _tampilkanSnackBar('Eror koneksi server: $e', Colors.red);
    }
  }

  // FUNGSI CEK STATUS DAN PENCETAKAN STRUK FISIK BUKTI VOID (KONEKSI PERSISTEN)
  Future<void> _cetakStrukBuktiVoid(
      Map<String, dynamic> faktur, List<dynamic> items) async {
    bool isPrinterReady = await PrintBluetoothThermal.connectionStatus;
    if (!isPrinterReady) {
      _tampilkanSnackBar(
          'Data terhapus, namun gagal cetak struk karena printer tidak terhubung!',
          Colors.orange);
      return;
    }

    try {
      final CapabilityProfile profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      String sline = "------------------------------------------------";
      const int maxKarakterBaris = 48;

      // Desain Kepala Struk Penanda Void Kasir
      bytes += generator.text(SettingSession.nama_cabang,
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text("!!! DIBATALKAN / VOID !!!",
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));

      bytes += generator.text("No Bill: ${faktur['no_faktur']}");
      bytes += generator
          .text("Waktu Void: ${DateTime.now().toString().substring(0, 16)}");
      bytes +=
          generator.text("Otorisasi : ${SettingSession.id_user.toUpperCase()}");
      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));

      // Looping Daftar Item Menu yang Dibatalkan
      for (var item in items) {
        int qty = int.tryParse(item['quantity'].toString()) ?? 0;
        double harga = double.tryParse(item['harga_satuan'].toString()) ?? 0.0;
        double subtotal = qty * harga;

        String textLeft = " [VOID] ${qty}x ${item['name']}";
        String textRight = formatRupiah.format(subtotal);

        int spaceCount =
            maxKarakterBaris - (textLeft.length + textRight.length);
        String spaces = ' ' * (spaceCount < 1 ? 1 : spaceCount);
        bytes += generator.text("$textLeft$spaces$textRight");
      }

      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));

      double total =
          double.tryParse(faktur['total_pembayaran'].toString()) ?? 0.0;
      bytes += generator.text(
          "TOTAL VOID RUPIAH : ${formatRupiah.format(total)}",
          styles: const PosStyles(bold: true));
      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text("Dokumen Audit Internal Toko",
          styles: const PosStyles(align: PosAlign.center));

      bytes += generator.feed(3);
      bytes.addAll([29, 86, 66, 0]); // Auto-Cut pisau mekanis Blueprint 80mm

      // Langsung semburlan bytes ke hardware karena koneksi di halaman utama menetap/persisten
      await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint("Gagal mencetak struk void: $e");
    }
  }

  // FUNGSI UTAMA CALL APIHELPER VOID POST
  Future<void> _prosesVoidTransaksi(String idTransaksi) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          const Center(child: CircularProgressIndicator(color: Colors.red)),
    );

    // Memanggil fungsi POST terpusat dari ApiHelper Anda
    var response = await ApiHelper.executeVoid(
      idTransaksi: idTransaksi,
      idAdmin: SettingSession.id_user,
      urlApi: SettingSession.url_api,
    );

    if (mounted) Navigator.pop(context); // Tutup loading spinner

    if (response != null && response['status'] == true) {
      _tampilkanSnackBar(response['message'], Colors.green);

      // PICU PRINT OTOMATIS: Ambil manifest lampiran data dari response server
      Map<String, dynamic> fakturData = response['data_faktur'] ?? {};
      List<dynamic> itemsData = response['data_items'] ?? [];

      await _cetakStrukBuktiVoid(fakturData, itemsData);

      _fetchTransactionsToday(); // Segarkan data agar nota langsung lenyap dari list view screen
    } else {
      _tampilkanSnackBar(
          'Gagal memproses pembatalan nota transaksi.', Colors.red);
    }
  }

  void _showKonfirmasiVoidDialog(Map<String, dynamic> trx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text('Void Nota #${trx['no_faktur']}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan transaksi ini secara permanen? Tindakan ini akan menghapus omset dari laporan dan printer akan mengeluarkan bukti void fisik.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _prosesVoidTransaksi(trx['id_transaksi'].toString());
            },
            child: const Text('Ya, Void Nota',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _tampilkanSnackBar(String pesan, Color warna) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(pesan), backgroundColor: warna));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Void / Pembatalan Transaksi',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4E342E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _transactions.isEmpty
              ? const Center(
                  child: Text(
                      'Tidak ada riwayat transaksi aktif yang bisa di-void hari ini.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center))
              : RefreshIndicator(
                  onRefresh: _fetchTransactionsToday,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final trx = _transactions[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.12),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.delete_sweep_rounded,
                                color: Colors.red),
                          ),
                          title: Text(
                            'Faktur: ${trx['no_faktur']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4E342E)),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                  'Jam: ${trx['tanggal_transaksi'].toString().substring(11, 16)} • Kasir: ${trx['nama_lengkap']}'),
                              const SizedBox(height: 4),
                              Text(
                                formatRupiah.format(double.tryParse(
                                        trx['total_pembayaran'].toString()) ??
                                    0.0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red, size: 28),
                            tooltip: 'Void Transaksi',
                            onPressed: () => _showKonfirmasiVoidDialog(trx),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
