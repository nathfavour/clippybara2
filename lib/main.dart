import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clippybara',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clippybara Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to Clippybara!'),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClipboardSyncPage()),
                );
              },
              child: const Text('Start Clipboard Sync'),
            ),
          ],
        ),
      ),
    );
  }
}

class ClipboardSyncPage extends StatefulWidget {
  const ClipboardSyncPage({super.key});
  @override
  State<ClipboardSyncPage> createState() => _ClipboardSyncPageState();
}

class _ClipboardSyncPageState extends State<ClipboardSyncPage> {
  final TextEditingController _serverUrlController = TextEditingController();
  String _status = "Disconnected";
  String _clipboardContent = "";

  @override
  void initState() {
    super.initState();
    _pollClipboard();
  }

  void _pollClipboard() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      Clipboard.getData(Clipboard.kTextPlain).then((data) {
        if (data != null && data.text != null) {
          setState(() {
            _clipboardContent = data.text!;
          });
        }
      });
    }
  }

  void _scanQRCode() async {
    setState(() {
      _serverUrlController.text = "http://192.168.1.100:8000";
      _status = "Connected";
    });
  }

  void _connectManually() {
    String url = _serverUrlController.text.trim();
    if (url.isNotEmpty) {
      setState(() {
        _status = "Connected";
      });
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Clipboard Sync")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: "Server URL",
                hintText: "Enter server URL or scan QR code",
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _connectManually,
                  child: const Text("Connect"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _scanQRCode,
                  child: const Text("Scan QR Code"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text("Status: $_status"),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            const Text("Local Clipboard:"),
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey[200],
              child: Text(_clipboardContent),
            ),
          ],
        ),
      ),
    );
  }
}
