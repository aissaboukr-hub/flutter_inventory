import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_inventory/theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _torchEnabled = false;
  bool _scanned = false;
  String? _lastScanned;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller?.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.start();
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_scanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty || code == _lastScanned) return;

    setState(() { _scanned = true; _lastScanned = code; });

    Navigator.pop(context, {'barcode': code});
  }

  void _enterManually() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saisie manuelle'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'Code-barres ou code produit',
            prefixIcon: Icon(Icons.qr_code),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      Navigator.pop(context, {'barcode': result});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner un code-barres'),
        actions: [
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
            color: _torchEnabled ? Colors.yellow : Colors.white,
            onPressed: () {
              _controller?.toggleTorch();
              setState(() => _torchEnabled = !_torchEnabled);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            color: Colors.white,
            onPressed: () => _controller?.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Caméra
          MobileScanner(
            controller: _controller!,
            onDetect: _onBarcodeDetected,
          ),

          // Overlay de scan
          _buildScanOverlay(),

          // Boutons bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = constraints.maxWidth * 0.7;
      final top = (constraints.maxHeight - size) / 2.5;

      return Stack(
        children: [
          // Fond semi-transparent
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(color: Colors.transparent),
                Center(
                  child: Container(
                    width: size,
                    height: size * 0.6,
                    margin: EdgeInsets.only(top: top - constraints.maxHeight / 2),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Coins du cadre de scan
          Center(
            child: Transform.translate(
              offset: Offset(0, -constraints.maxHeight / 10),
              child: SizedBox(
                width: size,
                height: size * 0.6,
                child: CustomPaint(painter: _ScanCornerPainter()),
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: const Column(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
                SizedBox(height: 8),
                Text(
                  'Pointez la caméra vers un code-barres',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildBottomBar() => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Colors.black, Colors.transparent],
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionButton(Icons.keyboard, 'Saisir manuellement', _enterManually),
      ],
    ),
  );

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    ),
  );
}

class _ScanCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;
    const radius = 12.0;

    // Coin haut-gauche
    canvas.drawLine(const Offset(0, cornerLength), const Offset(0, radius), paint);
    canvas.drawArc(const Rect.fromLTWH(0, 0, radius * 2, radius * 2), 3.14159, 0.5 * 3.14159, false, paint);
    canvas.drawLine(const Offset(radius, 0), const Offset(cornerLength, 0), paint);

    // Coin haut-droit
    canvas.drawLine(Offset(size.width - cornerLength, 0), Offset(size.width - radius, 0), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - radius * 2, 0, radius * 2, radius * 2), 1.5 * 3.14159, 0.5 * 3.14159, false, paint);
    canvas.drawLine(Offset(size.width, radius), Offset(size.width, cornerLength), paint);

    // Coin bas-gauche
    canvas.drawLine(Offset(0, size.height - cornerLength), Offset(0, size.height - radius), paint);
    canvas.drawArc(Rect.fromLTWH(0, size.height - radius * 2, radius * 2, radius * 2), 0.5 * 3.14159, 0.5 * 3.14159, false, paint);
    canvas.drawLine(Offset(radius, size.height), Offset(cornerLength, size.height), paint);

    // Coin bas-droit
    canvas.drawLine(Offset(size.width - cornerLength, size.height), Offset(size.width - radius, size.height), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - radius * 2, size.height - radius * 2, radius * 2, radius * 2), 0, 0.5 * 3.14159, false, paint);
    canvas.drawLine(Offset(size.width, size.height - radius), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
