import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';

class StudentAuthScreen extends StatefulWidget {
  const StudentAuthScreen({super.key});

  @override
  State<StudentAuthScreen> createState() => _StudentAuthScreenState();
}

class _StudentAuthScreenState extends State<StudentAuthScreen> {
  // 0: Login, 1: Signup
  int _mode = 0;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(), // Back button
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               Icon(LucideIcons.graduationCap, size: 64, color: Colors.blue.shade300),
               const SizedBox(height: 24),
               Text(
                 _mode == 0 ? "Student Login" : "Create Student Account",
                 style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 32),
               
               if (_mode == 1) ...[
                 TextField(
                   controller: _nameCtrl,
                   decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(LucideIcons.user), border: OutlineInputBorder()),
                 ),
                 const SizedBox(height: 16),
               ],
               
               TextField(
                 controller: _emailCtrl,
                 decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(LucideIcons.mail), border: OutlineInputBorder()),
                 keyboardType: TextInputType.emailAddress,
               ),
               const SizedBox(height: 16),
               TextField(
                 controller: _passCtrl,
                 decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(LucideIcons.lock), border: OutlineInputBorder()),
                 obscureText: true,
               ),
               const SizedBox(height: 24),
               
               ElevatedButton(
                 onPressed: _isLoading ? null : _handleAuth,
                 style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.all(16),
                   backgroundColor: Colors.blue,
                   foregroundColor: Colors.white,
                 ),
                 child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(_mode == 0 ? "Login" : "Sign Up", style: const TextStyle(fontSize: 18)),
               ),
               
               const SizedBox(height: 16),
               TextButton(
                 onPressed: () => setState(() => _mode = _mode == 0 ? 1 : 0),
                 child: Text(_mode == 0 ? "New here? Create Account" : "Already have an account? Login"),
               )
            ],
          ),
        ),
      ),
    );
  }

  void _handleAuth() async {
    setState(() => _isLoading = true);
    final state = Provider.of<AppState>(context, listen: false);

    String? error;

    if (_mode == 0) {
      error = await state.login(_emailCtrl.text, _passCtrl.text);
    } else {
      bool signupSuccess = await state.signupStudent(_emailCtrl.text, _passCtrl.text, _nameCtrl.text);
      error = signupSuccess ? null : "Signup Failed";
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        // Pop back to home which will redirect based on Auth State
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Authentication Failed: $error")));
      }
    }
  }
}
