import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_initicon/flutter_initicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Future<XFile?> pickImage() async {
  final ImagePicker picker = ImagePicker();
  return await picker.pickImage(source: ImageSource.gallery); // or camera
}

Future<String?> uploadProfileImage(XFile image, String uid) async {
  final storageRef =
      FirebaseStorage.instance.ref().child("profile_images/$uid.jpg");

  final uploadTask = await storageRef.putData(await image.readAsBytes());
  final downloadUrl = await uploadTask.ref.getDownloadURL();
  return downloadUrl;
}

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
                        clientId: " 1:276414625228:web:86087c54d32a99a15fd969"),
                  ],
                );
              }
              return const MainUI();
            },
          );
        },
      },
    );
  }
}

class MainUI extends StatefulWidget {
  const MainUI({super.key});
  @override
  State<MainUI> createState() => _MainUI();
}

class _MainUI extends State<MainUI> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  User? _user;
  String? _upiQrData;
  String? _local;
  String? _content;
  bool _toShow = false;
  int _index = 0;
  String? _username;
  String? _email;
  String? _uid;

  /// Fetch UPI ID from Firestore (document: config/upi)
  Future<void> fetchUPIIdFromFirestore() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.doc('upi_users/${_uid}').get();
      final upiId = snapshot.data()?['upi_id'];
      if (upiId != null && upiId is String) {
        _idController.text = upiId;
        _updateQrCode(); // update QR once we have UPI ID
      }
    } catch (e) {
      debugPrint("Error fetching UPI ID: $e");
    }
  }

  Future<void> showWhatsNew(BuildContext context) async {
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text("🎉 What's New"),
              content: Text(_content!),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Close"))
              ],
            ));
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

  String? getUsername() {
    if (_user?.displayName?.isNotEmpty == true) {
      return _user!.displayName;
    }
    return "User X";
  }

  String? getEmail() {
    if (_user?.email?.isNotEmpty == true) {
      return _user!.email;
    }
    return "User_X@mail.com";
  }

  String? getUID() {
    return _user!.uid;
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

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    // _qrcode=QrCode.fromData(data: _upiQrData!, errorCorrectLevel:QrErrorCorrectLevel.H);
    Future.microtask(() async {
      await fetchUPIIdFromFirestore();
      await getWhatsNew(); // fetch what's new content
      await check();
    });
    _username = getUsername();
    _email = getEmail();
    _uid = getUID();

    //
    // _toShow = true;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> _pages = [
      Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Welcome, ${_username}',
                        ),
                        const SizedBox(height: 20),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: _upiQrData != null
                              ? SizedBox(
                                  width: 250,
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 200),
                                    curve: Curves.fastOutSlowIn,
                                    child: Card(
                                      elevation: 3,
                                      child: PrettyQrView.data(
                                        key: ValueKey(_upiQrData),
                                        data: _upiQrData!,
                                        decoration: PrettyQrDecoration(
                                            shape: PrettyQrSmoothSymbol(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .inverseSurface,
                                            ),
                                            image:
                                                const PrettyQrDecorationImage(
                                                    image: const AssetImage(
                                                      "assets/icons/icon.png",
                                                    ),
                                                    position:
                                                        PrettyQrDecorationImagePosition
                                                            .foreground)),
                                      ),
                                    ),
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
                            prefixIcon: const Icon(Icons.currency_rupee),
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
          if (kIsWeb)
            Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(
                        "https://github.com/MrRohanBatra/UPI-QRCODE-MAKER/raw/refs/heads/main/UPI-QR-MAKER/android/app-release.apk");
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode
                              .externalApplication); // or LaunchMode.platformDefault
                    } else {
                      // Handle error
                      print("Could not launch $url");
                    }
                  },
                  child: Text(
                    "Want Android App instead of web? Click here",
                    style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline),
                  ),
                ))
        ],
      ),
      Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),

                /// 🔹 Logged-in User Info
                const Text(
                  "User Info",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Initicon(
                  text: _username!,
                  size: 100,
                  elevation: 0,
                  backgroundColor: Colors.purple,
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Name: ${_username}"),
                    const SizedBox(height: 8),
                    Text("Email: ${_email}"),
                    const SizedBox(height: 8),
                    Text("UID: ${_uid}"),
                    const SizedBox(height: 16),
                  ],
                ),
                Center(
                    child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          _nameController.text = _username!;
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Update username'),
                              content: TextField(
                                controller: _nameController,
                                keyboardType: TextInputType.text,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text('Close'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    print("Updating Username");
                                    await _user?.updateDisplayName(
                                        _nameController.text.trim());
                                    print("Username Updated");

                                    await _user
                                        ?.reload(); // <- This is important!
                                    _user = FirebaseAuth.instance.currentUser;

                                    setState(() {
                                      _username = getUsername();
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            "Successfully Updated Username"),
                                        backgroundColor: Colors.yellow,
                                        duration: Duration(milliseconds: 500),
                                      ),
                                    );

                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Confirm'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text("Update Username"),
                      ),
                      ElevatedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('New Password'),
                                content: TextField(
                                  controller: _passwordController,
                                  keyboardType: TextInputType.text,
                                  autofocus: false,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: Text('Close'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.of(context).pop();

                                      await _user?.updatePassword(
                                          _passwordController.text.trim());
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              "Successfully Updated Password"),
                                          backgroundColor: Colors.yellow,
                                          duration: Duration(milliseconds: 500),
                                        ),
                                      );
                                      // await _user?.reload();

                                      // Re-fetch the user to get updated data
                                      // _user = FirebaseAuth.instance.currentUser;

                                      setState(() {}); // Trigger UI update
                                    },
                                    child: Text('Confirm'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text("Change Password")),
                    ],
                  ),
                )),
                const Divider(height: 40, thickness: 1.5),

                /// 🔹 Developer Info
                const Text(
                  "App Developer",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const CircleAvatar(
                  radius: 60,
                  backgroundImage: const NetworkImage(
                    "https://avatars.githubusercontent.com/u/95527939?v=4",
                  ),
                ),
                const SizedBox(height: 12),
                const Text("Name: Rohan Batra"),
                const Text("Email: rohanbatra.in@gmail.com"),
                const Text("Mobile: 9818888495"),
                const SizedBox(
                  height: 20,
                ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    // crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      GestureDetector(
                        child: const FaIcon(FontAwesomeIcons.linkedin),
                        onTap: () async {
                          final url = Uri.parse(
                              "https://www.linkedin.com/in/rohan-batra160705/");
                          if (!await launchUrl(url,
                              mode: LaunchMode.externalApplication)) {
                            throw 'Could not launch $url';
                          }
                        },
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      GestureDetector(
                        child: const FaIcon(FontAwesomeIcons.github),
                        onTap: () async {
                          final url = Uri.parse(
                              "https://www.linkedin.com/in/rohan-batra160705/");
                          if (!await launchUrl(url,
                              mode: LaunchMode.externalApplication)) {
                            throw 'Could not launch $url';
                          }
                        },
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      GestureDetector(
                        child: const FaIcon(FontAwesomeIcons.instagram),
                        onTap: () async {
                          final url = Uri.parse(
                              "https://www.instagram.com/rohanbatra1607/");
                          if (!await launchUrl(url,
                              mode: LaunchMode.externalApplication)) {
                            throw "Could not launch $url";
                          }
                        },
                      ),
                      SizedBox(
                        width: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                GestureDetector(
                  child: const Text(
                    "🎉 What's New",
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline),
                  ),
                  onTap: () async {
                    await showWhatsNew(context);
                  },
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "App Version: $_local",
                style: TextStyle(
                    fontFamily: "monospace",
                    fontSize: 13,
                    color: Colors.redAccent),
              ),
            ),
          ),
        ],
      )
    ];
    // print(Platform.isAndroid);
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI QR MAKER'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SafeArea(top: false, child: _pages[_index]),
      bottomNavigationBar: BottomNavigationBar(
        enableFeedback: true,
        useLegacyColorScheme: false,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        onTap: (value) {
          setState(() {
            _index = value;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "About"),
        ],
      ),
    );
  }
}
