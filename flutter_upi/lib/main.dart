import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as ui_auth;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_popup_window_widget/on_popup_window_widget.dart';

//made some minor changes
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
      darkTheme: ThemeData.from(
        colorScheme: ColorScheme.dark(),
        useMaterial3: true,
      ),
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

  Future<String> getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<String> getWhatsNew() async {
    String? data;
    final snapshot =
        await FirebaseFirestore.instance.doc('app_config/whats_new').get();
    if (snapshot.exists && snapshot.data() != null) {
      data = snapshot.data()?['content'] ?? 'Contact Developer for updates';
    } else {
      data = 'Contact Developer for updates';
    }
    setState(() {
      _content = data;
    });
    return data!;
  }

  Future<String> getFirestoreVersion() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.doc('app_config/whats_new').get();
      return snapshot.data()?['version'] ?? 'Unknown';
    } catch (e) {
      debugPrint("Error fetching Firestore version: $e");
      return 'Unknown';
    }
  }

  Future<void> setSharedPrefs() async {
    final instance = await SharedPreferences.getInstance();
    final uid = _user?.uid;
    print("set ${uid}_shown to true");
    instance.setBool("${uid}_shown", true);
  }

  String? _local;
  Future<void> check() async {
    final localVersion = await getAppVersion();
    setState(() {
      _local = localVersion;
    });
    final firestoreVersion = await getFirestoreVersion();
    final data = await getSharedPrefData();
    print("Local Version: $localVersion");
    print("Firestore Version: $firestoreVersion");

    bool? data_bool;
    if (localVersion != firestoreVersion) {
      print("local version and firebase version not same");
      data_bool = true;
    } else if (localVersion == firestoreVersion && data == true) {
      data_bool = false;
      print(
        "local ,firebase version same and data is true\nsetting data_bool to ${data_bool}",
      );
    } else if (localVersion == firestoreVersion && data == false) {
      data_bool = true;
      print(
        "local ,firebase version same and data is true\nsetting data_bool to ${data_bool}",
      );
    }
    setState(() {
      _toShow = data_bool!;
      print("_toShow changed to : ${_toShow}");
    });
  }

  Future<bool> getSharedPrefData() async {
    final instance = await SharedPreferences.getInstance();
    final String? uid = _user?.uid;

    if (uid == null) {
      return false;
    }

    final bool data = instance.getBool("${uid}_shown") ?? false;
    print("shared prefs data fetched: ${data}");
    return data;
  }

  String? _content;
  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    Future.microtask(() async {
      await fetchUPIIdFromFirestore();
      await getWhatsNew(); // fetch what's new content
      await check();
    });
    //
    // _toShow = true;
  }

  bool _toShow = false;
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
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Welcome, ${_user?.displayName?.isNotEmpty == true ? _user!.displayName : (_user?.email ?? 'User')}',
                          ),
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
                                      version: QrVersions.auto,
                                      dataModuleStyle: QrDataModuleStyle(
                                        color: const Color.fromARGB(
                                          255,
                                          148,
                                          20,
                                          20,
                                        ),
                                        dataModuleShape:
                                            QrDataModuleShape.circle,
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
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      "Version: ${_local ?? ''}",
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),

            // Popup Overlay
            if (_toShow)
              Positioned.fill(
                child: Container(
                  color: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withOpacity(0.8),
                  alignment: Alignment.center,
                  child: OnPopupWindowWidget.widgetMode(
                    mainWindowAlignment: Alignment.center,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(
                          width: 200,
                          child: Text(
                            "What's New",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await setSharedPrefs();
                            setState(() {
                              _toShow = false;
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _content ?? "Loading update details...",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
