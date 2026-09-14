import 'package:flutter/material.dart';
import '../models/menu_item.dart';

class PosProvider with ChangeNotifier {
  final List<MenuItem> _cart = [];
  String _selectedCategory = 'Semua';

  List<MenuItem> get cart => _cart;
  String get selectedCategory => _selectedCategory;

// Di dalam kelas PosProvider Anda:

// 1. Ambil Nilai Total Tagihan Bersih Setelah Diskon Produk (Sebelum Pajak)
  double get totalPayment {
    return _cart.fold(0, (sum, item) {
      double discountAmount = item.price * (item.discountPercent / 100);
      double finalUnitPrice = item.price - discountAmount;
      return sum + (finalUnitPrice * item.quantity);
    });
  }

// 2. GETTER BARU: Kalkulasi Total Nilai Rupiah Pajak dari Seluruh Item di Keranjang
  double get totalTax {
    return _cart.fold(0, (sum, item) {
      double discountAmount = item.price * (item.discountPercent / 100);
      double finalUnitPrice = item.price - discountAmount;

      // Pajak dihitung dari harga unit setelah dipotong diskon produk
      double taxAmountPerUnit = finalUnitPrice * (item.tax / 100);
      return sum + (taxAmountPerUnit * item.quantity);
    });
  }

// 3. GETTER BARU: Total Akhir yang Wajib Dibayar Konsumen (Total Setelah Diskon + Pajak)
  double get finalTotalWithTax {
    return totalPayment + totalTax;
  }

  int get totalItems => _cart.fold(0, (sum, item) => sum + item.quantity);

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void addToCart(MenuItem item) {
    // PERBAIKAN: pencocokan sekarang berdasarkan id DAN note. Jadi
    // produk yang sama dengan catatan yang BEDA (misal "Kopi tanpa gula"
    // vs "Kopi extra pahit") jadi baris terpisah di keranjang, bukan
    // ketumpuk jadi satu baris.
    int index = _cart.indexWhere(
        (element) => element.id == item.id && element.note == item.note);
    if (index >= 0) {
      _cart[index].quantity++;
    } else {
      _cart.add(MenuItem(
        id: item.id,
        name: item.name,
        price: item.price,
        discountPercent: item.discountPercent,
        // PERBAIKAN: Wajib membawa nilai persen pajak produk ke dalam objek keranjang
        tax: item.tax,
        category: item.category,
        imagePath: item.imagePath,
        note: item.note,
      ));
    }
    notifyListeners();
  }

  /// PERBAIKAN: ubah catatan untuk satu baris item spesifik di keranjang
  /// (berdasarkan posisi/index, karena bisa ada beberapa baris dengan
  /// produk sama tapi catatan berbeda).
  void setNoteAt(int index, String note) {
    if (index < 0 || index >= _cart.length) return;
    _cart[index].note = note;
    notifyListeners();
  }

  void updateQuantity(String productId, int count) {
    // Cari index item di dalam keranjang belanja berdasarkan ID produk
    int index = _cart.indexWhere((item) => item.id.toString() == productId);

    if (index != -1) {
      // Tambah atau kurangi kuantitas item
      _cart[index].quantity += count;

      // Jaring pengaman: Jika kuantitas menjadi 0 atau minus, hapus item dari keranjang
      if (_cart[index].quantity <= 0) {
        _cart.removeAt(index);
      }

      // BANCIAN UTAMA: Wajib panggil notifyListeners agar jumlah & total harga di UI bertambah!
      notifyListeners();
    }
  }

  /// PERBAIKAN: sama seperti updateQuantity(), tapi berdasarkan POSISI
  /// baris di keranjang (bukan cuma id produk). Ini penting sekarang
  /// karena produk yang sama bisa punya beberapa baris terpisah kalau
  /// catatannya beda -- updateQuantity(productId) lama akan selalu
  /// kena baris PERTAMA yang cocok id-nya, padahal user mungkin
  /// memaksudkan baris kedua/ketiga.
  void updateQuantityAt(int index, int count) {
    if (index < 0 || index >= _cart.length) return;
    _cart[index].quantity += count;
    if (_cart[index].quantity <= 0) {
      _cart.removeAt(index);
    }
    notifyListeners();
  }

  void clearTransaction() {
    _cart.clear();
    notifyListeners();
  }

  String _paymentMethod = 'Tunai';
  String get paymentMethod => _paymentMethod;

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }
}
