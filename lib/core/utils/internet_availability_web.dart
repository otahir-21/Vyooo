import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

Future<bool> hasInternetAccess() async {
  try {
    final results = await Connectivity()
        .checkConnectivity()
        .timeout(const Duration(seconds: 2));
    if (results.isEmpty) return false;
    if (results.length == 1 && results.first == ConnectivityResult.none) {
      return false;
    }
  } on Object {
    return false;
  }

  try {
    final resp = await http
        .get(
          Uri.parse('https://connectivitycheck.gstatic.com/generate_204'),
        )
        .timeout(const Duration(seconds: 5));
    return resp.statusCode == 204 || resp.statusCode == 200;
  } on Object {
    return false;
  }
}
