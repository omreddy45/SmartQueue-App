import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';

class CanteenAuthScreen extends StatefulWidget {
  const CanteenAuthScreen({super.key});

  @override
  State<CanteenAuthScreen> createState() => _CanteenAuthScreenState();
}

class _CanteenAuthScreenState extends State<CanteenAuthScreen> {
  // 0: Login (Admin/Staff), 1: Register New Canteen
  int _mode = 0;
  
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _canteenNameCtrl = TextEditingController();
  final _campusCtrl = TextEditingController();
  
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               Icon(LucideIcons.store, size: 64, color: Colors.orange.shade300),
               const SizedBox(height: 24),
               Text(
                 _mode == 0 ? "Partner Login" : "Register Canteen",
                 style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                 textAlign: TextAlign.center,
               ),
               if (_mode == 0) const Text("For Admins and Kitchen Staff", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
               
               const SizedBox(height: 32),
               
               if (_mode == 1) ...[
                 TextField(
                   controller: _canteenNameCtrl,
                   decoration: const InputDecoration(labelText: "Canteen Name", prefixIcon: Icon(LucideIcons.home), border: OutlineInputBorder()),
                 ),
                 const SizedBox(height: 16),
                 TextField(
                   controller: _campusCtrl,
                   decoration: const InputDecoration(labelText: "Campus / Location", prefixIcon: Icon(LucideIcons.mapPin), border: OutlineInputBorder()),
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
                   backgroundColor: Colors.orange,
                   foregroundColor: Colors.white,
                 ),
                 child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(_mode == 0 ? "Login" : "Register Canteen", style: const TextStyle(fontSize: 18)),
               ),
               
               const SizedBox(height: 16),
               TextButton(
                 onPressed: () => setState(() => _mode = _mode == 0 ? 1 : 0),
                 child: Text(_mode == 0 ? "Want to partner with us? Register Canteen" : "Already a partner? Login"),
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
    bool success;

    if (_mode == 0) {
      success = await state.login(_emailCtrl.text, _passCtrl.text);
    } else {
      success = await state.registerCanteen(
          _canteenNameCtrl.text, 
          _campusCtrl.text, 
          _emailCtrl.text, 
          _passCtrl.text
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        // Pop back to home which will redirect based on Auth State
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Authentication Failed")));
      }
    }
  }
}
