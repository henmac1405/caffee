import 'package:caffee/services/setting_session.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';

class ApiHelper {
  String _device_id = "";

  Future<List> Login(String user_id, String user_password, String api_name,
      String url_api) async {
    List? data;
    String strerror = "";
    String str = "";
    //_url_api = "http://ipl.okbossku.com/ipl_server/index.php/api/";
    // _url_api = "http://henhen.okbossku.com/pos_server/index.php/api/";
    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$username:$password'));
    Map<String, String> headers = {
      "X-API-KEY": "rahasia123",
      'authorization': basicAuth
    };

    Map<String, dynamic> params = {
      "X-API-KEY": "rahasia123",
      "id_user": user_id,
      "password": user_password
    };
    // print(_url_api);
    print(url_api + api_name);
    print(params);
    try {
      final http.Response response = await http.post(
        Uri.parse(url_api + api_name),
        headers: headers,
        body: params,
      );
      print('response : ' + api_name + ' ' + response.statusCode.toString());
      print(response.body);
      // 1. CEK STATUS CODE 200 TERLEBIH DAHULU
      if (response.statusCode == 200) {
        var json = jsonDecode(response
            .body); // Hanya decode jika sukses atau format JSON pasti valid
        data = json['data'];
        _toastInfo(json['message'] ?? 'Login berhasil');
      }
      // 2. DETEKSI ERROR 404 DENGAN AMAN
      else if (response.statusCode == 404) {
        str = "${response.statusCode} : $api_name NOT FOUND";

        // Amankan pembacaan pesan dari JSON, gunakan fallback jika bukan JSON
        try {
          var json = jsonDecode(response.body);
          _toastInfo(json['message'] ?? 'Halaman atau API tidak ditemukan');
        } catch (_) {
          _toastInfo('Error 404: Endpoint API tidak ditemukan di server.');
        }
      }
      // 3. PENANGANAN ERROR LAINNYA
      else {
        try {
          var json = jsonDecode(response.body);
          str = response.statusCode.toString() +
              " : " +
              (json['message'] ?? 'Error');
          _toastInfo(response.statusCode.toString() +
              " : " +
              (json['message'] ?? 'Error'));
          insertlogerror(
              api_name +
                  " " +
                  response.statusCode.toString() +
                  " " +
                  json['message'],
              _device_id,
              params.toString(),
              url_api);
        } catch (_) {
          _toastInfo('Error ${response.statusCode}: Terjadi kesalahan server.');
        }
      }
      //return Album.fromJson(jsonDecode(response.body));
    } on SocketException catch (e) {
      print(e);
      str = e.toString();
      _toastInfo('Koneksi gagal: Periksa internet Anda');
      insertlogerror(api_name + " : " + e.toString(), _device_id,
          params.toString(), url_api);
    } catch (e) {
      print(e);
      str = e.toString();
      _toastInfo(api_name + " : " + e.toString());
      insertlogerror(api_name + " : " + e.toString(), _device_id,
          params.toString(), url_api);
    }
    return data ?? [];
  }

  Future<List> getProduct(String api_name, String url_api) async {
    List? data;
    String strerror = "";
    String str = "";
    //_url_api = "http://ipl.okbossku.com/ipl_server/index.php/api/";
    // _url_api = "http://henhen.okbossku.com/pos_server/index.php/api/";
    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$username:$password'));
    Map<String, String> headers = {
      "X-API-KEY": "rahasia123",
      'authorization': basicAuth
    };

    Map<String, dynamic> params = {
      "X-API-KEY": "rahasia123",
    };
    // print(_url_api);
    print(url_api + api_name);
    print(params);
    try {
      final http.Response response = await http.post(
        Uri.parse(url_api + api_name),
        headers: headers,
        body: params,
      );
      print('response : ' + api_name + ' ' + response.statusCode.toString());
      print(response.body);
      // 1. CEK STATUS CODE 200 TERLEBIH DAHULU
      if (response.statusCode == 200) {
        var json = jsonDecode(response
            .body); // Hanya decode jika sukses atau format JSON pasti valid
        data = json['data'];
        // _toastInfo(json['message'] ?? '');
      }
      // 2. DETEKSI ERROR 404 DENGAN AMAN
      else if (response.statusCode == 404) {
        str = "${response.statusCode} : $api_name NOT FOUND";

        // Amankan pembacaan pesan dari JSON, gunakan fallback jika bukan JSON
        try {
          var json = jsonDecode(response.body);
          _toastInfo(json['message'] ?? 'Halaman atau API tidak ditemukan');
        } catch (_) {
          _toastInfo('Error 404: Endpoint API tidak ditemukan di server.');
        }
      }
      // 3. PENANGANAN ERROR LAINNYA
      else {
        try {
          var json = jsonDecode(response.body);
          str = response.statusCode.toString() +
              " : " +
              (json['message'] ?? 'Error');
          _toastInfo(response.statusCode.toString() +
              " : " +
              (json['message'] ?? 'Error'));
          insertlogerror(
              api_name +
                  " " +
                  response.statusCode.toString() +
                  " " +
                  json['message'],
              _device_id,
              params.toString(),
              url_api);
        } catch (_) {
          _toastInfo('Error ${response.statusCode}: Terjadi kesalahan server.');
        }
      }
      //return Album.fromJson(jsonDecode(response.body));
    } on SocketException catch (e) {
      print(e);
      str = e.toString();
      _toastInfo('Koneksi gagal: Periksa internet Anda');
      insertlogerror(api_name + " : " + e.toString(), _device_id,
          params.toString(), url_api);
    } catch (e) {
      print(e);
      str = e.toString();
      _toastInfo(api_name + " : " + e.toString());
      insertlogerror(api_name + " : " + e.toString(), _device_id,
          params.toString(), url_api);
    }
    return data ?? [];
  }

  Future<List> getCabang(
      String id_cabang, String api_name, String url_api) async {
    List? data;
    String strerror = "";
    String str = "";
    //_url_api = "http://ipl.okbossku.com/ipl_server/index.php/api/";
    // _url_api = "http://henhen.okbossku.com/pos_server/index.php/api/";
    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$username:$password'));
    Map<String, String> headers = {
      "X-API-KEY": "rahasia123",
      'authorization': basicAuth
    };

    Map<String, dynamic> params = {
      "X-API-KEY": "rahasia123",
      "id_cabang": id_cabang
    };
    // print(_url_api);
    print(url_api + api_name);
    print(params);
    try {
      final http.Response response = await http.post(
        Uri.parse(url_api + api_name),
        headers: headers,
        body: params,
      );
      print('response : ' + api_name + ' ' + response.statusCode.toString());
      print(response.body);
      // 1. CEK STATUS CODE 200 TERLEBIH DAHULU
      if (response.statusCode == 200) {
        var json = jsonDecode(response
            .body); // Hanya decode jika sukses atau format JSON pasti valid
        data = json['data'];
        _toastInfo(json['message'] ?? '');
      }
      // 2. DETEKSI ERROR 404 DENGAN AMAN
      else if (response.statusCode == 404) {
        str = "${response.statusCode} : $api_name NOT FOUND";

        // Amankan pembacaan pesan dari JSON, gunakan fallback jika bukan JSON
        try {
          var json = jsonDecode(response.body);
          _toastInfo(json['message'] ?? 'Halaman atau API tidak ditemukan');
        } catch (_) {
          _toastInfo('Error 404: Endpoint API tidak ditemukan di server.');
        }
      }
      // 3. PENANGANAN ERROR LAINNYA
      else {
        try {
          var json = jsonDecode(response.body);
          str = response.statusCode.toString() +
              " : " +
              (json['message'] ?? 'Error');
          _toastInfo(response.statusCode.toString() +
              " : " +
              (json['message'] ?? 'Error'));
          insertlogerror(
              api_name +
                  " " +
                  response.statusCode.toString() +
                  " " +
                  json['message'],
              _device_id,
              params.toString(),
              url_api);
        } catch (_) {
          _toastInfo('Error ${response.statusCode}: Terjadi kesalahan server.');
        }
      }
      //return Album.fromJson(jsonDecode(response.body));
    } on SocketException catch (e) {
      print(e);
      str = e.toString();
      _toastInfo('Koneksi gagal: Periksa internet Anda');
      insertlogerror(api_name + " : " + e.toString(), _device_id,
          params.toString(), url_api);
    } catch (e) {
      print(e);
      str = e.toString();
      _toastInfo(api_name + " : " + e.toString());
      insertlogerror(api_name + " : " + e.toString(), _device_id,
          params.toString(), url_api);
    }
    return data ?? [];
  }

  Future<List<String>> getCategory(String api_name, String url_api) async {
    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    Map<String, String> headers = {
      "X-API-KEY": "rahasia123",
      'authorization': basicAuth
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(url_api + api_name),
        headers: headers,
        body: {"X-API-KEY": "rahasia123"},
      );

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        List rawCategories = json['data'];
        // Konversi list objek JSON menjadi List<String> dan tambahkan opsi 'Semua' di awal
        List<String> loadedCategories = ['Semua'];
        for (var item in rawCategories) {
          loadedCategories.add(item['category_name'].toString());
        }
        return loadedCategories;
      }
    } catch (e) {
      print("Error load category: $e");
    }
    return ['Semua', 'Kopi', 'Non-Kopi', 'Makanan']; // Fallback jika API gagal
  }

  Future<List> getSetting(
      String setting_id, String api_name, String url_api) async {
    String username = 'admin';
    String password = '1234';
    List? data;
    String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    Map<String, String> headers = {
      "X-API-KEY": "rahasia123",
      'authorization': basicAuth
    };

    try {
      final http.Response response = await http.post(
        Uri.parse(url_api + api_name),
        headers: headers,
        body: {"X-API-KEY": "rahasia123", "setting_id": setting_id},
      );

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        data = json['data'];
      }
    } catch (e) {
      print("Error load category: $e");
    }
    return data ?? [];
  }

  // PERBAIKAN: sebelumnya fungsi ini cuma mengembalikan String? no_faktur
  // (atau null kalau gagal), sehingga alasan kegagalan (misal stok tidak
  // cukup) tidak bisa ditampilkan ke kasir. Sekarang mengembalikan Map
  // lengkap berisi:
  //   'success'            -> bool
  //   'no_faktur'          -> String? (ada kalau sukses)
  //   'message'            -> String (pesan dari server, siap ditampilkan)
  //   'id_product_kurang'  -> List? (ada kalau gagal karena stok kurang)
  Future<Map<String, dynamic>> saveOrder(
      Map<String, dynamic> orderData, String urlApi) async {
    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    Map<String, String> headers = {
      "X-API-KEY": "rahasia123",
      'authorization': basicAuth,
      "Content-Type": "application/json"
    };

    try {
      final http.Response response = await http.post(
        Uri.parse("${urlApi}transaction"),
        headers: headers,
        body: json.encode(orderData),
      );

      print('Status Code: ${response.statusCode}');
      print('Response Body PHP: ${response.body}');

      Map<String, dynamic> jsonResult = {};
      try {
        jsonResult = jsonDecode(response.body);
      } catch (_) {
        // Body bukan JSON valid (misal error server mentah)
      }

      if (response.statusCode == 200) {
        return {
          'success': true,
          'no_faktur': jsonResult['no_faktur'],
          'message': jsonResult['message'] ?? 'Transaksi berhasil disimpan',
        };
      } else if (response.statusCode == 409) {
        // Stok tidak cukup untuk sebagian produk (lihat backend Mdl_transaction)
        return {
          'success': false,
          'message': jsonResult['message'] ?? 'Stok tidak cukup',
          'id_product_kurang': jsonResult['id_product_kurang'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': jsonResult['message'] ??
              'Gagal menyimpan transaksi (kode ${response.statusCode})',
        };
      }
    } catch (e) {
      print("Error saving transaction: $e");
      return {
        'success': false,
        'message': 'Gagal terhubung ke server: $e',
      };
    }
  }

  Future<Map<String, dynamic>?> checkActiveShift(
      String idCabang, String urlApi) async {
    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    try {
      final http.Response response = await http.post(
        Uri.parse("${urlApi}shift/cek_active"),
        headers: {
          "X-API-KEY": "rahasia123",
          'authorization': basicAuth,
        },
        // PERBAIKAN: Parameter body dialihkan mengirimkan id_cabang ke backend PHP
        body: {"id_cabang": idCabang},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error checking active shift by branch: $e");
    }
    return null;
  }

  Future<int?> bukaShift(
      String username, double modalAwal, String urlApi) async {
    String authUser = 'admin';
    String authPass = '1234';
    String basicAuth =
        'Basic ${base64Encode(utf8.encode('$authUser:$authPass'))}';

    try {
      final http.Response response = await http.post(
        Uri.parse("${urlApi}shift/buka"),
        headers: {
          "X-API-KEY": "rahasia123",
          'authorization': basicAuth,
        },
        body: {
          "id_user": username,
          "id_cabang": SettingSession.id_cabang,
          "modal_awal": modalAwal.toString(),
        },
      );

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return int.tryParse(json['id_shift'].toString());
      }
    } catch (e) {
      print("Error buka shift via API: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> tutupShift(
      int idShift, double uangAktifLaci, String urlApi) async {
    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    try {
      final http.Response response = await http.post(
        Uri.parse("${urlApi}shift/tutup"),
        headers: {"X-API-KEY": "rahasia123", 'authorization': basicAuth},
        body: {
          "id_shift": idShift.toString(),
          "id_cabang": SettingSession.id_cabang,
          "uang_aktual_laci": uangAktifLaci.toString(),
          "daily_id": SettingSession.daily_id,
        },
      );

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return json['data']; // Mengembalikan Map data ringkasan shift
      }
    } catch (e) {
      print("Error tutup shift: $e");
    }
    return null;
  }

  // 1. Perbarui Parameter getShiftReport
  Future<Map<String, dynamic>?> getShiftReport(
      int idShift, String idCabang, String urlApi) async {
    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    try {
      final http.Response response = await http.post(
        Uri.parse("${urlApi}report/shift"),
        headers: {"X-API-KEY": "rahasia123", 'authorization': basicAuth},
        body: {
          "id_shift": idShift.toString(),
          "id_cabang": idCabang,
          "daily_id": SettingSession.daily_id,
        }, // Menyertakan ID Cabang
      );
      print("daily_id : " + SettingSession.daily_id);
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return json['data'];
      }
    } catch (e) {
      print("Error: $e");
    }
    return null;
  }

  // 2. Perbarui Parameter getProductPerformanceReport
  Future<List<dynamic>?> getProductPerformanceReport(
      String idCabang, String urlApi) async {
    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    try {
      final http.Response response = await http.post(
        Uri.parse("${urlApi}report/all_product"),
        headers: {"X-API-KEY": "rahasia123", 'authorization': basicAuth},
        body: {"id_cabang": idCabang}, // Menyertakan ID Cabang
      );
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return json['data'];
      }
    } catch (e) {
      print("Error: $e");
    }
    return null;
  }

  // 3. Perbarui Parameter getBranchPerformanceReport
  Future<List<dynamic>?> getBranchPerformanceReport(
      String idCabang, String urlApi) async {
    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    try {
      final http.Response response = await http.post(
        Uri.parse("${urlApi}report/all_branch"),
        headers: {"X-API-KEY": "rahasia123", 'authorization': basicAuth},
        body: {"id_cabang": idCabang}, // Menyertakan ID Cabang
      );
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return json['data'];
      }
    } catch (e) {
      print("Error: $e");
    }
    return null;
  }

  Future<List<dynamic>?> getRevenueChartReport(
      String idCabang, String urlApi) async {
    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    try {
      final http.Response response = await http.post(
        Uri.parse("${urlApi}report/chart_revenue"),
        headers: {
          "X-API-KEY": "rahasia123",
          'authorization': basicAuth,
        },
        body: {"id_cabang": idCabang},
      );

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return json['data'];
      }
    } catch (e) {
      print("Error load revenue chart report: $e");
    }
    return null;
  }

  // MASUKKAN FUNGSI BARU INI DI DALAM KELAS _ReprintInvoiceScreenState:
  // =========================================================================
  // FUNGSI BARU: PENCATATAN AUDIT INTERNAL LOG REPRINT NOTA KASIR
  // =========================================================================
  static Future<bool> saveReprintLog({
    required String noFaktur,
    required String idUser,
    required String idCabang,
    required String urlApi,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${urlApi}transaction/reprint_log'),
        // PERBAIKAN: header X-API-KEY sebelumnya tidak dikirim sama
        // sekali di sini, padahal backend sekarang mewajibkannya di
        // SEMUA method controller Transaction (lihat API_Controller.php).
        // Tanpa ini, request akan ditolak 401 Unauthorized.
        headers: {
          "X-API-KEY": "rahasia123",
        },
        body: {
          'no_faktur': noFaktur,
          'id_user': idUser,
          'id_cabang': idCabang,
          'perangkat_device': 'Kasir Mobile HP',
        },
      );

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        if (resData['status'] == true) {
          //debugPrint("Audit: Sukses mencatat riwayat reprint nota $noFaktur ke database MySQL.");
          return true;
        }
      }
      // debugPrint("Audit Gagal: Server mengembalikan kode status ${response.statusCode}");
      return false;
    } catch (e) {
      // debugPrint("Gagal merekam jejak log reprint via ApiHelper: $e");
      return false;
    }
  }

  // =========================================================================
  // FUNGSI BARU: EKSEKUSI PEMBATALAN TRANSAKSI (VOID NOTA) VIA POST
  // =========================================================================
  static Future<Map<String, dynamic>?> executeVoid({
    required String idTransaksi,
    required String idAdmin,
    required String urlApi,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${urlApi}transaction/void'),
        // PERBAIKAN: header X-API-KEY sebelumnya tidak dikirim sama
        // sekali di sini. Backend sekarang mewajibkannya di SEMUA
        // method controller Transaction, termasuk void_post.
        headers: {
          "X-API-KEY": "rahasia123",
        },
        body: {
          'id_transaksi': idTransaksi,
          'id_admin': idAdmin,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      //debugPrint("Void API Error: Server mengembalikan kode status ${response.statusCode}");
      return null;
    } catch (e) {
      //debugPrint("Gagal mengeksekusi Void via ApiHelper: $e");
      return null;
    }
  }

//==========================================================================================
  Future<String> cekkoneksi(String channel_id, String region_id,
      String branch_id, String url_api) async {
    List? data;
    String strerror = "";
    String str = "";
    //_url_api = "http://ipl.okbossku.com/ipl_server/index.php/api/";
    // _url_api = "http://henhen.okbossku.com/pos_server/index.php/api/";
    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$username:$password'));
    Map<String, String> headers = {
      "X-API-KEY": "rahasia123",
      'authorization': basicAuth
    };

    Map<String, dynamic> params = {
      "X-API-KEY": "rahasia123",
      "channel_id": channel_id,
      "region_id": region_id,
      "branch_id": branch_id
    };
    // print(_url_api);
    print(params);
    try {
      final http.Response response = await http.post(
        Uri.parse(url_api),
        headers: headers,
        body: params,
      );
      print('response cek_koneksi :' + response.statusCode.toString());
      print(response.body);
      if (response.body.length > 0) {}
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        print('json');
        print(json['data']);
        // data = json['data'];
        //str = json['data'];
        str = "success";
        // insertlogerror(
        //     "version_get : " + response.body.toString(), _device_id, params.toString(), url_api);
        // Do whatever you want to do with json.
      } else {
        // var json = jsonDecode(response.body);
        // print('json');
        // print(json['data']);
        str = url_api +
            ' ' +
            response.statusCode.toString() +
            ' ' +
            response.body.toString();
        _toastInfo("cek_koneksi : " + response.statusCode.toString());
        insertlogerror("cek_koneksi : " + response.statusCode.toString(),
            _device_id, params.toString(), url_api);
      }
      //return Album.fromJson(jsonDecode(response.body));
    } on SocketException catch (e) {
      print(e);
      str = e.toString();
      _toastInfo("cek_koneksi : " + e.toString());
      insertlogerror("cek_koneksi : " + e.toString(), _device_id,
          params.toString(), url_api);
      //return "Error on Server";
      // throw Exception("Error on server");
    } catch (e) {
      print(e);
      str = e.toString();
      _toastInfo("cek_koneksi : " + e.toString());
      insertlogerror("cek_koneksi : " + e.toString(), _device_id,
          params.toString(), url_api);
      //return "Error on Server";
      // throw Exception("Error on server");
    }
    //return Album.fromJson(jsonDecode(response.body));
    return str;
  }

  Future<List> insertlogerror(String log_error, String device_id,
      String strparams, String url_api) async {
    List? data;
    //_url_api = "http://ipl.okbossku.com/ipl_server/index.php/api/";
    // _url_api = "http://henhen.okbossku.com/pos_server/index.php/api/";

    String username = 'admin';
    String password = '1234';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$username:$password'));
    Map<String, String> headers = {
      "X-API-KEY": "rahasia123",
      'authorization': basicAuth
    };
    String errors = log_error.replaceAll("'", "");
    Map<String, dynamic> params = {
      "X-API-KEY": "rahasia123",
      "channel_id": "CAFFEE",
      "region_id": "100",
      "branch_id": SettingSession.id_cabang,
      "username": SettingSession.nama_lengkap,
      "log_error": errors,
      "device_id": SettingSession.device_id,
      "params": strparams
    };
    // print(_url_api);
    print(params);

    try {
      final http.Response response = await http.post(
        Uri.parse(url_api + "logerror"),
        headers: headers,
        body: params,
      );
      print('response logerror :' + response.statusCode.toString());
      print(response.body);
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        print('json');
        print(json['data']);
        data = json['data'];
      } else {}
    } on SocketException catch (e) {
      print("logerror2 : " + e.toString());
    } catch (e) {
      print("logerror3 : " + e.toString());
    }

    return data ?? [];
  }

  // =========================================================================
  // FUNGSI BARU: MODULE VERIFIKASI SELF-ORDER OLEH PELAYAN/KASIR
  // =========================================================================

  /// Ambil daftar pesanan self-order yang masih menunggu verifikasi
  /// untuk cabang aktif.
  ///
  /// PERBAIKAN: sebelumnya kalau terjadi error (jaringan, X-API-KEY salah,
  /// endpoint salah, dsb) fungsi ini diam-diam mengembalikan list kosong
  /// -- sehingga di layar terlihat sama persis seperti "memang tidak ada
  /// pesanan", padahal sebenarnya gagal fetch. Sekarang mengembalikan Map
  /// berisi 'success' dan 'message' supaya error asli kelihatan.
  Future<Map<String, dynamic>> getPendingSelfOrders(String idCabang, String urlApi) async {
    try {
      final response = await http.get(
        Uri.parse('${urlApi}selforder/pending?id_cabang=$idCabang'),
        headers: {"X-API-KEY": "rahasia123"},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return {'success': true, 'data': json['data'] ?? []};
      } else {
        return {
          'success': false,
          'message': 'Server balas kode ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server: $e'};
    }
  }

  /// Setujui pesanan self-order -> baru di sini transaksi asli dibuat
  /// dan stok dipotong (lewat backend yang memanggil ulang
  /// Mdl_transaction::save_transaction, sama seperti transaksi kasir biasa).
  ///
  /// Return Map berisi 'success', 'message', 'no_faktur' (kalau sukses),
  /// atau 'id_product_kurang' (kalau gagal karena stok tidak cukup).
  Future<Map<String, dynamic>> approveSelfOrder({
    required String idSelfOrder,
    required String idUser,
    required int idShift,
    required String metodePembayaran,
    required double uangTunai,
    required double uangKembalian,
    required String dailyId,
    required String urlApi,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${urlApi}selforder/approve'),
        headers: {"X-API-KEY": "rahasia123"},
        body: {
          'id_self_order': idSelfOrder,
          'id_user': idUser,
          'id_shift': idShift.toString(),
          'metode_pembayaran': metodePembayaran,
          'uang_tunai': uangTunai.toString(),
          'uang_kembalian': uangKembalian.toString(),
          'daily_id': dailyId,
        },
      );

      Map<String, dynamic> json = {};
      bool jsonValid = true;
      try {
        json = jsonDecode(response.body);
      } catch (_) {
        jsonValid = false;
      }

      if (response.statusCode == 200 && jsonValid) {
        return {
          'success': true,
          'no_faktur': json['no_faktur'],
          'message': json['message'] ?? 'Pesanan berhasil diterima',
        };
      } else if (!jsonValid) {
        // PERBAIKAN: server tidak balas JSON valid (kemungkinan error
        // PHP mentah/HTML). Tampilkan potongan respons asli supaya
        // ketahuan errornya, bukan cuma pesan generik yang tidak
        // membantu debug.
        final cuplikan = response.body.length > 300
            ? response.body.substring(0, 300)
            : response.body;
        return {
          'success': false,
          'message': 'Server error (kode ${response.statusCode}): $cuplikan',
        };
      } else {
        return {
          'success': false,
          'message': json['message'] ?? 'Gagal memproses pesanan',
          'id_product_kurang': json['id_product_kurang'],
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server: $e'};
    }
  }

  /// Tolak pesanan self-order. Tidak menyentuh stok/transaksi.
  Future<Map<String, dynamic>> rejectSelfOrder({
    required String idSelfOrder,
    required String idUser,
    required String alasan,
    required String urlApi,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${urlApi}selforder/reject'),
        headers: {"X-API-KEY": "rahasia123"},
        body: {
          'id_self_order': idSelfOrder,
          'id_user': idUser,
          'alasan': alasan,
        },
      );
      final json = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && json['status'] == true,
        'message': json['message'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server: $e'};
    }
  }

  /// Tandai self_order sebagai selesai/approved SETELAH pembayaran
  /// benar-benar sukses lewat cart_screen (alur normal kasir), ditautkan
  /// ke transaksi asli yang baru dibuat. Dipanggil dari cart_screen,
  /// bukan dari layar Verifikasi Self-Order lagi.
  Future<Map<String, dynamic>> markSelfOrderSettled({
    required String idSelfOrder,
    required String noFaktur,
    required String idUser,
    required String urlApi,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${urlApi}selforder/mark_settled'),
        headers: {"X-API-KEY": "rahasia123"},
        body: {
          'id_self_order': idSelfOrder,
          'no_faktur': noFaktur,
          'id_user': idUser,
        },
      );
      final json = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && json['status'] == true,
        'message': json['message'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server: $e'};
    }
  }

  _toastInfo(String info) {
    Fluttertoast.showToast(
        msg: info, toastLength: Toast.LENGTH_LONG, timeInSecForIosWeb: 2);
  }
}
