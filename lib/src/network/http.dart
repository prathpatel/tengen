import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tengen/src/constants.dart';

/// The raw HTTP client. Override it in tests with a `MockClient`.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// The OGS REST API client.
final ogsHttpProvider = Provider<OgsHttp>((ref) => OgsHttp(ref.watch(httpClientProvider)));

class OgsHttpException implements Exception {
  const OgsHttpException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'OgsHttpException($statusCode): $message';
}

/// HTTP client for the OGS REST API.
///
/// OGS authenticates the website with Django session cookies, protected by a CSRF token. This
/// client keeps the two cookies it needs (`sessionid` and `csrftoken`) and sends them back, with
/// the `X-CSRFToken` and `Referer` headers Django requires on unsafe methods, just like the web
/// client does.
class OgsHttp {
  OgsHttp(this._client);

  final http.Client _client;
  final Map<String, String> _cookies = {};

  static const trackedCookies = {'sessionid', 'csrftoken'};

  Map<String, String> get cookies => Map.unmodifiable(_cookies);

  void restoreCookies(Map<String, String> cookies) {
    _cookies
      ..clear()
      ..addAll({
        for (final e in cookies.entries)
          if (trackedCookies.contains(e.key)) e.key: e.value,
      });
  }

  void clearCookies() => _cookies.clear();

  Map<String, String> _headers({required bool unsafe, bool json = false}) => {
    'Accept': 'application/json',
    if (json) 'Content-Type': 'application/json',
    if (_cookies.isNotEmpty)
      'Cookie': _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
    if (unsafe) ...{'Referer': 'https://$kOgsHost/', 'X-CSRFToken': ?_cookies['csrftoken']},
  };

  void _storeCookies(http.BaseResponse response) {
    // The IO client joins repeated Set-Cookie headers with commas, and cookie expiry dates contain
    // commas too, so pick the cookies we care about by name.
    final header = response.headers['set-cookie'];
    if (header == null) return;
    for (final match in RegExp(r'(?:^|[,\s])(sessionid|csrftoken)=([^;,\s]*)').allMatches(header)) {
      final value = match.group(2)!;
      if (value.isEmpty || value == '""') {
        _cookies.remove(match.group(1));
      } else {
        _cookies[match.group(1)!] = value;
      }
    }
  }

  dynamic _decode(http.Response response) {
    _storeCookies(response);
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 400) {
      var message = 'Request failed (${response.statusCode})';
      try {
        final json = jsonDecode(body);
        if (json is Map) {
          final detail = json['error'] ?? json['detail'] ?? json['message'];
          if (detail != null) message = detail.toString();
        }
      } on FormatException {
        // Not JSON: keep the generic message.
      }
      throw OgsHttpException(response.statusCode, message);
    }
    return body.isEmpty ? null : jsonDecode(body);
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) async {
    final response = await _client.get(ogsUri(path, query), headers: _headers(unsafe: false));
    return _decode(response);
  }

  Future<dynamic> post(String path, Object? body) async {
    final response = await _client.post(
      ogsUri(path),
      headers: _headers(unsafe: true, json: true),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _client.delete(ogsUri(path), headers: _headers(unsafe: true));
    return _decode(response);
  }
}
