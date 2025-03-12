import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class ClipboardService {
  final ApiService _apiService;
  String _lastContent = '';
  DateTime _lastUpdate = DateTime.now();
  Timer? _pollingTimer;

  // Used for UI to display current clipboard content
  final StreamController<String> _clipboardContentController =
      StreamController<String>.broadcast();

  Stream<String> get clipboardContent => _clipboardContentController.stream;

  ClipboardService(this._apiService);

  Future<void> initialize() async {
    // Start monitoring clipboard
    _startMonitoring();

    // Initially sync with server
    if (_apiService.isConnected) {
      await syncFromServer();
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
    _clipboardContentController.close();
  }

  void _startMonitoring() {
    // Cancel any existing timer
    _pollingTimer?.cancel();

    // Check every 2 seconds for changes
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_apiService.isConnected) return;

      await _checkLocalClipboard();
      await _checkServerClipboard();
    });
  }

  Future<void> _checkLocalClipboard() async {
    try {
      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      String currentContent = data?.text ?? '';

      // Only update if content changed and not too soon after last update
      if (currentContent.isNotEmpty &&
          currentContent != _lastContent &&
          DateTime.now().difference(_lastUpdate).inMilliseconds > 1000) {
        _updateLastContent(currentContent);

        // Send to server
        await _apiService.setClipboard(currentContent);
      }
    } catch (e) {
      // Clipboard access can sometimes fail, just log and continue
      print('Error accessing clipboard: $e');
    }
  }

  Future<void> _checkServerClipboard() async {
    try {
      String? serverContent = await _apiService.getClipboard();

      // Only update if content is different and not empty
      if (serverContent != null &&
          serverContent.isNotEmpty &&
          serverContent != _lastContent &&
          DateTime.now().difference(_lastUpdate).inMilliseconds > 1000) {
        _updateLastContent(serverContent);

        // Update local clipboard
        await Clipboard.setData(ClipboardData(text: serverContent));
      }
    } catch (e) {
      // Server communication can fail, just continue
      print('Error getting server clipboard: $e');
    }
  }

  void _updateLastContent(String content) {
    _lastContent = content;
    _lastUpdate = DateTime.now();
    _clipboardContentController.add(content);
  }

  Future<void> syncToServer() async {
    try {
      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        _updateLastContent(data!.text!);
        await _apiService.setClipboard(data.text!);
      }
    } catch (e) {
      print('Error syncing to server: $e');
    }
  }

  Future<void> syncFromServer() async {
    try {
      String? serverContent = await _apiService.getClipboard();
      if (serverContent != null && serverContent.isNotEmpty) {
        _updateLastContent(serverContent);
        await Clipboard.setData(ClipboardData(text: serverContent));
      }
    } catch (e) {
      print('Error syncing from server: $e');
    }
  }

  // Save server URL to persistent storage
  Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);

    // Add to recent servers list
    List<String> recentServers = prefs.getStringList('recent_servers') ?? [];
    if (recentServers.contains(url)) {
      recentServers.remove(url);
    }
    recentServers.insert(0, url);

    // Keep only the latest 10 servers
    if (recentServers.length > 10) {
      recentServers = recentServers.sublist(0, 10);
    }

    await prefs.setStringList('recent_servers', recentServers);
  }

  // Load saved server URL
  Future<String?> getSavedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_url');
  }

  // Get list of recent server URLs
  Future<List<String>> getRecentServers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('recent_servers') ?? [];
  }
}
