import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';

class QrService {
  // Generate QR code image widget
  static Widget generateQRCode(String data, {double size = 200}) {
    return QrImageView(data: data, version: QrVersions.auto, size: size);
  }

  // Method to scan QR code from image file
  static Future<String?> scanQrFromImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);

    if (photo == null) return null;

    try {
      // Use mobile_scanner to decode QR from file
      final qrCode = await MobileScannerPlugin.scanImage(path: photo.path);

      if (qrCode.barcodes.isNotEmpty) {
        return qrCode.barcodes.first.rawValue;
      }
    } catch (e) {
      print('Error scanning QR code: $e');
    }

    return null;
  }
}

// QR Scanner page using mobile_scanner
class QRScannerPage extends StatefulWidget {
  const QRScannerPage({Key? key}) : super(key: key);

  @override
  QRScannerPageState createState() => QRScannerPageState();
}

class QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController controller = MobileScannerController();
  bool _scanComplete = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                );
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller.cameraFacingState,
              builder: (context, state, child) {
                return Icon(
                  state == CameraFacing.front
                      ? Icons.camera_front
                      : Icons.camera_rear,
                );
              },
            ),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (_scanComplete) return;
          final barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes[0].rawValue != null) {
            _scanComplete = true;
            final code = barcodes[0].rawValue!;
            Navigator.pop(context, code);
          }
        },
      ),
    );
  }
}
