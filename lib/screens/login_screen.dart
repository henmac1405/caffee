import 'package:caffee/services/setting_session.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../database/apihelper.dart';
// import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  ApiHelper API = new ApiHelper();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'kopi123');
  String _projectVersion = "";
  String strversion_date = "";
  String _url_api = "";
  String nama_lengkap = "";
  String strerror = "";
  bool isLoading = false;
  String role = "";
  String device_id = "";
  String branch_id = "";
  String nama_cabang = "";
  String id_cabang = "CBG-01";
  String alamat_cabang = "";
  String telp_cabang = "";
  String daily_id = "";

  final TextEditingController _strController = TextEditingController(
      text: 'http://192.168.0.7:8080/poscaffee/index.php/api/');
  String _str = "";

  @override
  void initState() {
    super.initState();
    _projectVersion = "1.0.0";
    strversion_date = "last update 03 Agustus 2026";
    // _url_api = "http://192.168.0.7:8080/poscaffee/index.php/api/";
    _url_api = "https://api.portosales.com/index.php/api/";
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
      });
      if (_usernameController.text == "debug lokal") {
        _showDialogDebug();
      } else {
        API.Login(_usernameController.text.trim(),
                _passwordController.text.trim(), "login", _url_api)
            .then((result) {
          print(result);
          setState(() {
            isLoading = false;
          });

          if (result.isNotEmpty) {
            result.forEach((value) {
              setState(() {
                nama_lengkap = value['nama_lengkap'];
                role = value['role'];
              });
            });
            API.getCabang(id_cabang, "Cabang", _url_api).then((result) {
              if (result.isNotEmpty) {
                result.forEach((value) {
                  setState(() {
                    nama_cabang = value['nama_cabang'] ?? "";
                    alamat_cabang = value['alamat_cabang'] ?? "";
                    telp_cabang = value['telp_cabang'] ?? "";
                  });
                  setIntoSettingSession().then((i) {
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => HomeScreen()));
                  });
                });
              }
            });
          }
        });
      }
      // if (_usernameController.text == 'admin' &&
      //     _passwordController.text == 'kopi123') {
      //   Navigator.pushReplacement(
      //       context, MaterialPageRoute(builder: (_) => HomeScreen()));
      // } else {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //         content: Text('Kredensial Kasir Salah!'),
      //         backgroundColor: Colors.redAccent),
      //   );
      // }
    }
  }

  Future<int> setIntoSettingSession() async {
    SettingSession.insert(
        id_cabang_: id_cabang,
        nama_cabang_: nama_cabang,
        alamat_cabang_: alamat_cabang,
        telp_cabang_: telp_cabang,
        url_api_: _url_api,
        id_user_: _usernameController.text.trim(),
        nama_lengkap_: nama_lengkap,
        role_: role,
        device_id_: device_id,
        daily_id_: daily_id);
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4E342E), Color(0xFF1A0C00)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.coffee_maker_rounded,
                      size: 80, color: Color(0xFFD7CCC8)),
                  SizedBox(height: 16),
                  Text('CAFFEE GAUL',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5)),
                  Text('Sistem Kasir Caffee',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  isLoading == true
                      ? const LinearProgressIndicator(
                          backgroundColor: Color(0xFFF1F1F1),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.yellow),
                          minHeight: 4, // Ketebalan garis progress
                        )
                      : Container(),
                  Text(strerror,
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  SizedBox(height: 40),
                  TextFormField(
                    controller: _usernameController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'ID Kasir',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.person, color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFD7CCC8)),
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? 'ID tidak boleh kosong' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.lock, color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFD7CCC8)),
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? 'Password tidak boleh kosong' : null,
                  ),
                  SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF8D6E63),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handleLogin,
                      child: Text('MASUK SISTEM',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _showDialogDebug() async {
    await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        contentPadding: EdgeInsets.all(16.0),
        content: Row(
          children: <Widget>[
            Expanded(
              //padding: EdgeInsets.only(top: 10.0, bottom: 10.0),
              child: TextField(
                autofocus: true,
                controller: _strController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                ),
                //onChanged: (value) {
                //
                // },
              ),
            ),
          ],
        ),
        actions: <Widget>[
          Container(
              child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: new Text("BATAL"),
          )),
          Container(
              child: ElevatedButton(
            onPressed: () {
              setState(() {
                _str = _strController.text;
                _url_api = _str;
                _usernameController.text = "";
              });
              Navigator.pop(context);
            },
            child: new Text("OK"),
          )),
        ],
      ),
    );
  }
}
