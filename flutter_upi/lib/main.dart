import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as ui_auth;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UPI QR App',
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) {
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return ui_auth.SignInScreen(
                  providers: [
                    ui_auth.EmailAuthProvider(),
                    GoogleProvider(
                      clientId:
                          '1:276414625228:web:aeb60f3a5b81716d5fd969.apps.googleusercontent.com',
                    ),
                  ],
                );
              }
              return const HomePage();
            },
          );
        },
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  String? _upiQrData;

  /// Fetch UPI ID from Firestore (document: config/upi)
  Future<void> fetchUPIIdFromFirestore() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.doc('config/upi').get();
      final upiId = snapshot.data()?['upi_id'];
      if (upiId != null && upiId is String) {
        _idController.text = upiId;
        _updateQrCode(); // update QR once we have UPI ID
      }
    } catch (e) {
      debugPrint("Error fetching UPI ID: $e");
    }
  }

  /// Build UPI QR data
  void _updateQrCode() {
    final id = _idController.text.trim();
    final amount = _amountController.text.trim();

    if (id.isNotEmpty) {
      _upiQrData =
          'upi://pay?pa=$id&pn=${Uri.encodeComponent("Rohan Batra")}&cu=INR';

      if (amount.isNotEmpty) {
        _upiQrData = '$_upiQrData&am=$amount';
      }

      setState(() {}); // refresh
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUPIIdFromFirestore();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI QR Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Welcome, ${user?.email ?? 'User'}'),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _upiQrData != null
                  ? QrImageView(
                      key: ValueKey(_upiQrData),
                      data: _upiQrData!,
                      size: 250,
                      backgroundColor:Colors.white,
                      // foregroundColor: Colors.black,
                      version: QrVersions.auto,
                      dataModuleStyle: QrDataModuleStyle(
                        color:const Color.fromARGB(255, 148, 20, 20),
                        dataModuleShape: QrDataModuleShape.circle,
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('placeholder'),
                      height: 250,
                    ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              onChanged: (value) => _updateQrCode(),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _idController,
              onChanged: (value) async {
                _updateQrCode();
                await FirebaseFirestore.instance
                    .doc("config/upi")
                    .set({'upi_id': value});
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'UPI ID (e.g., rohan@upi)',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
            ),
          ],
        ),
      ),
    );
  }
}