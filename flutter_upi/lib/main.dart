import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  String? _upiQrData;

  void _onGeneratePressed() {
    final amount = _amountController.text.trim();
    final id = _idController.text.trim();

    if (amount.isNotEmpty && id.isNotEmpty) {
      setState(() {
        _upiQrData =
            'upi://pay?pa=$id&pn=${Uri.encodeComponent("Rohan Batra")}&am=$amount&cu=INR';
        debugPrint('QR Data: $_upiQrData');
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both ID and Amount')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo',
      themeMode: ThemeMode.system,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Demo'), centerTitle: true),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              AnimatedContainer(duration: Duration(milliseconds: 300),
              child:
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _upiQrData != null
                    ? QrImageView(
                  key: ValueKey(_upiQrData),
                  data: _upiQrData!,
                  size: 250,
                  version: QrVersions.auto,
                  gapless: false,
                  backgroundColor: Colors.white,
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Colors.black,
                  ),
                )
                    : const SizedBox(
                  height: 250,
                  child: Placeholder(),
                ),
              ),
              ),
            const SizedBox(height: 30),
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Amount',
                  hintText: 'Enter Amount',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                controller: _amountController,
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'UPI ID',
                  hintText: 'Enter UPI ID (e.g., rohan@upi)',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
                controller: _idController,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Generate UPI QR'),
                  onPressed: _onGeneratePressed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}