import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as ui_auth;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
// import 'package:flutter_launcher_icons/web/web_template.dart';
import 'package:on_popup_window_widget/on_popup_window_widget.dart';

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

  User? _user;
  String? _upiQrData;

  /// Fetch UPI ID from Firestore (document: config/upi)
  Future<void> fetchUPIIdFromFirestore() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.doc('upi_users/${_user?.uid}').get();
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
      _upiQrData = 'upi://pay?pa=$id&cu=INR';

      if (amount.isNotEmpty) {
        _upiQrData = '$_upiQrData&am=$amount';
      }

      setState(() {}); // refresh
    }
  }

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    if (_user == null) {
      // If user is not logged in, redirect to sign-in screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to fetch user data. Please sign in again.'),
        ),
      );
    }
    fetchUPIIdFromFirestore();
  }

  bool _isPopUP = true;
  @override
  Widget build(BuildContext context) {
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
        child: Center(
          child: _isPopUP? OnPopupWindowWidget(
            child:Icon(Icons.currency_rupee_sharp, size: 50, color: Colors.red),
          ):Column(
            children: [
              Text('Welcome, ${_user?.email ?? 'User'}'),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child:
                    _upiQrData != null
                        ? QrImageView(
                          key: ValueKey(_upiQrData),
                          data: _upiQrData!,
                          size: 250,
                          backgroundColor: Colors.white,
                          // foregroundColor: Colors.black,
                          version: QrVersions.auto,
                          dataModuleStyle: QrDataModuleStyle(
                            color: const Color.fromARGB(255, 148, 20, 20),
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
                      .doc('upi_users/${_user?.uid}')
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
      ),
    );
  }
  @override
  @override
Widget build1(BuildContext context) {
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
    body: Stack(
      children: [
        // Background main content
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Welcome, ${_user?.email ?? 'User'}'),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _upiQrData != null
                    ? QrImageView(
                        key: ValueKey(_upiQrData),
                        data: _upiQrData!,
                        size: 250,
                        backgroundColor: Colors.white,
                        version: QrVersions.auto,
                        dataModuleStyle: QrDataModuleStyle(
                          color: const Color.fromARGB(255, 148, 20, 20),
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
                      .doc('upi_users/${_user?.uid}')
                      .set({'upi_id': value});
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'UPI ID (e.g., rohan@upi)',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isPopUP = !_isPopUP;
                  });
                },
                child: Text("Update popup to ${_isPopUP ? 'Hide' : 'Show'}"),
              ),
            ],
          ),
        ),

        // Floating Popup Icon (visible on top)
        if (_isPopUP)OnPopupWindowWidget(
              mainWindowAlignment: Alignment.center,
              child: Icon(Icons.currency_rupee_sharp, size: 50, color: Colors.red),
            ),
      ],
    ),
  );
}
}
