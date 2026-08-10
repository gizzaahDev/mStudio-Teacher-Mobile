import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _requestTimeout = Duration(seconds: 20);
  static const _uploadTimeout = Duration(minutes: 2);
  static const _cacheFolderName = 'magical_lms_teacher_api_v2';
  static final Map<String, dynamic> _memoryCache = {};

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final baseUrl = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath').replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw ApiException(
          'Sign in is required before calling the Magical LMS backend.');
    }
    final token = await user.getIdToken().timeout(_requestTimeout);
    if (token == null || token.isEmpty) {
      throw ApiException(
          'Could not obtain a Firebase sign-in token. Please sign in again.');
    }
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Directory get _cacheRoot => Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}$_cacheFolderName',
      );

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'signed-out';

  Directory get _userCacheDirectory => Directory(
        '${_cacheRoot.path}${Platform.pathSeparator}${_stableHash(_uid)}',
      );

  File _cacheFile(Uri uri) => File(
        '${_userCacheDirectory.path}${Platform.pathSeparator}${_stableHash(uri.toString())}.json',
      );

  String _stableHash(String input) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool refresh = false,
  }) async {
    final uri = _uri(path, query);
    final memoryKey = '$_uid|$uri';
    if (!refresh && _memoryCache.containsKey(memoryKey)) {
      return _memoryCache[memoryKey];
    }
    final cacheFile = _cacheFile(uri);
    final cached = await _readCache(cacheFile);
    if (!refresh && cached != null) {
      _memoryCache[memoryKey] = cached;
      return cached;
    }

    try {
      final headers = await _headers();
      http.Response? response;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          response =
              await _client.get(uri, headers: headers).timeout(_requestTimeout);
          break;
        } on http.ClientException catch (_) {
          // Retry once for brief backend/ngrok restarts.
        } on SocketException catch (_) {
          // Retry once for brief backend/ngrok restarts.
        }
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
        }
      }
      if (response == null) {
        if (cached != null) return cached;
        throw ApiException(
          'The backend connection was interrupted. Check that the backend and ngrok are running, then tap refresh.',
        );
      }
      final result = _decode(response);
      _memoryCache[memoryKey] = result;
      await _writeCache(cacheFile, result);
      return result;
    } on TimeoutException {
      if (cached != null) return cached;
      throw ApiException('The server took too long to respond. Try refresh.');
    } on http.ClientException catch (_) {
      if (cached != null) return cached;
      throw ApiException(
          'The backend connection was interrupted. Check the server and tap refresh.');
    } on SocketException catch (_) {
      if (cached != null) return cached;
      throw ApiException(
          'The backend is temporarily unavailable. Check the connection and tap refresh.');
    }
  }

  Future<dynamic> post(String path, {Object? body}) async =>
      _send('POST', path, body);

  Future<dynamic> put(String path, {Object? body}) async =>
      _send('PUT', path, body);

  Future<dynamic> patch(String path, {Object? body}) async =>
      _send('PATCH', path, body);

  Future<dynamic> delete(String path, {Object? body}) async =>
      _send('DELETE', path, body);

  Future<dynamic> _send(String method, String path, Object? body) async {
    final headers = await _headers();
    try {
      http.Response? response;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final request = http.Request(method, _uri(path));
          request.headers.addAll(headers);
          if (body != null) request.body = jsonEncode(body);
          final streamed = await request.send().timeout(_requestTimeout);
          response =
              await http.Response.fromStream(streamed).timeout(_requestTimeout);
          break;
        } on http.ClientException catch (_) {
          // Retry once when the backend/ngrok connection restarts mid-save.
        } on SocketException catch (_) {
          // Retry once when the backend/ngrok connection restarts mid-save.
        }
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
        }
      }
      if (response == null) {
        throw ApiException(
            'The connection closed before the change was saved. Check the backend and ngrok, then try again.');
      }
      final result = _decode(response);
      await clearCache();
      return result;
    } on TimeoutException {
      throw ApiException('The server took too long to save. Please try again.');
    } on http.ClientException catch (_) {
      throw ApiException(
          'The backend connection was interrupted. Please try again.');
    } on SocketException catch (_) {
      throw ApiException(
          'The backend is temporarily unavailable. Please try again.');
    }
  }

  Future<Map<String, dynamic>> uploadRaw(String path, File file) async {
    final headers = await _headers(json: false);
    headers['Content-Type'] = 'application/octet-stream';
    headers['x-file-name'] = file.uri.pathSegments.last;
    try {
      final response = await _client
          .post(
            _uri(path),
            headers: headers,
            body: await file.readAsBytes(),
          )
          .timeout(_uploadTimeout);
      final result = _decode(response);
      await clearCache();
      return (result as Map).cast<String, dynamic>();
    } on TimeoutException {
      throw ApiException('The file upload timed out. Please try again.');
    }
  }

  Future<dynamic> _readCache(File file) async {
    try {
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(File file, dynamic value) async {
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(value), flush: false);
    } catch (_) {
      // Cache failure must never block the app or its API result.
    }
  }

  Future<void> clearCache() async {
    final prefix = '$_uid|';
    _memoryCache.removeWhere((key, _) => key.startsWith(prefix));
    try {
      final directory = _userCacheDirectory;
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {
      // The cache is disposable and will be replaced by later API responses.
    }
  }

  Stream<String> liveUpdates() async* {
    final request = http.Request('GET', _uri('/api/live-events'));
    request.headers.addAll(await _headers(json: false));
    request.headers['Accept'] = 'text/event-stream';
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Could not connect to live database updates.',
          statusCode: response.statusCode);
    }
    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (line.startsWith('data: ')) {
        final value = line.substring(6).trim();
        if (value.isNotEmpty && value != 'connected') yield value;
      }
    }
  }

  dynamic _decode(http.Response response) {
    final raw = response.body.trim();
    dynamic data;
    try {
      data = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    } catch (_) {
      data = <String, dynamic>{'message': raw};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map
          ? '${data['message'] ?? data['error'] ?? 'Request failed'}'
          : 'Request failed';
      throw ApiException(message, statusCode: response.statusCode);
    }
    return data;
  }
}
