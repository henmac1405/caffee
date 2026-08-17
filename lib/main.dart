import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/pos_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_branch_screen.dart';
import 'screens/report_chart_screen.dart';
import 'screens/report_product_screen.dart';
import 'screens/report_screen.dart';
import 'services/shift_provider.dart';
import 'screens/report_menu_screen.dart';
import 'screens/reprint_invoice_screen.dart'; // <-- Tambahkan baris impor ini
import 'screens/void_transaction_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PosProvider()),
        ChangeNotifierProvider(create: (_) => ShiftProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cafe POS System',
      theme: ThemeData(
        primaryColor: const Color(0xFF4E342E),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4E342E)),
        useMaterial3: true,
      ),
      // Tampilan pertama saat aplikasi dibuka
      home: LoginScreen(),
      // DAFTAR RUTE NAVIGASI APLIKASI
      routes: {
        '/login': (context) => LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/report': (context) => const ReportScreen(),
        '/report_menu': (context) => const ReportMenuScreen(),
        '/report_product': (context) => const ReportProductScreen(),
        '/report_branch': (context) => const ReportBranchScreen(),
        '/report_chart': (context) => const ReportChartScreen(),
        '/reprint_invoice': (context) => const ReprintInvoiceScreen(),
        '/void_transaction': (context) => const VoidTransactionScreen(),
      },
    );
  }
}
