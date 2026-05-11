import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Same endpoint many Android builds use for captive-portal checks; small response.
Uri get _connectivityProbeUri =>
    Uri.parse('https://connectivitycheck.gstatic.com/generate_204');

/// Uses OS connectivity, then verifies **actual** reachability (DNS + TLS can still lie).
///
/// Wi‑Fi off with **mobile data on** usually means you still have internet — we correctly
/// report online. You only see [kNoInternetUserMessage] when there is no usable path.
Future<bool> hasInternetAccess() async {
  List<ConnectivityResult> connectivityResults;
  try {
    connectivityResults = await Connectivity()
        .checkConnectivity()
        .timeout(const Duration(seconds: 2));
  } on Object {
    return false;
  }

  // connectivity_plus: offline is a single `none` entry (per plugin docs).
  if (connectivityResults.isEmpty ||
      (connectivityResults.length == 1 &&
          connectivityResults.first == ConnectivityResult.none)) {
    return false;
  }

  // Some devices briefly report a transport while nothing routes; verify with HTTP.
  try {
    final resp = await http
        .get(
          _connectivityProbeUri,
          headers: const {'User-Agent': 'VyoooConnectivity/1'},
        )
        .timeout(const Duration(seconds: 5));
    if (resp.statusCode == 204 || resp.statusCode == 200) {
      return true;
    }
  } on Object {
    // Fall through to DNS-only probe below.
  }

  try {
    final list = await InternetAddress.lookup(
      'google.com',
    ).timeout(const Duration(seconds: 3));
    return list.isNotEmpty;
  } on Object {
    return false;
  }
}
