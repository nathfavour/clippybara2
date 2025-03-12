import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/platform_utils.dart';
import 'widgets/qr_scanner_page.dart';
import 'widgets/qr_display_widget.dart';

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
  bool _showQrCode = false;

  @override
  void initState() {
    super.initState();
    _pollClipboard();

    // Set a default server URL for demonstration
    _serverUrlController.text = "http://192.168.1.100:8000";
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

  Future<void> _handleQrCodeAction() async {
    if (PlatformUtils.isMobile) {
      // Show loading indicator while preparing camera
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Wait a moment to ensure the dialog is shown before navigating
      await Future.delayed(const Duration(milliseconds: 300));

      // Pop the loading dialog
      if (context.mounted) {
        Navigator.pop(context);

        // Navigate to QR scanner and get result
        final scannedUrl = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (context) => const QRScannerPage()),
        );

        if (scannedUrl != null && context.mounted) {
          // Update the URL input
          setState(() {
            _serverUrlController.text = scannedUrl;
            _status = "Connected";
          });

          // Show success message with the scanned URL
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully scanned: $scannedUrl'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // In a real app, you would connect to the server here
          // _connectToServer(scannedUrl);
        }
      }
    } else {
      // On desktop: Show/hide QR code
      setState(() {
        _showQrCode = !_showQrCode;
      });
    }
  }

  // Optional: Add a method to connect to server after scanning
  Future<void> _connectToServer(String url) async {
    // Show connecting indicator
    setState(() {
      _status = "Connecting...";
    });

    // Simulate connection delay
    await Future.delayed(const Duration(seconds: 1));

    // Update connection status (in real app, check actual connection)
    setState(() {
      _status = "Connected";
    });

    // Start clipboard sync in background
    // ...
  }

  void _connectManually() {
    String url = _serverUrlController.text.trim();
    if (url.isNotEmpty) {
      setState(() {
        _status = "Connected";
      });
      // In production: This is where you'd connect to the server with the typed URL
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
      body: SingleChildScrollView(
        child: Padding(
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
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _connectManually,
                      child: const Text("Connect"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleQrCodeAction,
                      child: Text(
                        PlatformUtils.isMobile
                            ? "Scan QR Code"
                            : _showQrCode
                                ? "Hide QR Code"
                                : "Show QR Code",
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text("Status: $_status"),

              // QR code section for desktop
              if (_showQrCode && PlatformUtils.isDesktop)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: QrDisplayWidget(
                    data: _serverUrlController.text.isEmpty
                        ? "http://192.168.1.100:8000"
                        : _serverUrlController.text,
                  ),
                ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              const Text("Local Clipboard:"),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                color: Colors.grey[200],
                child: Text(
                  _clipboardContent.isEmpty
                      ? "No clipboard content"
                      : _clipboardContent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
