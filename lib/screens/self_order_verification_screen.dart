import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:caffee/services/setting_session.dart';
import '../database/apihelper.dart';
import '../providers/pos_provider.dart';
import '../models/menu_item.dart';
import 'cart_screen.dart';

/// Layar untuk pelayan/kasir memverifikasi pesanan yang masuk dari
/// self-order (web). Pesanan di sini BELUM memotong stok dan BELUM
/// jadi transaksi asli. Menekan "Terima" akan memuat item pesanan ke
/// keranjang kasir dan membuka cart_screen -- pembayaran diproses
/// SEPERTI TRANSAKSI BIASA lewat layar itu (bukan dialog terpisah di
/// sini), supaya cuma ada SATU jalur pembayaran di seluruh app.
class SelfOrderVerificationScreen extends StatefulWidget {
  const SelfOrderVerificationScreen({super.key});

  @override
  State<SelfOrderVerificationScreen> createState() =>
      _SelfOrderVerificationScreenState();
}

class _SelfOrderVerificationScreenState
    extends State<SelfOrderVerificationScreen> {
  final ApiHelper API = ApiHelper();
  List<dynamic> _pendingOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  final formatRupiah =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  Timer? _autoRefreshTimer;
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchPending();
    // PERBAIKAN: auto-refresh tiap 10 detik supaya pesanan baru dari
    // self-order langsung kelihatan tanpa pelayan harus tarik-refresh
    // manual terus-menerus.
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      // Lewati refresh diam-diam kalau dialog Terima/Tolak sedang
      // terbuka, supaya daftar tidak berubah di belakang layar saat
      // pelayan sedang memproses satu pesanan.
      if (!_isDialogOpen) {
        _fetchPending(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPending({bool silent = false}) async {
    // "silent" dipakai saat auto-refresh berjalan di background, supaya
    // tidak menampilkan spinner loading tiap 10 detik yang bikin
    // tampilan berkedip-kedip mengganggu pelayan yang sedang membaca.
    if (!silent) {
      setState(() => _isLoading = true);
    }
    final hasil = await API.getPendingSelfOrders(
        SettingSession.id_cabang, SettingSession.url_api);
    if (!mounted) return;

    if (hasil['success'] == true) {
      setState(() {
        _pendingOrders = hasil['data'];
        _errorMessage = null;
        _isLoading = false;
      });
    } else {
      // PERBAIKAN: sebelumnya error jaringan/server disembunyikan dan
      // tampil sama persis seperti "tidak ada pesanan". Sekarang error
      // asli ditampilkan supaya bisa langsung ketahuan penyebabnya.
      setState(() {
        _errorMessage = hasil['message'] ?? 'Gagal memuat data';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Verifikasi Order',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4E342E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchPending,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 56, color: Colors.red),
                        const SizedBox(height: 12),
                        const Text('Gagal memuat daftar pesanan',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchPending,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _pendingOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('Tidak ada pesanan self-order yang menunggu',
                              style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          // Info debug: id_cabang yang dipakai untuk fetch,
                          // supaya gampang ketahuan kalau ternyata beda
                          // dengan id_cabang yang dipakai saat submit di
                          // self-order web.
                          Text('Cabang: ${SettingSession.id_cabang}',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchPending,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _pendingOrders.length,
                        itemBuilder: (context, index) {
                          final order = _pendingOrders[index];
                          return _buildOrderCard(order);
                        },
                      ),
                    ),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final items = order['items'] as List<dynamic>;
    final total = double.tryParse(order['total_pembayaran'].toString()) ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Meja ${order['no_meja']}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    _buildSumberBadge(order),
                  ],
                ),
                Text(formatRupiah.format(total),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32))),
              ],
            ),
            if ((order['created_at'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 3),
                    Text(_formatJam(order['created_at']),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            if ((order['nama_pelanggan'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('a.n. ${order['nama_pelanggan']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
            const Divider(),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                                '${item['quantity']}x ${item['nama_produk'] ?? 'Produk'}',
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Text(
                              formatRupiah.format(
                                  double.tryParse(item['subtotal'].toString()) ?? 0),
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      if ((item['catatan'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('*${item['catatan']}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.deepOrange.shade400)),
                        ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red)),
                    onPressed: () => _showRejectDialog(order),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32)),
                    onPressed: () => _terimaPesanan(order),
                    child: const Text('Terima',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(dynamic order) {
    final alasanController = TextEditingController();
    _isDialogOpen = true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tolak Pesanan Meja ${order['no_meja']} (${order['nama_pelanggan']})?'),
        content: TextField(
          controller: alasanController,
          decoration: const InputDecoration(
              labelText: 'Alasan (opsional)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final hasil = await API.rejectSelfOrder(
                idSelfOrder: order['id_self_order'].toString(),
                idUser: SettingSession.id_user,
                alasan: alasanController.text.trim(),
                urlApi: SettingSession.url_api,
              );
              _showSnack(hasil['message'] ?? '', hasil['success'] == true);
              if (hasil['success'] == true) _fetchPending();
            },
            child: const Text('Ya, Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((_) => _isDialogOpen = false);
  }

  /// PERBAIKAN (alur baru): "Terima" tidak lagi membuka dialog pembayaran
  /// sendiri. Sekarang item pesanan dimuat ke keranjang kasir
  /// (PosProvider), lalu CartScreen dibuka -- pembayaran diproses persis
  /// seperti transaksi kasir manual biasa (satu jalur pembayaran untuk
  /// semua jenis transaksi).
  Future<void> _terimaPesanan(dynamic order) async {
    final total = double.tryParse(order['total_pembayaran'].toString()) ?? 0;

    // Konfirmasi awal sebelum apa pun diproses.
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terima Pesanan Ini?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meja    : ${order['no_meja']}'),
            if ((order['nama_pelanggan'] ?? '').toString().isNotEmpty)
              Text('Nama    : ${order['nama_pelanggan']}'),
            Text('Total   : ${formatRupiah.format(total)}'),
            const SizedBox(height: 12),
            const Text(
              'Item pesanan akan dimuat ke keranjang kasir untuk diproses pembayarannya.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Terima', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (konfirmasi != true) return;

    final posProvider = Provider.of<PosProvider>(context, listen: false);

    // Kalau kasir kebetulan sedang punya transaksi lain berjalan di
    // keranjang, jangan langsung ditimpa diam-diam -- konfirmasi dulu.
    if (posProvider.cart.isNotEmpty) {
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Keranjang belum kosong'),
          content: const Text(
              'Ada transaksi lain yang sedang berjalan di keranjang kasir. '
              'Melanjutkan akan mengosongkan keranjang itu terlebih dulu. Lanjutkan?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lanjutkan'),
            ),
          ],
        ),
      );
      if (lanjut != true) return;
      posProvider.clearTransaction();
    }

    // Muat setiap item pesanan self-order ke keranjang kasir.
    final items = order['items'] as List<dynamic>;
    for (var item in items) {
      final qty = int.tryParse(item['quantity'].toString()) ?? 1;
      final menuItem = MenuItem(
        id: int.tryParse(item['id_product'].toString()) ?? 0,
        name: item['nama_produk'] ?? 'Produk',
        price: double.tryParse(item['harga_satuan'].toString()) ?? 0,
        discountPercent: int.tryParse(item['diskon_persen'].toString()) ?? 0,
        tax: int.tryParse(item['tax_persen'].toString()) ?? 0,
        category: '',
        imagePath: '☕',
        note: (item['catatan'] ?? '').toString(),
      );
      // addToCart menambah quantity 1 tiap kali dipanggil (atau membuat
      // baris baru kalau belum ada) -- panggil berulang sesuai qty asli.
      for (int i = 0; i < qty; i++) {
        posProvider.addToCart(menuItem);
      }
    }

    if (!mounted) return;

    // Buka cart_screen dengan penanda asal self-order, supaya setelah
    // pembayaran sukses, self_order ini otomatis ditautkan & ditutup
    // statusnya (lihat cart_screen.dart -> markSelfOrderSettled).
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          fromSelfOrderId: int.tryParse(order['id_self_order'].toString()),
          selfOrderNoMeja: order['no_meja']?.toString(),
          selfOrderNamaPelanggan: order['nama_pelanggan']?.toString(),
        ),
      ),
    );

    // Setelah kembali dari cart_screen (baik jadi bayar atau batal),
    // refresh daftar pending -- kalau sudah dibayar, pesanan ini akan
    // otomatis hilang dari daftar karena statusnya sudah berubah.
    _fetchPending();
  }

  void _showSnack(String message, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? Colors.green : Colors.redAccent,
    ));
  }

  String _formatJam(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  Widget _buildSumberBadge(dynamic order) {
    final sumber = (order['sumber'] ?? 'web').toString();
    final isWeb = sumber == 'web';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isWeb ? const Color(0xFFE3F2FD) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isWeb ? Icons.qr_code_scanner : Icons.badge,
              size: 11, color: isWeb ? Colors.blue.shade700 : Colors.orange.shade800),
          const SizedBox(width: 3),
          Text(
            isWeb ? 'Web' : (order['dibuat_oleh'] ?? 'Pelayan').toString(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isWeb ? Colors.blue.shade700 : Colors.orange.shade800),
          ),
        ],
      ),
    );
  }
}
