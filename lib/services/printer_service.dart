import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../providers/pos_provider.dart';
import 'package:caffee/services/setting_session.dart';

class PrinterService {
  // Mengambil daftar printer terdekat (Termasuk BLE)
  Future<List<BluetoothInfo>> getDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  String formatRupiah(double nominal) {
    String valueString = nominal.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${valueString.replaceAllMapped(reg, (Match match) => '${match.group(1)}.')}';
  }

  // Fungsi cetak struk kasir fisik via BLE bytes
  Future<void> printReceipt(PosProvider posProvider, double cashAmount,
      double change, String nomorFaktur) async {
    String sline = "------------------------------------------------";
    String strRow = "";
    String strRowPrint = "";
    int irow = 0;
    int ipaper = 48;
    int isisa = 0;
    double discountPerUnit = 0;
    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) return;
    final formatRupiah =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final CapabilityProfile profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Judul & Header Struk
    bytes += generator.text(SettingSession.nama_cabang,
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(SettingSession.alamat_cabang,
        styles: const PosStyles(align: PosAlign.center));
    bytes +=
        generator.text(sline, styles: const PosStyles(align: PosAlign.center));

    bytes += generator.text("No Bill : $nomorFaktur");
    bytes += generator
        .text("Tanggal : ${DateTime.now().toString().substring(0, 16)}");
    bytes += generator.text("Kasir   : ${SettingSession.nama_lengkap}");

    // bytes += generator.text("Metode  : ${posProvider.paymentMethod}");
    bytes +=
        generator.text(sline, styles: const PosStyles(align: PosAlign.center));

    // List Pesanan Pelanggan
    for (var item in posProvider.cart) {
      strRow =
          "${item.quantity}x ${item.name} ${formatRupiah.format((item.price * item.quantity))}";
      irow = strRow.length;
      isisa = ipaper - irow;
      String spasi = ' ' * isisa;
      strRowPrint =
          "${item.quantity}x ${item.name}${spasi} ${formatRupiah.format((item.price * item.quantity))}";

      bytes += generator.text(strRowPrint);

      //KLO ADA DISKON
      if (item.discountPercent > 0) {
        discountPerUnit = item.price * (item.discountPercent / 100);
        strRow =
            "   Disc ${item.discountPercent}% -${formatRupiah.format((discountPerUnit * item.quantity))}";
        irow = strRow.length;
        isisa = ipaper - irow;
        String spasi = ' ' * isisa;
        strRowPrint =
            "   Disc ${item.discountPercent}%${spasi} -${formatRupiah.format((discountPerUnit * item.quantity))}";
        bytes += generator.text(strRowPrint);
      }

      // bytes += generator.row([
      //   PosColumn(
      //     text:
      //         "${item.quantity}x ${item.name} RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRp ${(item.price * item.quantity).toStringAsFixed(0)}",
      //     // "${item.quantity}x ${item.name}${spasi}Rp ${(item.price * item.quantity).toStringAsFixed(0)}",
      //     width: 12,
      //     styles: const PosStyles(align: PosAlign.left),
      //   ),
      // ]);
    }

    // Informasi Pembayaran & Kembalian
    bytes +=
        generator.text(sline, styles: const PosStyles(align: PosAlign.center));
    if (posProvider.totalTax > 0) {
      bytes += generator.row([
        PosColumn(
            text: "PAJAK:", width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: formatRupiah.format(posProvider.totalTax),
          width: 6,
          styles: const PosStyles(
              align: PosAlign.right, bold: true), // Perbaikan posisi di sini
        ),
      ]);
    }
    bytes += generator.row([
      PosColumn(text: "TOTAL:", width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: formatRupiah.format(posProvider.finalTotalWithTax),
        width: 6,
        styles: const PosStyles(
            align: PosAlign.right, bold: true), // Perbaikan posisi di sini
      ),
    ]);
    bytes += generator.row([
      PosColumn(text: "BAYAR:", width: 6),
      PosColumn(
        text: formatRupiah.format(cashAmount),
        width: 6,
        styles:
            const PosStyles(align: PosAlign.right), // Perbaikan posisi di sini
      ),
    ]);
    bytes += generator.row([
      PosColumn(text: "KEMBALI:", width: 6),
      PosColumn(
        text: formatRupiah.format(change),
        width: 6,
        styles:
            const PosStyles(align: PosAlign.right), // Perbaikan posisi di sini
      ),
    ]);
    bytes += generator.row([
      PosColumn(text: "METODE:", width: 6),
      PosColumn(
        text: posProvider.paymentMethod,
        width: 6,
        styles:
            const PosStyles(align: PosAlign.right), // Perbaikan posisi di sini
      ),
    ]);

    // Footer Struk
    bytes +=
        generator.text(sline, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text("Terima Kasih Atas Kunjungan Anda",
        styles: const PosStyles(align: PosAlign.center));

    bytes += generator.feed(2);

    bytes.addAll([29, 86, 66, 0]);

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<void> printShiftReport(
      Map<String, dynamic> report, String username) async {
    try {
      // 1. Validasi awal status koneksi persisten printer Anda
      bool isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        //debugPrint("Printer tidak aktif tersambung!");
        return;
      }

      final formatRupiah = NumberFormat.currency(
          locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

      // Pembatas garis disesuaikan dengan lebar kertas 80mm (48 Karakter)
      String sline = "------------------------------------------------";
      const int maxKarakterBaris = 48;

      final CapabilityProfile profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // Judul & Header Struk (PERBAIKAN: Pastikan string aman dari null)
      bytes += generator.text(SettingSession.nama_cabang ?? 'CAFE DIGITAL',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text(SettingSession.alamat_cabang ?? '',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text("LAPORAN RINGKASAN TUTUP SHIFT",
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));

      bytes += generator.text("Shift ID : #${report['id_shift'] ?? '-'}");
      bytes += generator.text("Kasir    : $username");
      bytes += generator
          .text("Waktu    : ${DateTime.now().toString().substring(0, 16)}");
      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));

      // DATA FINANSIAL UTAMA SHIFT (Aman dari kegagalan format data database)
      double modalAwal =
          double.tryParse(report['modal_awal'].toString()) ?? 0.0;
      double omsetTunai =
          double.tryParse(report['total_tunai'].toString()) ?? 0.0;
      double omsetQris =
          double.tryParse(report['total_qris'].toString()) ?? 0.0;
      double totalDiskon =
          double.tryParse(report['total_diskon'].toString()) ?? 0.0;
      double totalTax = double.tryParse(report['total_tax'].toString()) ?? 0.0;
      double totalLaci =
          double.tryParse(report['total_laci'].toString()) ?? 0.0;

      double voidamount =
          double.tryParse(report['total_void_amount'].toString()) ?? 0.0;

      bytes += generator
          .text("Modal Awal Laci  : ${formatRupiah.format(modalAwal)}");
      bytes += generator
          .text("Omset Tunai Shift: ${formatRupiah.format(omsetTunai)}");
      bytes += generator
          .text("Omset QRIS Shift : ${formatRupiah.format(omsetQris)}");
      bytes += generator.text(
          "${report['total_void_count']}x Void : ${formatRupiah.format(voidamount)}");
      if (totalTax > 0) {
        bytes += generator
            .text("Total Pajak (Tax): ${formatRupiah.format(voidamount)}");
      }
      if (totalDiskon > 0) {
        bytes += generator
            .text("Potongan Diskon  : -${formatRupiah.format(totalDiskon)}");
      }
      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));

      bytes += generator.text(
          "Total Seharusnya Di Laci: ${formatRupiah.format(totalLaci)}",
          styles: const PosStyles(bold: true));
      bytes += generator.text(sline,
          styles: const PosStyles(align: PosAlign.center));

      // =========================================================================
      // INDIKATOR BARU 1: OMSET PENDAPATAN PER KASIR / ID_USER (RATA KANAN-KIRI)
      // =========================================================================
      if (report['info_sales_user'] != null) {
        try {
          var userList = report['info_sales_user'] as List;
          if (userList.isNotEmpty) {
            // PERBAIKAN: Hapus emoji dari teks agar tidak memicu sirkuit driver printer Blueprint crash
            bytes += generator.text("Omset Pendapatan per-Kasir:",
                styles: const PosStyles(bold: true));

            for (var u in userList) {
              if (u != null) {
                String textLeft = " ID User: ${u['id_user'] ?? '-'}";
                String textRight = formatRupiah
                    .format(double.tryParse(u['total'].toString()) ?? 0.0);

                int spaceCount =
                    maxKarakterBaris - (textLeft.length + textRight.length);
                String spaces = ' ' * (spaceCount < 1 ? 1 : spaceCount);

                bytes += generator.text("$textLeft$spaces$textRight");
              }
            }
            bytes += generator.text(sline,
                styles: const PosStyles(align: PosAlign.center));
          }
        } catch (e) {
          //debugPrint("Gagal urai list user: $e");
        }
      }

      // =========================================================================
      // INDIKATOR BARU 2: KUANTITAS & OMSET PER-PRODUK (RATA KANAN-KIRI)
      // =========================================================================
      if (report['info_sales_product'] != null) {
        try {
          var productList = report['info_sales_product'] as List;
          if (productList.isNotEmpty) {
            bytes += generator.text("Kuantitas & Omset per-Produk:",
                styles: const PosStyles(bold: true));

            for (var p in productList) {
              if (p != null) {
                int qty = int.tryParse(p['qty'].toString()) ?? 0;
                String textLeft = " ${p['name'] ?? '-'} (x$qty)";
                String textRight = formatRupiah
                    .format(double.tryParse(p['total'].toString()) ?? 0.0);

                int spaceCount =
                    maxKarakterBaris - (textLeft.length + textRight.length);
                String spaces = ' ' * (spaceCount < 1 ? 1 : spaceCount);

                bytes += generator.text("$textLeft$spaces$textRight");
              }
            }
            bytes += generator.text(sline,
                styles: const PosStyles(align: PosAlign.center));
          }
        } catch (e) {
          //debugPrint("Gagal urai list produk: $e");
        }
      }

      // INTEGRASI AUDIT SELISIH FISIK LACI KASIR
      if (report['uang_aktual'] != null) {
        double uangAktual =
            double.tryParse(report['uang_aktual'].toString()) ?? 0.0;
        double selisih = double.tryParse(report['selisih'].toString()) ?? 0.0;

        bytes += generator
            .text("Uang Aktual Laci  : ${formatRupiah.format(uangAktual)}");
        bytes += generator.text(
            "Selisih Laci      : ${formatRupiah.format(selisih)}",
            styles: const PosStyles(bold: true));
        bytes += generator.text(sline,
            styles: const PosStyles(align: PosAlign.center));
      }

      bytes += generator.text("Laporan Tutup Shift Sukses Diunggah.",
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text("Sistem CMS & POS Cafe V1",
          styles: const PosStyles(align: PosAlign.center));

      // Mekanisme Potong Kertas Otomatis Blueprint 80mm
      bytes += generator.feed(3);
      bytes.addAll([29, 86, 66, 0]); // Perintah Auto-Cut fisik hardware

      // TEMBAK DATA KE PRINTER YANG SEDANG AKTIF TERHUBUNG (PERSISTEN)
      await PrintBluetoothThermal.writeBytes(bytes);
      //debugPrint("Laporan ringkasan shift sukses dialirkan ke printer!");
    } catch (e) {
      // PERBAIKAN: Aktifkan debugger console agar Anda tahu di baris mana letak crash data aslinya
      //debugPrint("Gagal total cetak laporan shift: $e");
    }
  }

  Future<void> printShiftReport_(
      Map<String, dynamic> report, String username) async {
    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) return;
    final formatRupiah =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    String sline = "------------------------------------------------";
    final CapabilityProfile profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

// Judul & Header Struk
    bytes += generator.text(SettingSession.nama_cabang,
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(SettingSession.alamat_cabang,
        styles: const PosStyles(align: PosAlign.center));
    bytes +=
        generator.text(sline, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text("LAPORAN TUTUP SHIFT",
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes +=
        generator.text(sline, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text("Shift ID : #${report['id_shift']}");
    bytes += generator.text("Kasir    : $username");
    bytes += generator
        .text("Waktu    : ${DateTime.now().toString().substring(0, 16)}");
    bytes +=
        generator.text(sline, styles: const PosStyles(align: PosAlign.center));

    bytes += generator
        .text("Modal Awal    : ${formatRupiah.format(report['modal_awal'])}");
    bytes += generator
        .text("Total Tunai   : ${formatRupiah.format(report['total_tunai'])}");
    bytes += generator
        .text("Total QRIS    : ${formatRupiah.format(report['total_qris'])}");

    bytes +=
        generator.text(sline, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(
        "Uang Aktual Laci  : ${formatRupiah.format(report['uang_aktual'])}");

    bytes += generator
        .text("Selisih Laci      : ${formatRupiah.format(report['selisih'])}");

    bytes +=
        generator.text(sline, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text("Laporan sukses diunggah.",
        styles: const PosStyles(align: PosAlign.center));

    bytes += generator.feed(3);
    bytes.addAll([29, 86, 66, 0]);
    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<void> printShiftOpen(
      Map<String, dynamic> report, String username) async {
    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) return;
    final formatRupiah =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    String sline = "------------------------------------------------";
    final CapabilityProfile profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

// Judul & Header Struk
    bytes += generator.text(SettingSession.nama_cabang,
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(SettingSession.alamat_cabang,
        styles: const PosStyles(align: PosAlign.center));
    bytes +=
        generator.text(sline, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text("LAPORAN BUKA SHIFT",
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes +=
        generator.text(sline, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text("Shift ID : #${report['id_shift']}");
    bytes += generator.text("Kasir    : $username");
    bytes += generator
        .text("Modal Awal    : ${formatRupiah.format(report['modal_awal'])}");
    bytes += generator
        .text("Waktu    : ${DateTime.now().toString().substring(0, 16)}");
    bytes +=
        generator.text(sline, styles: const PosStyles(align: PosAlign.center));

    bytes += generator.feed(3);
    bytes.addAll([29, 86, 66, 0]);
    await PrintBluetoothThermal.writeBytes(bytes);
  }
}
