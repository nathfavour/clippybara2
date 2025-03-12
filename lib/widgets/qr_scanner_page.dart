import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({Key? key}) : super(key: key);

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  // Create the controller without ValueNotifiers that don't exist in v6.0.7
  final MobileScannerController controller = MobileScannerController();
  bool _scanComplete = false;
  bool _hasError = false;
  String _scanStatus = 'Scanning...';
  String _errorMessage = '';
  bool _isUsingFrontCamera = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScanStatus('Position the QR code within the frame');
    });
  }

  void _updateScanStatus(String message) {
    if (mounted) {
      setState(() {
        _scanStatus = message;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = message;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _hasError = false;
            _errorMessage = '';
          });
        }
      });
    }
  }

  void _toggleTorch() async {
    try {
      await controller.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (e) {
      _showError('Failed to toggle torch: $e');
    }
  }

  void _switchCamera() async {
    try {
      await controller.switchCamera();
      setState(() {
        _isUsingFrontCamera = !_isUsingFrontCamera;
      });
    } catch (e) {
      _showError('Failed to switch camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          // Replace ValueListenableBuilder with direct state
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: Icon(
                _isUsingFrontCamera ? Icons.camera_front : Icons.camera_rear),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner view
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Text(
                  'Scanner error: ${error.errorCode}',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              );
            },
          ),

          // Overlay with scan frame
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
              ),
              child: Stack(
                children: [
                  // Centered transparent scanner box
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2.0),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                      ),
                    ),
                  ),

                  // Status message
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: _hasError ? Colors.red : Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _hasError ? _errorMessage : _scanStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanComplete) return;

    // Debug: print all barcodes found
    print('Detected ${capture.barcodes.length} barcodes');
    for (final barcode in capture.barcodes) {
      print('Barcode: ${barcode.rawValue}, format: ${barcode.format}');
    }

    // Filter QR codes with valid URLs
    final validBarcodes = capture.barcodes.where((barcode) {
      final rawValue = barcode.rawValue ?? '';
      return rawValue.isNotEmpty &&
          (rawValue.startsWith('http://') || rawValue.startsWith('https://'));
    }).toList();

    if (validBarcodes.isNotEmpty) {
      _processScanResult(validBarcodes.first.rawValue!);
    } else if (capture.barcodes.isNotEmpty &&
        capture.barcodes.first.rawValue != null) {
      // Found a barcode, but not a valid URL
      _showError('Invalid QR code: Not a valid URL');
    }
  }

  void _processScanResult(String code) {
    if (_scanComplete) return;

    // Validate that it's a reasonable URL before returning
    if (!code.startsWith('http://') && !code.startsWith('https://')) {
      _showError('Invalid URL format');
      return;
    }

    setState(() {
      _scanComplete = true;
      _scanStatus = 'URL found! Connecting...';
    });

    // Visual feedback that the QR code was successfully scanned
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pop(context, code);
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
