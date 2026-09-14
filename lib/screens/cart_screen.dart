import 'package:caffee/services/setting_session.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/pos_provider.dart';
import '../services/printer_service.dart';
import '../services/shift_provider.dart';
import '../database/apihelper.dart';

class CartScreen extends StatefulWidget {
  // PERBAIKAN: parameter opsional ini diisi ketika keranjang datang dari
  // layar Verifikasi Self-Order (bukan input manual kasir). Kalau
  // fromSelfOrderId != null, setelah pembayaran sukses, self_order yang
  // bersangkutan otomatis ditandai selesai di backend supaya hilang dari
  // daftar pending -- lihat _showReceiptPreview di bawah.
  final int? fromSelfOrderId;
  final String? selfOrderNoMeja;
  final String? selfOrderNamaPelanggan;

  const CartScreen({
    super.key,
    this.fromSelfOrderId,
    this.selfOrderNoMeja,
    this.selfOrderNamaPelanggan,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _cashController = TextEditingController();
  final PrinterService _printerService = PrinterService();
  final ApiHelper API = ApiHelper();

  List<BluetoothInfo> _devices = [];
  BluetoothInfo? _selectedDevice;
  double _change = 0;
  bool _isPrinterConnected = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  bool _isScanning =
      false; // Tambahkan variable state ini di dalam kelas _CartScreenState

  Future<void> _initBluetooth() async {
    try {
      setState(() {
        _isScanning = true;
      });

      // Meminta izin krusial (Bluetooth Scan, Connect, dan Lokasi/GPS)
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (statuses[Permission.bluetoothConnect]!.isGranted &&
          statuses[Permission.bluetoothScan]!.isGranted &&
          statuses[Permission.location]!.isGranted) {
        // SOLUSI MUTLAK: Gunakan fungsi penarik dari service lokal Anda yang sudah terbukti valid
        // Fungsi ini otomatis memicu antena HP memindai printer thermal di sekitar meja kasir
        List<BluetoothInfo> devices = await _printerService.getDevices();

        bool isConnected = await PrintBluetoothThermal.connectionStatus;

        setState(() {
          _devices = devices;
          _isPrinterConnected = isConnected;
          _isScanning = false;
        });
      } else {
        setState(() {
          _isScanning = false;
        });
        _showPermissionAlert();
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      debugPrint("Error Bluetooth: $e");
    }
  }

  void _showPermissionAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Izin Bluetooth & Lokasi wajib diaktifkan untuk mencari printer baru!'),
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }

  // PERBAIKAN: dialog kecil untuk tambah/ubah catatan per item keranjang
  // (contoh: "tidak pedas", "tanpa gula").
  void _showEditNoteDialog(
      BuildContext context, PosProvider posProvider, int index, String currentNote) {
    final controller = TextEditingController(text: currentNote);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catatan Item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: 'Contoh: tidak pedas, tanpa gula',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              posProvider.setNoteAt(index, controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _calculateChange(double totalBelanjaWajib) {
    // Ambil teks nominal uang tunai yang diketik kasir, jika kosong setel ke 0
    double uangTunaiKasir = double.tryParse(_cashController.text) ?? 0.0;

    setState(() {
      if (uangTunaiKasir == 0.0) {
        _change = 0.0;
      } else {
        // Rumus Finansial: Uang Tunai Konsumen - Grand Total Wajib (Termasuk Pajak)
        _change = uangTunaiKasir - totalBelanjaWajib;
      }
    });
  }

  double _getFinalTotal(double subtotal) {
    // Karena diskon per produk sudah langsung memotong total di PosProvider,
    // fungsi ini cukup mengembalikan nilai subtotal bersih yang diterima.
    return subtotal;
  }

  Future<void> _togglePrinterConnection() async {
    if (_selectedDevice == null) return;

    if (_isPrinterConnected) {
      await PrintBluetoothThermal.disconnect;
      setState(() => _isPrinterConnected = false);
    } else {
      bool result = await PrintBluetoothThermal.connect(
          macPrinterAddress: _selectedDevice!.macAdress);
      setState(() => _isPrinterConnected = result);
    }
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  String formatRupiah(double nominal) {
    String valueString = nominal.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${valueString.replaceAllMapped(reg, (Match match) => '${match.group(1)}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    double subtotal = posProvider.totalPayment;
    double totalTaxValue = posProvider.totalTax; // <-- AMBIL NILAI RUPIAH PAJAK
    double finalTotal = posProvider.finalTotalWithTax;

    double discountValue = posProvider.cart.fold(0, (sum, item) {
      return sum +
          ((item.price * (item.discountPercent / 100)) * item.quantity);
    });

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Billing Detail', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF4E342E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // 1. PANEL SELEKSI PRINTER BLUETOOTH BLE
            // Container(
            //   color: Colors.grey,
            //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            //   child: Row(
            //     children: [
            //       IconButton(
            //         icon: const Icon(Icons.refresh, color: Colors.blue),
            //         onPressed: () => _initBluetooth(),
            //       ),
            //       Expanded(
            //         child: DropdownButton<BluetoothInfo>(
            //           isExpanded: true,
            //           hint: const Text("Pilih Printer Bluetooth"),
            //           value: _selectedDevice,
            //           items: _devices.map((device) {
            //             return DropdownMenuItem(
            //               value: device,
            //               child: Text(device.name.isNotEmpty
            //                   ? device.name
            //                   : "Tanpa Nama (${device.macAdress})"),
            //             );
            //           }).toList(),
            //           onChanged: (device) =>
            //               setState(() => _selectedDevice = device),
            //         ),
            //       ),
            //       const SizedBox(width: 8),
            //       ElevatedButton(
            //         style: ElevatedButton.styleFrom(
            //             backgroundColor:
            //                 _isPrinterConnected ? Colors.green : Colors.brown),
            //         onPressed: _selectedDevice == null
            //             ? null
            //             : _togglePrinterConnection,
            //         child: Text(_isPrinterConnected ? "Connected" : "Connect",
            //             style: const TextStyle(color: Colors.white)),
            //       ),
            //     ],
            //   ),
            // ),

            // 2. LIST ITEM PRODUK DI KERANJANG
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posProvider.cart.length,
              itemBuilder: (context, idx) {
                final item = posProvider.cart[idx];
                double discountAmountPerUnit =
                    item.price * (item.discountPercent / 100);
                double finalUnitPrice = item.price - discountAmountPerUnit;
                double totalItemPrice = finalUnitPrice * item.quantity;

                return Card(
                  margin: const EdgeInsets.only(left: 16, right: 16, top: 8),
                  child: ListTile(
                    // leading: Text(item.imagePath,
                    //     style: const TextStyle(fontSize: 24)),
                    title: Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.discountPercent > 0) ...[
                          Text('Harga Asli: ${formatRupiah(item.price)}',
                              style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                  fontSize: 12)),
                          Text(
                              'Diskon Produk: -${formatRupiah(discountAmountPerUnit * item.quantity)} (${item.discountPercent}%)',
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12)),
                        ],
                        Text('Subtotal: ${formatRupiah(totalItemPrice)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                        // PERBAIKAN: tampilkan catatan item kalau ada,
                        // plus tombol untuk tambah/edit catatan.
                        if (item.note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Catatan: ${item.note}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.deepOrange)),
                          ),
                        InkWell(
                          onTap: () => _showEditNoteDialog(context, posProvider, idx, item.note),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_note,
                                    size: 16, color: Colors.blueGrey.shade400),
                                const SizedBox(width: 2),
                                Text(
                                  item.note.isEmpty ? 'Tambah catatan' : 'Ubah catatan',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.blueGrey.shade400),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                          onPressed: () {
                            posProvider.updateQuantityAt(idx, -1);
                            _calculateChange(posProvider.finalTotalWithTax);
                          },
                        ),
                        Text('${item.quantity}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: Colors.green),
                          onPressed: () {
                            posProvider.updateQuantityAt(idx, 1);
                            _calculateChange(posProvider.finalTotalWithTax);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // 3. PILIHAN METODE PEMBAYARAN & NOMINAL TUNAI
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Metode Pembayaran:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          avatar: const Icon(Icons.money, size: 18),
                          label: const Center(child: Text('Tunai')),
                          selected: posProvider.paymentMethod == 'Tunai',
                          onSelected: (_) {
                            posProvider.setPaymentMethod('Tunai');
                            _cashController.clear();
                            setState(() {
                              _change = 0;
                            });
                          },
                          selectedColor: const Color(0xFF8D6E63),
                          labelStyle: TextStyle(
                              color: posProvider.paymentMethod == 'Tunai'
                                  ? Colors.white
                                  : Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          avatar: const Icon(Icons.qr_code_2, size: 18),
                          label: const Center(child: Text('QRIS')),
                          selected: posProvider.paymentMethod == 'QRIS',
                          onSelected: (_) {
                            posProvider.setPaymentMethod('QRIS');
                            _cashController.text =
                                finalTotal.toStringAsFixed(0);
                            _calculateChange(posProvider.finalTotalWithTax);
                          },
                          selectedColor: const Color(0xFF8D6E63),
                          labelStyle: TextStyle(
                              color: posProvider.paymentMethod == 'QRIS'
                                  ? Colors.white
                                  : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  if (posProvider.paymentMethod == 'Tunai') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _cashController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Uang Tunai Diterima (Rp)',
                          border: OutlineInputBorder(),
                          prefixText: 'Rp '),
                      onChanged: (_) =>
                          _calculateChange(posProvider.finalTotalWithTax),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kembalian:',
                            style: TextStyle(fontSize: 14)),
                        Text(
                            _change < 0
                                ? 'Uang Kurang!'
                                : formatRupiah(_change),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _change < 0 ? Colors.red : Colors.blue)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 4. RINGKASAN PEMBAYARAN AKHIR
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Column(
                children: [
                  if (discountValue > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal Item',
                            style: TextStyle(fontSize: 14, color: Colors.grey)),
                        Text(formatRupiah(subtotal),
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Potongan Diskon',
                            style: TextStyle(fontSize: 14, color: Colors.red)),
                        Text('-${formatRupiah(discountValue)}',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  // WIDGET BARU: RINCIAN NOMINAL PAJAK PRODUK YANG KELUAR
                  if (totalTaxValue > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pajak Produk (Tax)',
                            style:
                                TextStyle(fontSize: 14, color: Colors.orange)),
                        Text(formatRupiah(totalTaxValue),
                            style: const TextStyle(
                                fontSize: 14, color: Colors.orange)),
                      ],
                    ),

                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Pembayaran',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                      Text(formatRupiah(finalTotal),
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4E342E),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: posProvider.cart.isEmpty ||
                              (_change < 0 &&
                                  posProvider.paymentMethod == 'Tunai') ||
                              (posProvider.paymentMethod == 'Tunai' &&
                                  _cashController.text.isEmpty)
                          ? null
                          : () => _showReceiptPreview(context, posProvider,
                              subtotal, discountValue, finalTotal),
                      child: const Text('LIHAT STRUK & BAYAR',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showReceiptPreview(BuildContext context, PosProvider posProvider,
      double subtotal, double discountValue, double finalTotal) {
    double totalTaxValue = posProvider.totalTax;
    double cashAmount = posProvider.paymentMethod == 'QRIS'
        ? finalTotal
        : (double.tryParse(_cashController.text) ?? finalTotal);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Center(
          child: Column(
            children: [
              Text(SettingSession.nama_cabang,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(SettingSession.alamat_cabang,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
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
              // PERBAIKAN: tampilkan info meja/pelanggan kalau keranjang
              // ini berasal dari self-order yang baru di-Terima.
              if (widget.fromSelfOrderId != null) ...[
                if ((widget.selfOrderNoMeja ?? '').isNotEmpty)
                  Text('Meja    : ${widget.selfOrderNoMeja}',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                if ((widget.selfOrderNamaPelanggan ?? '').isNotEmpty)
                  Text('Nama    : ${widget.selfOrderNamaPelanggan}',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              ],
              Text('Tanggal : ${DateTime.now().toString().substring(0, 16)}',
                  style:
                      const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              Text('Kasir   : ${SettingSession.nama_lengkap}',
                  style:
                      const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              Text('Metode  : ${posProvider.paymentMethod}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
              const Text('--------------------------------',
                  style: TextStyle(color: Colors.grey)),

              // LOOPING DAFTAR ITEM BELANJA
              ...posProvider.cart.map((item) {
                double discountPerUnit =
                    item.price * (item.discountPercent / 100);
                double itemSubtotal =
                    (item.price - discountPerUnit) * item.quantity;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text('${item.name} x${item.quantity}',
                                  style: const TextStyle(
                                      fontSize: 13, fontFamily: 'monospace'))),
                          Text(formatRupiah(itemSubtotal),
                              style: const TextStyle(
                                  fontSize: 13, fontFamily: 'monospace')),
                        ],
                      ),
                      if (item.discountPercent > 0)
                        Text(
                            '  *Disc ${item.discountPercent}%: -${formatRupiah(discountPerUnit * item.quantity)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontFamily: 'monospace')),
                      if (item.note.isNotEmpty)
                        Text('  *Catatan: ${item.note}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.deepOrange,
                                fontFamily: 'monospace')),
                    ],
                  ),
                );
              }),

              const Text('--------------------------------',
                  style: TextStyle(color: Colors.grey)),

              // RINCIAN DISKON GLOBAL JIKA ADA PROMO AKTIF
              // if (discountValue > 0) ...[
              //   Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: [
              //       const Text('SUBTOTAL:',
              //           style:
              //               TextStyle(fontSize: 13, fontFamily: 'monospace')),
              //       Text(formatRupiah(subtotal),
              //           style: const TextStyle(
              //               fontSize: 13, fontFamily: 'monospace')),
              //     ],
              //   ),
              //   Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: [
              //       const Text('TOTAL DISKON:',
              //           style: TextStyle(
              //               fontSize: 13,
              //               fontFamily: 'monospace',
              //               color: Colors.red)),
              //       Text('-${formatRupiah(discountValue)}',
              //           style: const TextStyle(
              //               fontSize: 13,
              //               fontFamily: 'monospace',
              //               color: Colors.red)),
              //     ],
              //   ),
              //   Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: [
              //       const Text('TOTAL AKHIR:',
              //           style: TextStyle(
              //               fontWeight: FontWeight.bold,
              //               fontSize: 14,
              //               fontFamily: 'monospace')),
              //       Text(formatRupiah(finalTotal),
              //           style: const TextStyle(
              //               fontWeight: FontWeight.bold,
              //               fontSize: 14,
              //               color: Colors.green,
              //               fontFamily: 'monospace')),
              //     ],
              //   )
              // ],

              // RINCIAN DISKON GLOBAL JIKA ADA PROMO AKTIF
              if (totalTaxValue > 0) ...[
                // <-- CETAK PAJAK DI STRUK BELANJA
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('PAJAK / TAX:',
                        style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: Colors.orange)),
                    Text(formatRupiah(totalTaxValue),
                        style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: Colors.orange)),
                  ],
                ),
              ],

              // RINCIAN NOMINAL PEMBAYARAN AKHIR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL AKHIR:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'monospace')),
                  Text(formatRupiah(finalTotal),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.green,
                          fontFamily: 'monospace')),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('BAYAR:',
                      style: TextStyle(fontSize: 13, fontFamily: 'monospace')),
                  Text(formatRupiah(cashAmount),
                      style: const TextStyle(
                          fontSize: 13, fontFamily: 'monospace')),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('KEMBALI:',
                      style: TextStyle(fontSize: 13, fontFamily: 'monospace')),
                  Text(_change < 0 ? 'Rp 0' : formatRupiah(_change),
                      style: const TextStyle(
                          fontSize: 13, fontFamily: 'monospace')),
                ],
              ),
              const SizedBox(height: 20),
              const Center(
                  child: Text('Terima Kasih Atas Kunjungan Anda',
                      style: TextStyle(
                          fontSize: 11, fontStyle: FontStyle.italic))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E342E)),
            onPressed: () async {
              final shiftProvider =
                  Provider.of<ShiftProvider>(context, listen: false);

              // Merakit Paket Data Transaksi Lengkap
              Map<String, dynamic> orderData = {
                'id_user': SettingSession.id_user,
                'id_shift': shiftProvider.activeShiftId,
                'id_cabang': SettingSession.id_cabang,
                'daily_id': SettingSession.daily_id,
                'total_pembayaran': finalTotal,
                'diskon': discountValue,
                'tax': totalTaxValue,
                'metode_pembayaran': posProvider.paymentMethod,
                'uang_tunai': cashAmount,
                'uang_kembalian': _change < 0 ? 0 : _change,
                'items': posProvider.cart.map((item) {
                  double subtotal = item.price * item.quantity;
                  double discountRupee =
                      (item.price * (item.discountPercent / 100)) *
                          item.quantity;
                  double subtotalAfterDisc = subtotal - discountRupee;
                  double taxAmount = subtotalAfterDisc * (item.tax / 100);
                  double subtotalAfterTax = subtotalAfterDisc + taxAmount;
                  return {
                    'id': item.id,
                    'quantity': item.quantity,
                    'price': item.price,
                    'diskon_persen': item.discountPercent,
                    'diskon_amount': discountRupee,
                    'tax_persen': item.tax,
                    'tax_amount': taxAmount,
                    'subtotal': subtotalAfterTax,
                    'catatan': item.note,
                  };
                }).toList()
              };

              // Kirim POST Request JSON ke Server CodeIgniter 3 via ApiHelper
              // PERBAIKAN: saveOrder sekarang mengembalikan Map lengkap
              // (bukan cuma String? no_faktur), supaya kita bisa tahu
              // alasan gagal secara spesifik -- termasuk kalau ternyata
              // stok produk tidak cukup (dicek atomik di backend).
              Map<String, dynamic> hasil =
                  await API.saveOrder(orderData, SettingSession.url_api);

              if (hasil['success'] == true) {
                String nomorFaktur = hasil['no_faktur'].toString();

                // PERBAIKAN: kalau keranjang ini berasal dari self-order
                // (bukan input manual kasir), tandai self_order yang
                // bersangkutan sebagai selesai/approved di backend,
                // ditautkan ke transaksi asli yang baru saja dibuat.
                // Tanpa ini, pesanan akan tetap nyangkut di status
                // 'pending' walau sudah lunas dibayar di sini.
                if (widget.fromSelfOrderId != null) {
                  await API.markSelfOrderSettled(
                    idSelfOrder: widget.fromSelfOrderId.toString(),
                    noFaktur: nomorFaktur,
                    idUser: SettingSession.id_user,
                    urlApi: SettingSession.url_api,
                  );
                }

                // Perintah cetak hardware ke Printer Thermal bluetooth BLE
                if (_isPrinterConnected) {
                  await _printerService.printReceipt(
                      posProvider, cashAmount, _change, nomorFaktur);
                }

                posProvider.clearTransaction();
                _cashController.clear();
                _change = 0;

                if (mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Transaksi $nomorFaktur (Format Angka Murni) Berhasil Simpan!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else if (hasil['id_product_kurang'] != null &&
                  (hasil['id_product_kurang'] as List).isNotEmpty) {
                // Gagal spesifik karena stok tidak cukup untuk sebagian
                // produk di keranjang. Tunjukkan produk mana ke kasir,
                // dan sarankan refresh daftar menu supaya stok terbaru
                // ikut ter-update di layar.
                final List idKurang = hasil['id_product_kurang'] as List;
                final namaProdukKurang = posProvider.cart
                    .where((item) => idKurang.contains(item.id))
                    .map((item) => item.name)
                    .join(', ');

                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Stok Tidak Cukup'),
                      content: Text(
                        namaProdukKurang.isNotEmpty
                            ? 'Stok untuk produk berikut tidak mencukupi:\n$namaProdukKurang\n\nSilakan sesuaikan jumlah pesanan atau hapus produk tersebut dari keranjang.'
                            : (hasil['message'] ??
                                'Stok tidak cukup untuk sebagian produk.'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(hasil['message'] ??
                          'Gagal sinkronisasi data ke server MySQL!'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Cetak Sekarang',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
