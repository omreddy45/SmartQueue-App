import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
      await Firebase.initializeApp();
      runApp(const MyApp());
  } catch (e) {
      print("Firebase initialization error: $e");
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                "Firebase Initialization Failed:\n\n$e\n\nMake sure google-services.json is in android/app/",
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'SmartQueue',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          fontFamily: 'Roboto', // Default, but can be customized
          scaffoldBackgroundColor: const Color(0xFFF8FAFC), // gray-50 equivalent
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
