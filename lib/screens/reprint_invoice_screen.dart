import 'package:caffee/services/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:caffee/services/setting_session.dart';
import '../database/apihelper.dart';

class ReprintInvoiceScreen extends StatefulWidget {
  const ReprintInvoiceScreen({super.key});

  @override
  State<ReprintInvoiceScreen> createState() => _ReprintInvoiceScreenState();
}

class _ReprintInvoiceScreenState extends State<ReprintInvoiceScreen> {
  ApiHelper API = new ApiHelper();
  final PrinterService _printerService = PrinterService();
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  BluetoothInfo? _savedPrinter;

  final formatRupiah =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchHistoryToday();
    _checkConnectedPrinter();
  }

  // Cek apakah ada printer yang aktif tersimpan di memori
  // Cek apakah ada printer yang aktif tersimpan di memori
  Future<void> _checkConnectedPrinter() async {
    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (isConnected) {
      // SOLUSI MUTLAK: Gunakan instans printer service lokal yang sudah pasti kompatibel
      List<BluetoothInfo> devices = await _printerService.getDevices();
      if (devices.isNotEmpty) {
        setState(() {
          _savedPrinter =
              devices.first; // Ambil perangkat pertama yang terdeteksi aktif
        });
      }
    }
  }

  // Ambil data riwayat transaksi hari ini dari API MySQL
  Future<void> _fetchHistoryToday() async {
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
        throw Exception('Gagal memuat data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal terhubung ke server: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  // =========================================================================
  // LOGIKA ASINKRON REPRINT: CONNECT -> PRINT REPRINT -> DISCONNECT
  // =========================================================================
  Future<void> _prosesReprintNota(Map<String, dynamic> trx) async {
    // 1. Cek status koneksi persisten printer di halaman utama secara real-time
    bool isPrinterReady = await PrintBluetoothThermal.connectionStatus;

    if (!isPrinterReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Printer tidak terhubung! Silakan aktifkan koneksi di menu utama.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      // 2. SOLUSI MANFAAT NESTED JSON: Tarik langsung data array item dari objek trx['items']
      // Tidak perlu lagi memanggil http.get() terpisah untuk mendongkrak performa aplikasi
      List<dynamic> items = trx['items'] ?? [];

      final CapabilityProfile profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      String sline = "------------------------------------------------";
      const int maxKarakterBaris = 48;

      // Desain Teks Header Salinan Struk
      bytes += generator.text(SettingSession.nama_cabang,
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text(SettingSession.alamat_cabang,
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text("*** SALINAN NOTA / REPRINT ***",
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text("${DateTime.now().toString().substring(0, 16)}",
          styles: const PosStyles(align: PosAlign.center, bold: false));
      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));

      bytes += generator.text("No Bill   : ${trx['no_faktur']}");
      bytes += generator.text("Tanggal   : ${trx['tanggal_transaksi']}");
      bytes += generator.text("Kasir     : ${trx['nama_lengkap']}");
      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));

      // Looping Daftar Item Belanjaan Salinan (Rata Kanan-Kiri presisi 48 karakter)
      for (var item in items) {
        int qty = int.tryParse(item['quantity'].toString()) ?? 0;
        double hargaSatuan =
            double.tryParse(item['harga_satuan'].toString()) ?? 0.0;

// Lakukan operasi perkalian matematika kotor (Qty x Harga Satuan)
        double subtotalKotor = qty * hargaSatuan;

        String textLeft = " ${item['quantity']}x ${item['name']}";
        String textRight = formatRupiah.format(subtotalKotor);

        int spaceCount =
            maxKarakterBaris - (textLeft.length + textRight.length);
        String spaces = ' ' * (spaceCount < 1 ? 1 : spaceCount);
        bytes += generator.text("$textLeft$spaces$textRight");
        int diskonPersen = int.tryParse(item['diskon_persen'].toString()) ?? 0;

        if (diskonPersen > 0) {
          // Menampilkan baris rincian nilai potongan rupiah di bawah nama menu
          String textDiscLeft = "   Disc $diskonPersen%";

          // Ambil nominal rupiah diskon dari kolom diskon_amount yang baru saja kita ubah
          double diskonAmount =
              double.tryParse(item['diskon_amount'].toString()) ?? 0.0;
          String textDiscRight = "-${formatRupiah.format(diskonAmount)}";

          int spaceDiscCount =
              maxKarakterBaris - (textDiscLeft.length + textDiscRight.length);
          String spacesDisc = ' ' * (spaceDiscCount < 1 ? 1 : spaceDiscCount);

          bytes += generator.text(
              "$textDiscLeft$spacesDisc$textDiscRight" // Opsional: Beri warna pembeda di struk
              );
        }
      }

      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));

      // Hitung dan Cetak Ringkasan Finansial Nota Belanja
      double total = double.tryParse(trx['total_pembayaran'].toString()) ?? 0.0;
      double bayar = double.tryParse(trx['uang_tunai'].toString()) ?? 0.0;
      double change = double.tryParse(trx['uang_kembalian'].toString()) ?? 0.0;
      double diskon = double.tryParse(trx['diskon'].toString()) ?? 0.0;
      double tax = double.tryParse(trx['tax'].toString()) ?? 0.0;

      if (tax > 0) {
        bytes += generator.row([
          PosColumn(
              text: "PAJAK:", width: 6, styles: const PosStyles(bold: true)),
          PosColumn(
            text: formatRupiah.format(tax),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true), // Perbaikan posisi di sini
          ),
        ]);
      }

      bytes += generator.row([
        PosColumn(
            text: "TOTAL:", width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: formatRupiah.format(total),
          width: 6,
          styles: const PosStyles(
              align: PosAlign.right, bold: true), // Perbaikan posisi di sini
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: "BAYAR:", width: 6),
        PosColumn(
          text: formatRupiah.format(bayar),
          width: 6,
          styles: const PosStyles(
              align: PosAlign.right), // Perbaikan posisi di sini
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: "KEMBALI:", width: 6),
        PosColumn(
          text: formatRupiah.format(change),
          width: 6,
          styles: const PosStyles(
              align: PosAlign.right), // Perbaikan posisi di sini
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: "METODE:", width: 6),
        PosColumn(
          text: trx['metode_pembayaran'],
          width: 6,
          styles: const PosStyles(
              align: PosAlign.right), // Perbaikan posisi di sini
        ),
      ]);

      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text("Terima Kasih Atas Kunjungan Anda",
          styles: const PosStyles(align: PosAlign.center));

      bytes += generator.feed(3);
      bytes.addAll([29, 86, 66, 0]); // Perintah mekanis Auto-Cut Blueprint 80mm

      // LANGSUNG TEMBAK DATA KE PRINTER YANG SEDANG STAND-BY AKTIF
      await PrintBluetoothThermal.writeBytes(bytes);
      await ApiHelper.saveReprintLog(
        noFaktur: trx['no_faktur'].toString(),
        idUser: SettingSession.id_user,
        idCabang: SettingSession.id_cabang,
        urlApi: SettingSession.url_api,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Nota ${trx['no_faktur']} Sukses Dicetak Ulang!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Gagal melakukan reprint persisten: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Reprint Nota Transaksi',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4E342E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistoryToday,
            tooltip: 'Segarkan Data',
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4E342E)))
          : _transactions.isEmpty
              ? const Center(
                  child: Text('Belum ada transaksi keluar untuk hari ini.',
                      style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _fetchHistoryToday,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final trx = _transactions[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.15),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.receipt_long_rounded,
                                color: Colors.purple),
                          ),
                          title: Text(
                            'No. Faktur: ${trx['no_faktur']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4E342E)),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Waktu: ${trx['tanggal_transaksi']}'),
                              Text(
                                  'Kasir: ${trx['nama_lengkap']} • ${trx['metode_pembayaran']}'),
                              const SizedBox(height: 4),
                              Text(
                                formatRupiah.format(double.tryParse(
                                        trx['total_pembayaran'].toString()) ??
                                    0.0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 15),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4E342E),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.print_rounded,
                                size: 16, color: Colors.white),
                            label: const Text('Print',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            onPressed: () => _prosesReprintNota(trx),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
