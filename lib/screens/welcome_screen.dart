import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'student_auth_screen.dart';
import 'canteen_auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(LucideIcons.utensilsCrossed, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              const Text(
                "SmartQueue",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 16),
              const Text(
                "Order food, skip lines, and manage queues effortlessly.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const Spacer(),
              const Text("I am a:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              
              // Role Selection Cards
              _buildRoleCard(
                context, 
                title: "Student", 
                subtitle: "Order food & skip the queue", 
                icon: LucideIcons.graduationCap, 
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAuthScreen()))
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context, 
                title: "Canteen Partner", 
                subtitle: "Manage menu, orders & staff", 
                icon: LucideIcons.store, 
                color: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CanteenAuthScreen()))
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
