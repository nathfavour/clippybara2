import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  String? _serverUrl;
  bool _connected = false;
  final Duration _timeout = const Duration(seconds: 5);
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  // Connection status stream for UI updates
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  bool get isConnected => _connected;
  String? get serverUrl => _serverUrl;

  void dispose() {
    _connectionStatusController.close();
  }

  void setServerUrl(String url) {
    // Normalize URL by removing trailing slashes
    _serverUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  Future<bool> testConnection() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      _updateConnectionStatus(false);
      return false;
    }

    try {
      final response = await http
          .get(Uri.parse('$_serverUrl/api/clipboard'))
          .timeout(_timeout);

      _updateConnectionStatus(
        response.statusCode >= 200 && response.statusCode < 300,
      );
      return _connected;
    } catch (e) {
      _updateConnectionStatus(false);
      return false;
    }
  }

  Future<String?> getClipboard() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      return null;
    }

    try {
      final response = await http
          .get(Uri.parse('$_serverUrl/api/clipboard'))
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        return data['text'] as String;
      }
    } catch (e) {
      // Silently fail as this is called frequently
      return null;
    }

    return null;
  }

  Future<bool> setClipboard(String text) async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_serverUrl/api/clipboard'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'text': text}),
          )
          .timeout(_timeout);

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  void _updateConnectionStatus(bool status) {
    if (_connected != status) {
      _connected = status;
      _connectionStatusController.add(status);
    }
  }
}
