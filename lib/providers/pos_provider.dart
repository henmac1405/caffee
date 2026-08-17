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
    int index = _cart.indexWhere((element) => element.id == item.id);
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
      ));
    }
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
