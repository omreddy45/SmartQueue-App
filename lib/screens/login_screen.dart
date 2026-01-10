import 'package:flutter/material.dart';
import 'welcome_screen.dart';

// Deprecated: This screen is replaced by the new Auth Flow.
// Redirecting to WelcomeScreen just in case it is still referenced.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeScreen();
  }
}
