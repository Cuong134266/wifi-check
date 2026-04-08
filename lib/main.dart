import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'screens/checkin_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  await GoogleSignIn.instance.initialize(
    clientId: kIsWeb
        ? '22727687094-p116tl7os4okfvpn6pla4614fusjis9u.apps.googleusercontent.com'
        : null,
    serverClientId: kIsWeb
        ? null
        : '569344189606-3uakma469t0dca00664jqgtj881b42hk.apps.googleusercontent.com', 
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UXTeam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      // Mở thẳng Home, không cần login trước
      home: const CheckinScreen(),
    );
  }
}
