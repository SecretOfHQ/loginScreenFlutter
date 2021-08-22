import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Auth with ChangeNotifier {
  String? _token;
  DateTime? _expiryDate;
  String? _userId;
  Timer? _authTimer;

  bool get isAuth{
    return _token != null;
  }
  String? get token{
    if(_expiryDate != null && _token != null && _expiryDate!.isAfter(DateTime.now()))
      return _token!;
    else
      return null;
}


  Future<void> _authonticate(
    String? email,
    String? password,
    String? urlSegment,
  ) async {
    final url =
        "https://identitytoolkit.googleapis.com/v1/accounts:$urlSegment?key= AIzaSyDISnj9OsHqE7rGeTqdgDL1wZVmYJYBwas";
    try {
      final res = await http.post(Uri.parse(url), body: json.encode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }));
      final resData = json.decode(res.body);
      if(resData["error"] != null)
        throw "${resData['error']['message']}";
      _token = resData['idToken'];
      _userId = resData['localId'];
      _expiryDate = DateTime.now().add(
          Duration(seconds: int.parse(resData['expiresIn'])));
      autoLogout();
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      final userData = json.encode({
        'token': _token,
        'userId': _userId,
        'expiryDate': _expiryDate!.toIso8601String(),
      });
      prefs.setString("userData", userData);

    }catch (e){
      throw e;
    }
  }
  Future<bool> tryAutoLogin() async{
    final prefs = await SharedPreferences.getInstance();
    if(!prefs.containsKey('userData'))
      return false;
    final extractedUserData = json.decode(prefs.getString("userData")!) as Map<String, Object>;
    final expiryDate = DateTime.parse(extractedUserData['expiryDate'].toString());

    if(expiryDate.isBefore(DateTime.now()))
      return false;

    _token = extractedUserData['token'].toString();
    _userId = extractedUserData['userId'].toString();
    _expiryDate = expiryDate;
    notifyListeners();
    autoLogout();
    return true;
  }
  Future<void> signUp (String? email, String? password,)async {
    return _authonticate(email, password, 'signUp');
  }
  Future<void> login (String? email, String? password,)async {
    return _authonticate(email, password, 'signInWithPassword');
  }

  void logout() async{
    _token = null;
    _userId = null;
    _expiryDate = null;
    if(_authTimer != null)
      _authTimer = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();  //prefs.remove('userData');
  }

  void autoLogout(){
    if(_authTimer != null)
      _authTimer!.cancel();

    final timeToExpiry = _expiryDate!.difference(DateTime.now()).inSeconds;
    _authTimer = Timer(Duration(seconds: timeToExpiry),logout);
  }
}
