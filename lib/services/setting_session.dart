import 'dart:io';

class SettingSession {
  SettingSession._();
  static String id_cabang = "";
  static String nama_cabang = "";
  static String alamat_cabang = "";
  static String telp_cabang = "";
  static String url_api = "";
  static String id_user = "";
  static String nama_lengkap = "";
  static String role = "";
  static String device_id = "";
  static String daily_id = "";

  static void insert({
    required String id_cabang_,
    required String nama_cabang_,
    required String alamat_cabang_,
    required String telp_cabang_,
    required String url_api_,
    required String id_user_,
    required String nama_lengkap_,
    required String role_,
    required String device_id_,
    required String daily_id_,
  }) {
    id_cabang = id_cabang_;
    nama_cabang = nama_cabang_;
    alamat_cabang = alamat_cabang_;
    telp_cabang = telp_cabang_;
    url_api = url_api_;
    id_user = id_user_;
    nama_lengkap = nama_lengkap_;
    role = role_;
    device_id = device_id_;
    daily_id = daily_id_;
  }

  static void clear() {
    id_cabang = "";
    nama_cabang = "";
    alamat_cabang = "";
    telp_cabang = "";
    url_api = "";
    id_user = "";
    nama_lengkap = "";
    role = "";
    device_id = "";
    daily_id = "";
  }
}
