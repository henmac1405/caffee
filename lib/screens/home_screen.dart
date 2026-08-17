import 'package:caffee/services/setting_session.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../services/printer_service.dart';
import '../services/shift_provider.dart';
import 'cart_screen.dart';
import '../database/apihelper.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiHelper API = ApiHelper();
  late Future<Map<String, dynamic>> _futureAppData;
  String _searchQuery = "";
  bool _isCheckingShift = true;
  String daily_id_now = "";
  var dailyFormat = DateFormat("yyMMdd");
  DateTime now = DateTime.now();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // --- VARIABEL BARU UNTUK MENU PENGATURAN PRINTER ---
  final PrinterService _printerService = PrinterService();
  List<BluetoothInfo> _devices = [];
  BluetoothInfo? _selectedDevice;
  bool _isPrinterConnected = false;
  bool _isScanning = false;

  int _currentIndex = 0;

  String image_url = "";

  @override
  void initState() {
    super.initState();
    // _initFetch();
    getSetting();
    daily_id_now = dailyFormat.format(now);
    _checkShiftStatusBeforeLoad();
    _cekStatusPrinterKini();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void getSetting() {
    API
        .getSetting("image_url", "Setting", SettingSession.url_api)
        .then((result) {
      print("getSetting : ");
      print(result);
      if (result.isNotEmpty) {
        result.forEach((value) {
          setState(() {
            image_url = value['setting_value'];
          });
        });
      }
    });
  }

  Future<void> _cekStatusPrinterKini() async {
    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    setState(() {
      _isPrinterConnected = isConnected;
    });
  }

  // VALIDASI UTAMA: Cek status shift di MySQL sebelum menampilkan katalog
  Future<void> _checkShiftStatusBeforeLoad() async {
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);

    // Mengambil parameter id_cabang dinamis dari SettingSession
    String currentBranch = SettingSession.id_cabang;

    // Panggil fungsi API yang telah dimodifikasi
    var res = await API.checkActiveShift(currentBranch, SettingSession.url_api);

    if (res != null && res['has_active_shift'] == true) {
      int realShiftId = int.tryParse(res['id_shift'].toString()) ?? 0;
      SettingSession.daily_id = res['daily_id'] ?? "";

      print("DAILY ID : " + SettingSession.daily_id);
      // PERBAIKAN: Tambahkan .toDouble() setelah parsing angka modal awal
      double realModalAwal =
          (double.tryParse(res['modal_awal'].toString()) ?? 0.0).toDouble();

      shiftProvider.openShift(realShiftId, realModalAwal);
    } else {
      shiftProvider.closeShift();
    }

    setState(() {
      _isCheckingShift = false;
      if (shiftProvider.isShiftOpen) {
        _initFetch();
      }
    });
  }

  void _initFetch() {
    // Memuat data produk dan data kategori secara paralel dari API MySQL
    _futureAppData = Future.wait([
      fetchMenuFromServer("product", SettingSession.url_api),
      API.getCategory("category", SettingSession.url_api),
    ]).then((results) {
      return {
        'products': results[0] as List<MenuItem>,
        'categories': results[1] as List<String>,
      };
    });
  }

  Future<List<MenuItem>> fetchMenuFromServer(
      String apiName, String urlApi) async {
    List rawData = await API.getProduct(apiName, urlApi);
    return rawData
        .map((item) => MenuItem(
              // PERBAIKAN 1: Parsing ID menjadi Integer murni sesuai tipe master_product MySQL
              id: int.tryParse(item['id'].toString()) ?? 0,
              name: item['name'].toString(),
              price: double.tryParse(item['price'].toString()) ?? 0.0,
              discountPercent:
                  int.tryParse(item['diskon_persen'].toString()) ?? 0,

              // PERBAIKAN 2: Tarik data persentase pajak (tax) baru dari payload database MySQL
              tax: int.tryParse(item['tax'].toString()) ?? 0,

              category: item['category'].toString(),
              imagePath: item['imagePath'] ?? '☕',
            ))
        .toList();
  }

  String formatRupiah(double nominal) {
    // Mengubah angka menjadi string dan memisahkan ribuan dengan titik
    String valueString = nominal.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result =
        valueString.replaceAllMapped(reg, (Match match) => '${match[1]}.');
    return 'Rp $result';
  }

  String hitungKodeTanggal() {
    DateTime kini = DateTime.now();
    // 'yy' menghasilkan 2 digit tahun, 'MM' 2 digit bulan, 'dd' 2 digit tanggal
    return DateFormat('yyMMdd').format(kini);
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final shiftProvider = Provider.of<ShiftProvider>(context);
    final PrinterService _printerService = PrinterService();

    // 1. TAMPILKAN LOADING SAAT APLIKASI MEMERIKSA STATUS SHIFT KE MYSQL
    if (_isCheckingShift) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4E342E)),
        ),
      );
    }

    // JIKA SHIFT BELUM DIBUKA, TAMPILKAN LAYAR INPUT MODAL AWAL
    if (!shiftProvider.isShiftOpen) {
      final TextEditingController modalController = TextEditingController();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Buka Shift Kasir',
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF4E342E),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/login'),
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_clock, size: 64, color: Color(0xFF8D6E63)),
              const SizedBox(height: 16),
              const Text('Sesi Kerja Anda Kosong',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Text('Masukkan Modal Awal untuk memulai transaksi baru',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 24),
              TextField(
                controller: modalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Modal Laci (Rp)',
                    prefixText: 'Rp '),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4E342E)),
                  onPressed: () async {
                    if (modalController.text.isEmpty) return;

                    double modal = double.tryParse(modalController.text) ?? 0;

                    // 1. Simpan data shift baru ke MySQL via API PHP
                    int? realShiftId = await API.bukaShift(
                        SettingSession.id_user, modal, SettingSession.url_api);

                    if (realShiftId != null) {
                      // 2. Jika sukses mendapatkan ID dari database, aktifkan session di Flutter
                      setState(() {
                        shiftProvider.openShift(realShiftId, modal);
                        _initFetch(); // Muat katalog produk
                      });

                      SettingSession.daily_id = daily_id_now;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Shift #$realShiftId berhasil dibuka untuk ${SettingSession.id_user}'),
                            backgroundColor: Colors.green),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Gagal membuka shift di database server!'),
                            backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                  child: const Text('BUKA SHIFT SEKARANG',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('KASIR\n${SettingSession.nama_lengkap}',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4E342E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          // IconButton(
          //   icon:
          //       const Icon(Icons.analytics_rounded, color: Colors.amberAccent),
          //   tooltip: 'Menu Laporan Cafe',
          //   onPressed: () {
          //     // =========================================================================
          //     // GERBANG KEAMANAN PINDAH KE SINI: Validasi Role Sebelum Membuka Menu Utama
          //     // =========================================================================
          //     if (SettingSession.role == 'admin') {
          //       // Jika yang login adalah Owner/Admin, langsung buka Pusat Menu Laporan
          //       Navigator.pushNamed(context, '/report_menu');
          //     } else {
          //       // Jika yang login adalah kasir biasa, panggil Dialog Login Supervisor
          //       _showAdminLoginDialog(context, '/report_menu');
          //     }
          //     // =========================================================================
          //   },
          // ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _initFetch();
              });
              posProvider.clearTransaction();
            },
          ),
//           IconButton(
//             icon: const Icon(Icons.assignment_turned_in,
//                 color: Colors.orangeAccent),
//             tooltip: 'Tutup Shift Harian',
//             onPressed: () {
//               final TextEditingController laciController =
//                   TextEditingController();

//               showDialog(
//                 context: context,
//                 barrierDismissible: false,
//                 builder: (ctx) => AlertDialog(
//                   title: const Text('Konfirmasi Tutup Shift',
//                       style:
//                           TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                   content: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                           'Hitung total uang fisik (Tunai + Modal) yang ada di dalam laci kasir saat ini:',
//                           style: TextStyle(fontSize: 12, color: Colors.grey)),
//                       const SizedBox(height: 16),
//                       TextField(
//                         controller: laciController,
//                         keyboardType: TextInputType.number,
//                         decoration: const InputDecoration(
//                           border: OutlineInputBorder(),
//                           labelText: 'Total Uang Fisik Laci',
//                           prefixText: 'Rp ',
//                         ),
//                       ),
//                     ],
//                   ),
//                   actions: [
//                     TextButton(
//                       onPressed: () {
//                         Navigator.pop(ctx);
//                       },
//                       child: const Text('Batal',
//                           style: TextStyle(color: Colors.grey)),
//                     ),
//                     ElevatedButton(
//                       style:
//                           ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                       onPressed: () async {
//                         if (laciController.text.isEmpty) return;

//                         double uangLaci =
//                             double.tryParse(laciController.text) ?? 0;
//                         int currentShiftId = shiftProvider.activeShiftId ?? 0;

//                         // 1. Ambil data ringkasan agregat baru dari database MySQL via API PHP
//                         Map<String, dynamic>? shiftData = await API.tutupShift(
//                             currentShiftId, uangLaci, SettingSession.url_api);

//                         if (shiftData != null) {
//                           if (context.mounted) {
//                             Navigator.pop(
//                                 ctx); // Tutup dialog input nominal uang laci dengan aman
//                           }

//                           // 2. TAMPILKAN DIALOG PREVIEW STRUK SHIFT YANG SUDAH FORMAT RUPIAH & AGREGAT LENGKAP
//                           if (context.mounted) {
//                             showDialog(
//                               context: context,
//                               barrierDismissible: false,
//                               builder: (previewCtx) => AlertDialog(
//                                 backgroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(4)),
//                                 title: const Center(
//                                   child: Column(
//                                     children: [
//                                       Text('📝 RINGKASAN SHIFT',
//                                           style: TextStyle(
//                                               fontWeight: FontWeight.bold,
//                                               fontSize: 16)),
//                                       Text('--------------------------------',
//                                           style: TextStyle(color: Colors.grey)),
//                                     ],
//                                   ),
//                                 ),
//                                 content: SingleChildScrollView(
//                                   child: Column(
//                                     mainAxisSize: MainAxisSize.min,
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       Text(
//                                           'Shift ID : #${shiftData['id_shift']}',
//                                           style: const TextStyle(
//                                               fontSize: 12,
//                                               fontFamily: 'monospace')),
//                                       Text(
//                                           'Cabang   : ${shiftData['id_cabang']}',
//                                           style: const TextStyle(
//                                               fontSize: 12,
//                                               fontFamily: 'monospace')),
//                                       Text(
//                                           'Kasir    : ${SettingSession.id_user}',
//                                           style: const TextStyle(
//                                               fontSize: 12,
//                                               fontFamily: 'monospace')),
//                                       Text(
//                                           'Waktu    : ${DateTime.now().toString().substring(0, 16)}',
//                                           style: const TextStyle(
//                                               fontSize: 12,
//                                               fontFamily: 'monospace')),
//                                       const Text(
//                                           '--------------------------------',
//                                           style: TextStyle(color: Colors.grey)),

//                                       Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           const Text('Modal Awal:',
//                                               style: TextStyle(
//                                                   fontSize: 12,
//                                                   fontFamily: 'monospace')),
//                                           Text(
//                                               formatRupiah(double.tryParse(
//                                                       shiftData['modal_awal']
//                                                           .toString()) ??
//                                                   0),
//                                               style: const TextStyle(
//                                                   fontSize: 12,
//                                                   fontFamily: 'monospace')),
//                                         ],
//                                       ),
//                                       Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           const Text('Total Tunai:',
//                                               style: TextStyle(
//                                                   fontSize: 12,
//                                                   fontFamily: 'monospace')),
//                                           Text(
//                                               formatRupiah(double.tryParse(
//                                                       shiftData['total_tunai']
//                                                           .toString()) ??
//                                                   0),
//                                               style: const TextStyle(
//                                                   fontSize: 12,
//                                                   fontFamily: 'monospace')),
//                                         ],
//                                       ),
//                                       Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           const Text('Total QRIS:',
//                                               style: TextStyle(
//                                                   fontSize: 12,
//                                                   fontFamily: 'monospace')),
//                                           Text(
//                                               formatRupiah(double.tryParse(
//                                                       shiftData['total_qris']
//                                                           .toString()) ??
//                                                   0),
//                                               style: const TextStyle(
//                                                   fontSize: 12,
//                                                   fontFamily: 'monospace')),
//                                         ],
//                                       ),
//                                       //VOID
//                                       Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           Text(
//                                               '${shiftData['total_void_count']}x Void:',
//                                               style: TextStyle(
//                                                   fontSize: 12,
//                                                   fontFamily: 'monospace')),
//                                           Text(
//                                               formatRupiah(double.tryParse(
//                                                       shiftData[
//                                                               'total_void_amount']
//                                                           .toString()) ??
//                                                   0),
//                                               style: const TextStyle(
//                                                   fontSize: 12,
//                                                   fontFamily: 'monospace')),
//                                         ],
//                                       ),
//                                       const Text(
//                                           '--------------------------------',
//                                           style: TextStyle(color: Colors.grey)),
//                                       Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           const Text('Uang Aktual Laci:',
//                                               style: TextStyle(
//                                                   fontSize: 12,
//                                                   fontWeight: FontWeight.bold,
//                                                   fontFamily: 'monospace')),
//                                           Text(
//                                               formatRupiah(double.tryParse(
//                                                       shiftData['uang_aktual']
//                                                           .toString()) ??
//                                                   0),
//                                               style: const TextStyle(
//                                                   fontSize: 12,
//                                                   fontWeight: FontWeight.bold,
//                                                   fontFamily: 'monospace')),
//                                         ],
//                                       ),
//                                       Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           const Text('Selisih Laci:',
//                                               style: TextStyle(
//                                                   fontSize: 12,
//                                                   fontFamily: 'monospace')),
//                                           Text(
//                                             formatRupiah(double.tryParse(
//                                                     shiftData['selisih']
//                                                         .toString()) ??
//                                                 0),
//                                             style: TextStyle(
//                                                 fontSize: 12,
//                                                 fontFamily: 'monospace',
//                                                 color: (double.tryParse(shiftData[
//                                                                     'selisih']
//                                                                 .toString()) ??
//                                                             0) <
//                                                         0
//                                                     ? Colors.red
//                                                     : Colors.green,
//                                                 fontWeight: FontWeight.bold),
//                                           ),
//                                         ],
//                                       ),

//                                       // TOTAL PENJUALAN PER CABANG HARI INI
//                                       const Text(
//                                           '--------------------------------',
//                                           style: TextStyle(color: Colors.grey)),
//                                       const Text('[ OMSET CABANG HARI INI ]',
//                                           style: TextStyle(
//                                               fontSize: 12,
//                                               fontWeight: FontWeight.bold,
//                                               fontFamily: 'monospace')),
//                                       Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           Expanded(
//                                               child: Text(
//                                                   '${shiftData['info_sales_cabang']['nama']}',
//                                                   style: const TextStyle(
//                                                       fontSize: 11,
//                                                       fontFamily: 'monospace'),
//                                                   maxLines: 1,
//                                                   overflow:
//                                                       TextOverflow.ellipsis)),
//                                           Text(
//                                               formatRupiah(double.tryParse(
//                                                       shiftData['info_sales_cabang']
//                                                               ['total']
//                                                           .toString()) ??
//                                                   0),
//                                               style: const TextStyle(
//                                                   fontSize: 11,
//                                                   fontFamily: 'monospace',
//                                                   fontWeight: FontWeight.w600)),
//                                         ],
//                                       ),

//                                       // TOTAL PENJUALAN PER USER/KASIR PADA SHIFT INI
//                                       const Text(
//                                           '--------------------------------',
//                                           style: TextStyle(color: Colors.grey)),
//                                       const Text('[ OMSET KASIR PADA SHIFT ]',
//                                           style: TextStyle(
//                                               fontSize: 12,
//                                               fontWeight: FontWeight.bold,
//                                               fontFamily: 'monospace')),
//                                       ...(shiftData['info_sales_user'] as List)
//                                           .map((u) {
//                                         return Row(
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.spaceBetween,
//                                           children: [
//                                             Text('User: ${u['id_user']}',
//                                                 style: const TextStyle(
//                                                     fontSize: 11,
//                                                     fontFamily: 'monospace')),
//                                             Text(
//                                                 formatRupiah(double.tryParse(
//                                                         u['total']
//                                                             .toString()) ??
//                                                     0),
//                                                 style: const TextStyle(
//                                                     fontSize: 11,
//                                                     fontFamily: 'monospace')),
//                                           ],
//                                         );
//                                       }),

//                                       // TOTAL PENJUALAN PER PRODUK PADA SHIFT INI
//                                       const Text(
//                                           '--------------------------------',
//                                           style: TextStyle(color: Colors.grey)),
//                                       const Text('[ PENJUALAN MENU / PRODUK ]',
//                                           style: TextStyle(
//                                               fontSize: 12,
//                                               fontWeight: FontWeight.bold,
//                                               fontFamily: 'monospace')),
//                                       ...(shiftData['info_sales_product']
//                                               as List)
//                                           .map((p) {
//                                         return Padding(
//                                           padding: const EdgeInsets.symmetric(
//                                               vertical: 2.0),
//                                           child: Row(
//                                             mainAxisAlignment:
//                                                 MainAxisAlignment.spaceBetween,
//                                             children: [
//                                               Expanded(
//                                                   child: Text(
//                                                       '${p['name']} (x${p['qty']})',
//                                                       style: const TextStyle(
//                                                           fontSize: 11,
//                                                           fontFamily:
//                                                               'monospace'),
//                                                       maxLines: 1,
//                                                       overflow: TextOverflow
//                                                           .ellipsis)),
//                                               Text(
//                                                   formatRupiah(double.tryParse(
//                                                           p['total']
//                                                               .toString()) ??
//                                                       0),
//                                                   style: const TextStyle(
//                                                       fontSize: 11,
//                                                       fontFamily: 'monospace')),
//                                             ],
//                                           ),
//                                         );
//                                       }),
//                                       const Text(
//                                           '--------------------------------',
//                                           style: TextStyle(color: Colors.grey)),
//                                     ],
//                                   ),
//                                 ),
//                                 actions: [
//                                   TextButton(
//                                     onPressed: () {
//                                       setState(() {
//                                         shiftProvider.closeShift();
//                                         posProvider.clearTransaction();
//                                       });
//                                       Navigator.pop(previewCtx);
//                                     },
//                                     child: const Text('Selesai (Tanpa Cetak)',
//                                         style: TextStyle(color: Colors.grey)),
//                                   ),
//                                   ElevatedButton(
//                                     style: ElevatedButton.styleFrom(
//                                         backgroundColor:
//                                             const Color(0xFF4E342E)),
//                                     onPressed: () async {
// // Cetak ke hardware printer thermal BLE
//                                       await _printerService.printShiftReport(
//                                           shiftData, SettingSession.id_user);
//                                       setState(() {
//                                         shiftProvider.closeShift();
//                                         posProvider.clearTransaction();
//                                       });
//                                       if (context.mounted) {
//                                         Navigator.pop(previewCtx);
//                                         ScaffoldMessenger.of(context)
//                                             .showSnackBar(
//                                           const SnackBar(
//                                               content: Text(
//                                                   'Shift Ditutup & Struk Laporan Dicetak!'),
//                                               backgroundColor: Colors.green),
//                                         );
//                                       }
//                                     },
//                                     child: const Text('Cetak Struk',
//                                         style: TextStyle(color: Colors.white)),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           }
//                         } else {
//                           if (context.mounted) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                   content: Text(
//                                       'Gagal memproses tutup shift ke server!'),
//                                   backgroundColor: Colors.redAccent),
//                             );
//                           }
//                         }
//                       },
//                       child: const Text('Tutup Shift',
//                           style: TextStyle(color: Colors.white)),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),
          // IconButton(
          //   icon: Icon(
          //     _isPrinterConnected
          //         ? Icons.print_rounded
          //         : Icons.print_disabled_rounded,
          //     color: _isPrinterConnected
          //         ? Colors.greenAccent
          //         : Colors.grey.shade400,
          //   ),
          //   tooltip: 'Pengaturan Printer Bluetooth',
          //   onPressed: () =>
          //       _initBluetoothScan(context), // Jalankan radar pemindai
          // ),
          // IconButton(
          //   icon: const Icon(Icons.logout, color: Colors.redAccent),
          //   tooltip: 'Logout Kasir',
          //   onPressed: () {
          //     posProvider.clearTransaction();
          //     Navigator.pushReplacementNamed(context, '/login');
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       const SnackBar(
          //           content: Text('Berhasil keluar dari sistem kasir.')),
          //     );
          //   },
          // ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureAppData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4E342E)));
          } else if (snapshot.hasError) {
            return Center(child: Text("Gagal memuat data: ${snapshot.error}"));
          } else if (!snapshot.hasData) {
            return const Center(child: Text("Data dari server kosong"));
          }

          final dynamicCategories =
              snapshot.data!['categories'] as List<String>;
          final masterMenu = snapshot.data!['products'] as List<MenuItem>;

          // Memfilter menu berdasarkan kategori dan kolom pencarian teks
          final filteredMenu = masterMenu.where((item) {
            bool matchesCategory = posProvider.selectedCategory == 'Semua' ||
                item.category == posProvider.selectedCategory;
            bool matchesSearch =
                item.name.toLowerCase().contains(_searchQuery.toLowerCase());
            return matchesCategory && matchesSearch;
          }).toList();

          return Column(
            children: [
              // 1. FILTER KATEGORI DINAMIS DARI MYSQL
              Container(
                height: 60,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: dynamicCategories.length,
                  itemBuilder: (context, idx) {
                    bool isSelected =
                        posProvider.selectedCategory == dynamicCategories[idx];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(dynamicCategories[idx]),
                        selected: isSelected,
                        selectedColor: const Color(0xFF8D6E63),
                        labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87),
                        onSelected: (_) =>
                            posProvider.setCategory(dynamicCategories[idx]),
                      ),
                    );
                  },
                ),
              ),

              // 2. WIDGET BAR PENCARIAN REAKTIF
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari Product...',
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF4E342E)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _searchQuery = "";
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // 3. GRID PRODUK UTAMA (FLEKSIBEL PADA PONSEL & TABLET)
              Expanded(
                child: filteredMenu.isEmpty
                    ? const Center(child: Text("Menu tidak ditemukan"))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          // 1. Dapatkan lebar layar perangkat secara real-time
                          double width = constraints.maxWidth;

                          // 2. Hitung jumlah kolom secara dinamis berdasarkan lebar layar
                          // Jika lebar > 600 dp (standar awal tablet), buat menjadi 3 atau 4 kolom
                          int crossAxisCount = 2;
                          if (width > 900) {
                            crossAxisCount =
                                4; // Tablet Mode Lanskap / Tablet Besar
                          } else if (width > 600) {
                            crossAxisCount =
                                3; // Tablet Mode Potret / Tablet Kecil
                          }

                          // 3. Tentukan rasio tinggi-lebar kartu (Child Aspect Ratio) secara proporsional
                          // Pada tablet, rasio disesuaikan agar ruang teks harga dan tombol tetap pas
                          double childAspectRatio = 0.75;
                          if (width > 600) {
                            childAspectRatio =
                                0.85; // Sedikit lebih kotak di tablet agar tidak terlalu panjang ke bawah
                          }

                          return GridView.builder(
                            padding: const EdgeInsets.only(
                                top: 16, left: 16, right: 16, bottom: 100),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  crossAxisCount, // Dinamis mengikuti ukuran layar
                              childAspectRatio:
                                  childAspectRatio, // Dinamis mengikuti ukuran layar
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                            ),
                            itemCount: filteredMenu.length,
                            itemBuilder: (context, idx) {
                              final item = filteredMenu[idx];
                              double discountAmount =
                                  item.price * (item.discountPercent / 100);
                              double finalPrice = item.price - discountAmount;

                              return Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 4,
                                child: Stack(
                                  children: [
                                    // Konten Kartu Menu Utama
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                                12), // Membuat sudut gambar melengkung rapi
                                            child: Image.network(
                                              // Pastikan url_api digabung jika database hanya menyimpan nama filenya saja,
                                              // Contoh: '${SettingSession.url_api}/uploads/products/${item.imagePath}'
                                              "${image_url}${item.imagePath}",

                                              // Ukuran bingkai gambar membesar secara fleksibel saat di tablet
                                              width: width > 600 ? 80 : 64,
                                              height: width > 600 ? 80 : 64,
                                              fit: BoxFit
                                                  .cover, // Memotong gambar agar pas presisi di dalam bingkai kotak

                                              // INDIKATOR LOADING: Animasi berputar saat gambar sedang diunduh dari server
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return SizedBox(
                                                  width: width > 600 ? 80 : 64,
                                                  height: width > 600 ? 80 : 64,
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                      color: const Color(
                                                          0xFF4E342E),
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                );
                                              },

                                              // JARING PENGAMAN ERROR: Jika link mati atau internet putus, tampilkan emoji default
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  width: width > 600 ? 80 : 64,
                                                  height: width > 600 ? 80 : 64,
                                                  decoration: BoxDecoration(
                                                    color: Colors.brown.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Icon(
                                                    Icons
                                                        .image_not_supported_outlined, // Ikon resmi patah/tidak didukung dari material design
                                                    color: Colors.grey
                                                        .shade400, // Warna abu-abu halus agar estetik
                                                    size: width > 600
                                                        ? 36
                                                        : 28, // Ukuran ikon adaptif membesar secara fleksibel di layar tablet
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8.0),
                                            child: Text(item.name,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    // Teks judul menu lebih proporsional di tablet
                                                    fontSize:
                                                        width > 600 ? 14 : 13),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(height: 4),
                                          // Render Struktur Harga Normal vs Harga Potongan Diskon
                                          if (item.discountPercent > 0) ...[
                                            Text(formatRupiah(item.price),
                                                style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize:
                                                        width > 600 ? 12 : 11,
                                                    decoration: TextDecoration
                                                        .lineThrough)),
                                            Text(formatRupiah(finalPrice),
                                                style: TextStyle(
                                                    color:
                                                        const Color(0xFF2E7D32),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize:
                                                        width > 600 ? 15 : 14)),
                                          ] else ...[
                                            Text(formatRupiah(item.price),
                                                style: TextStyle(
                                                    color:
                                                        const Color(0xFF8D6E63),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize:
                                                        width > 600 ? 15 : 14)),
                                          ],
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF4E342E),
                                                padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        width > 600 ? 16 : 12,
                                                    vertical:
                                                        width > 600 ? 8 : 4),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20))),
                                            icon: const Icon(Icons.add,
                                                size: 14, color: Colors.white),
                                            label: Text('Tambah',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize:
                                                        width > 600 ? 12 : 11)),
                                            onPressed: () =>
                                                posProvider.addToCart(item),
                                          )
                                        ],
                                      ),
                                    ),
                                    // BADGE PROMO MERAH DI SUDUT KARTU
                                    if (item.discountPercent > 0)
                                      Positioned(
                                        top: 10,
                                        left: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: Text(
                                            '${item.discountPercent}% OFF',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: width > 600 ? 10 : 9,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index; // Ubah halaman aktif saat ikon NavBar diklik
          });

          if (index == 1) {
            //SHIFT CLOSE
            _showTutupShiftDialog(context, shiftProvider, posProvider);
          } else if (index == 2) {
            //LAPORAN
            if (SettingSession.role == 'admin') {
              // Jika yang login adalah Owner/Admin, langsung buka Pusat Menu Laporan
              Navigator.pushNamed(context, '/report_menu');
            } else {
              // Jika yang login adalah kasir biasa, panggil Dialog Login Supervisor
              _showAdminLoginDialog(context, '/report_menu');
            }
          } else if (index == 3) {
            //PRINTER
            _initBluetoothScan(context);
          } else if (index == 4) {
            //EXIT
            posProvider.clearTransaction();
            Navigator.pushReplacementNamed(context, '/login');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Berhasil keluar dari sistem kasir.')),
            );
          } else {
            //HOME
            setState(() {
              _currentIndex = index;
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        // selectedItemColor:
        //     const Color(0xFF4E342E), // Warna cokelat saat dipilih
        // unselectedItemColor:
        //     Colors.grey.shade400, // Warna abu-abu saat tidak aktif
        // selectedLabelStyle:
        //     const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        // unselectedLabelStyle: const TextStyle(fontSize: 11),

        // Daftar Ikon Menu Navigasi Bawah
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 30),
            // activeIcon: Icon(Icons.home, color: Color(0xFF4E342E)),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in, size: 30),
            // activeIcon:
            //     Icon(Icons.assignment_turned_in, color: Color(0xFF4E342E)),
            label: 'Shift Close',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.analytics_rounded, size: 30),
            // activeIcon: Icon(Icons.analytics_rounded, color: Color(0xFF4E342E)),
            label: 'Laporan',
          ),
          BottomNavigationBarItem(
            icon: Icon(
                _isPrinterConnected
                    ? Icons.print_rounded
                    : Icons.print_disabled_rounded,
                size: 30,
                color: _isPrinterConnected
                    ? Colors.greenAccent
                    : Colors.grey.shade400),
            // activeIcon: Icon(
            //   _isPrinterConnected
            //       ? Icons.print_rounded
            //       : Icons.print_disabled_rounded,
            //   color: _isPrinterConnected
            //       ? Colors.greenAccent
            //       : Colors.grey.shade400,
            // ),
            label: 'Printer',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.logout, size: 30),
            // activeIcon: Icon(Icons.logout, color: Color(0xFF4E342E)),
            label: 'Exit',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: posProvider.cart.isEmpty
          ? null
          : Container(
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: FloatingActionButton.extended(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CartScreen())),
                label: Row(
                  children: [
                    const Icon(Icons.shopping_basket, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      '${posProvider.totalItems} Item | ${formatRupiah(posProvider.totalPayment)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.white),
                  ],
                ),
              ),
            ),
    );
  }

  void _showAdminLoginDialog(BuildContext context, String targetRoute) {
    _usernameController.clear();
    _passwordController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_person_rounded, color: Color(0xFF4E342E)),
            SizedBox(width: 8),
            Text('Otorisasi Admin',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Akses ke Pusat Laporan dikunci. Silakan masukkan kredensial akun admin/supervisor.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username Admin',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password Admin',
                prefixIcon: Icon(Icons.vpn_key),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4E342E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              String userAdmin = _usernameController.text.trim();
              String passAdmin = _passwordController.text.trim();

              // Verifikasi kredensial (Sesuaikan dengan enkripsi MD5 / API Anda)
              API.Login(
                      _usernameController.text.trim(),
                      _passwordController.text.trim(),
                      "login",
                      SettingSession.url_api)
                  .then((result) {
                if (result.isNotEmpty) {
                  result.forEach((value) {
                    setState(() {
                      if (value['role'] == "admin") {
                        Navigator.pop(ctx); // Tutup dialog otentikasi
                        Navigator.pushNamed(
                            context, targetRoute); // Buka halaman menu laporan

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Akses Laporan Diberikan!'),
                              backgroundColor: Colors.green),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Kredensial Salah / Hak Akses Ditolak!'),
                              backgroundColor: Colors.red),
                        );
                      }
                    });
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Kredensial Tidak Ditemukan'),
                        backgroundColor: Colors.red),
                  );
                }
              });
              // if (userAdmin == 'admin' && passAdmin == 'admin123') {
              //   Navigator.pop(ctx); // Tutup dialog otentikasi
              //   Navigator.pushNamed(
              //       context, targetRoute); // Buka halaman menu laporan

              //   ScaffoldMessenger.of(context).showSnackBar(
              //     const SnackBar(
              //         content: Text('Akses Laporan Diberikan!'),
              //         backgroundColor: Colors.green),
              //   );
              // } else {
              //   ScaffoldMessenger.of(context).showSnackBar(
              //     const SnackBar(
              //         content: Text('Kredensial Salah / Hak Akses Ditolak!'),
              //         backgroundColor: Colors.red),
              //   );
              // }
            },
            child:
                const Text('Verifikasi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTutupShiftDialog(BuildContext context, ShiftProvider shiftProvider,
      PosProvider posProvider) {
    final TextEditingController laciController = TextEditingController();

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
              title: const Text('Konfirmasi Tutup Shift',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Hitung total uang fisik (Tunai + Modal) yang ada di dalam laci kasir saat ini:',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: laciController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Total Uang Fisik Laci',
                      prefixText: 'Rp ',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child:
                      const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    if (laciController.text.isEmpty) return;

                    double uangLaci = double.tryParse(laciController.text) ?? 0;
                    int currentShiftId = shiftProvider.activeShiftId ?? 0;

                    // 1. Ambil data ringkasan agregat baru dari database MySQL via API PHP
                    Map<String, dynamic>? shiftData = await API.tutupShift(
                        currentShiftId, uangLaci, SettingSession.url_api);

                    if (shiftData != null) {
                      if (context.mounted) {
                        Navigator.pop(
                            ctx); // Tutup dialog input nominal uang laci dengan aman
                      }

                      // 2. TAMPILKAN DIALOG PREVIEW STRUK SHIFT YANG SUDAH FORMAT RUPIAH & AGREGAT LENGKAP
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (previewCtx) => AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            title: const Center(
                              child: Column(
                                children: [
                                  Text('📝 RINGKASAN SHIFT',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  Text('--------------------------------',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Shift ID : #${shiftData['id_shift']}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace')),
                                  Text('Cabang   : ${shiftData['id_cabang']}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace')),
                                  Text('Kasir    : ${SettingSession.id_user}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace')),
                                  Text(
                                      'Waktu    : ${DateTime.now().toString().substring(0, 16)}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace')),
                                  const Text('--------------------------------',
                                      style: TextStyle(color: Colors.grey)),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Modal Awal:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace')),
                                      Text(
                                          formatRupiah(double.tryParse(
                                                  shiftData['modal_awal']
                                                      .toString()) ??
                                              0),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace')),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total Tunai:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace')),
                                      Text(
                                          formatRupiah(double.tryParse(
                                                  shiftData['total_tunai']
                                                      .toString()) ??
                                              0),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace')),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total QRIS:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace')),
                                      Text(
                                          formatRupiah(double.tryParse(
                                                  shiftData['total_qris']
                                                      .toString()) ??
                                              0),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace')),
                                    ],
                                  ),
                                  //VOID
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          '${shiftData['total_void_count']}x Void:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace')),
                                      Text(
                                          formatRupiah(double.tryParse(
                                                  shiftData['total_void_amount']
                                                      .toString()) ??
                                              0),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace')),
                                    ],
                                  ),
                                  const Text('--------------------------------',
                                      style: TextStyle(color: Colors.grey)),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Uang Aktual Laci:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace')),
                                      Text(
                                          formatRupiah(double.tryParse(
                                                  shiftData['uang_aktual']
                                                      .toString()) ??
                                              0),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace')),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Selisih Laci:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace')),
                                      Text(
                                        formatRupiah(double.tryParse(
                                                shiftData['selisih']
                                                    .toString()) ??
                                            0),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                            color: (double.tryParse(
                                                            shiftData['selisih']
                                                                .toString()) ??
                                                        0) <
                                                    0
                                                ? Colors.red
                                                : Colors.green,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),

                                  // TOTAL PENJUALAN PER CABANG HARI INI
                                  const Text('--------------------------------',
                                      style: TextStyle(color: Colors.grey)),
                                  const Text('[ OMSET CABANG HARI INI ]',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace')),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                          child: Text(
                                              '${shiftData['info_sales_cabang']['nama']}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontFamily: 'monospace'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis)),
                                      Text(
                                          formatRupiah(double.tryParse(
                                                  shiftData['info_sales_cabang']
                                                          ['total']
                                                      .toString()) ??
                                              0),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),

                                  // TOTAL PENJUALAN PER USER/KASIR PADA SHIFT INI
                                  const Text('--------------------------------',
                                      style: TextStyle(color: Colors.grey)),
                                  const Text('[ OMSET KASIR PADA SHIFT ]',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace')),
                                  ...(shiftData['info_sales_user'] as List)
                                      .map((u) {
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('User: ${u['id_user']}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace')),
                                        Text(
                                            formatRupiah(double.tryParse(
                                                    u['total'].toString()) ??
                                                0),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace')),
                                      ],
                                    );
                                  }),

                                  // TOTAL PENJUALAN PER PRODUK PADA SHIFT INI
                                  const Text('--------------------------------',
                                      style: TextStyle(color: Colors.grey)),
                                  const Text('[ PENJUALAN MENU / PRODUK ]',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace')),
                                  ...(shiftData['info_sales_product'] as List)
                                      .map((p) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                              child: Text(
                                                  '${p['name']} (x${p['qty']})',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      fontFamily: 'monospace'),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                          Text(
                                              formatRupiah(double.tryParse(
                                                      p['total'].toString()) ??
                                                  0),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontFamily: 'monospace')),
                                        ],
                                      ),
                                    );
                                  }),
                                  const Text('--------------------------------',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    shiftProvider.closeShift();
                                    posProvider.clearTransaction();
                                  });
                                  Navigator.pop(previewCtx);
                                },
                                child: const Text('Selesai (Tanpa Cetak)',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4E342E)),
                                onPressed: () async {
// Cetak ke hardware printer thermal BLE
                                  await _printerService.printShiftReport(
                                      shiftData, SettingSession.id_user);
                                  setState(() {
                                    shiftProvider.closeShift();
                                    posProvider.clearTransaction();
                                  });
                                  if (context.mounted) {
                                    Navigator.pop(previewCtx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Shift Ditutup & Struk Laporan Dicetak!'),
                                          backgroundColor: Colors.green),
                                    );
                                  }
                                },
                                child: const Text('Cetak Struk',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Gagal memproses tutup shift ke server!'),
                              backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  child: const Text('Tutup Shift',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ));
  }

  // FUNGSI UTAMA PINDAI HARDWARE PRINTER SEKITAR (BONDED & UNPAIRED)
  Future<void> _initBluetoothScan(BuildContext context) async {
    setState(() {
      _isScanning = true;
    });
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (statuses[Permission.bluetoothConnect]!.isGranted &&
          statuses[Permission.location]!.isGranted) {
        // Memanggil fungsi penarik andalan dari service lokal Anda
        List<BluetoothInfo> classicDevices = await _printerService.getDevices();

        bool isConnected = await PrintBluetoothThermal.connectionStatus;
        setState(() {
          _devices = classicDevices;
          _isPrinterConnected = isConnected;
          _isScanning = false;
        });

        // Buka panel menu pengaturan khusus jika berhasil scan
        if (mounted) _bukaPanelPengaturanPrinter(context);
      } else {
        setState(() {
          _isScanning = false;
        });
        _tampilkanPesan(
            'Izin Bluetooth & Lokasi wajib diaktifkan!', Colors.orange);
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      debugPrint("Gagal memindai printer: $e");
    }
  }

  // PANEL DIALOG BAWAH (BOTTOM SHEET) PENGATURAN PRINTER KHUSUS
  void _bukaPanelPengaturanPrinter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return StatefulBuilder(
          // Memungkinkan UI Dropdown & Button berubah di dalam bottom sheet
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🔌 Pengaturan Printer Kasir',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4E342E)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded,
                            color: Colors.blue),
                        onPressed: () async {
                          setModalState(() {
                            _isScanning = true;
                          });
                          List<BluetoothInfo> refreshed =
                              await _printerService.getDevices();
                          setModalState(() {
                            _devices = refreshed;
                            _isScanning = false;
                          });
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pilih printer thermal Blueprint 80mm Anda di bawah untuk mengaktifkan cetak kertas nota harian.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // DROPDOWN SELEKSI PERANGKAT PRINTER BLUETOOTH
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<BluetoothInfo>(
                        isExpanded: true,
                        hint: const Text("Pilih Alamat Hardware Printer"),
                        value: _selectedDevice,
                        items: _devices.map((device) {
                          return DropdownMenuItem(
                            value: device,
                            child: Text(device.name.isNotEmpty
                                ? device.name
                                : "Tanpa Nama (${device.macAdress})"),
                          );
                        }).toList(),
                        onChanged: (device) {
                          setModalState(() => _selectedDevice = device);
                          setState(() => _selectedDevice = device);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // TOMBOL HUBUNGKAN & UJI COBA CETAK (TEST PRINT)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF4E342E)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.playlist_add_check_rounded,
                              color: Color(0xFF4E342E)),
                          label: const Text('Test Print',
                              style: TextStyle(
                                  color: Color(0xFF4E342E),
                                  fontWeight: FontWeight.bold)),
                          onPressed: !_isPrinterConnected
                              ? null
                              : () => _eksekusiTestPrint(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: // Di dalam menu Bottom Sheet home_screen.dart, bagian tombol Connect:
                            ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: _isPrinterConnected
                                ? Colors.green
                                : const Color(0xFF4E342E),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(
                              _isPrinterConnected
                                  ? Icons.gpp_good_rounded
                                  : Icons.bluetooth_audio_rounded,
                              color: Colors.white),
                          label: Text(
                              _isPrinterConnected
                                  ? 'Connected (Klik Disconnect)'
                                  : 'Connect',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          onPressed: _selectedDevice == null
                              ? null
                              : () async {
                                  if (_isPrinterConnected) {
                                    // Manual Disconnect jika kasir ingin mengganti ke HP kasir lain
                                    await PrintBluetoothThermal.disconnect;
                                    setModalState(() {
                                      _isPrinterConnected = false;
                                    });
                                    setState(() {
                                      _isPrinterConnected = false;
                                    });
                                  } else {
                                    // Hubungkan menetap (Koneksi Persisten)
                                    bool success =
                                        await PrintBluetoothThermal.connect(
                                            macPrinterAddress:
                                                _selectedDevice!.macAdress);
                                    setModalState(() {
                                      _isPrinterConnected = success;
                                    });
                                    setState(() {
                                      _isPrinterConnected = success;
                                    });
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // FUNGSI CEK OMSET STRUK GENTLE UJI CETAK HARDWARE 80MM
  Future<void> _eksekusiTestPrint() async {
    try {
      final CapabilityProfile profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.text("TEST CETAK PRINTER SUKSES",
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text("Sistem Kasir Multi-Cabang",
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(
          "------------------------------------------------",
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(
          "Hardware   : ${_selectedDevice?.name ?? 'Blueprint 80mm'}",
          styles: const PosStyles(align: PosAlign.left));
      bytes += generator.text("Status     : KONEKSI OK (READY TO PRINT)",
          styles: const PosStyles(align: PosAlign.left));
      bytes += generator.text(
          "------------------------------------------------",
          styles: const PosStyles(align: PosAlign.left));
      bytes += generator.feed(2);
      bytes.addAll(
          [29, 86, 66, 0]); // Pemicu pemotong kertas otomatis (Auto-Cut)

      await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint("Eror uji cetak: $e");
    }
  }

  void _tampilkanPesan(String teks, Color warna) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(teks), backgroundColor: warna));
  }
}
