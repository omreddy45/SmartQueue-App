import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/user_role.dart';
import 'student_view.dart';
import 'staff_view.dart';
import 'admin_view.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        // 0. Auth Check
        // If not logged in, show Welcome Screen (Entry point)
        if (state.currentUser == null || state.currentRole == UserRole.none) {
           // We might need to differentiate between 'Logged out completely' and 'App Start'
           // AppState should ideally try to check active session on startup.
           // For now, if no user, Welcome.
           return const WelcomeScreen();
        }

        // 1. Routing based on Role
        // Student -> Student View (Scanner)
        if (state.currentRole == UserRole.student) {
             return const StudentView();
        } 
        
        // Staff -> Kitchen View (Requires Canteen)
        if (state.currentRole == UserRole.staff) {
             if (state.selectedCanteen == null) {
                return const Scaffold(body: Center(child: Text("Error: Staff account has no linked Canteen.")));
             }
             return const StaffView();
        } 
        
        // Admin -> Admin View (Requires Canteen)
        if (state.currentRole == UserRole.admin) {
             if (state.selectedCanteen == null) {
                // If admin has no canteen (rare, registration should handle it), show option to create? 
                // Creating manually via AdminView is possible if we pass null.
                return const AdminView(); 
             }
             return const AdminView();
        }

        // Fallback
        return const WelcomeScreen();
      },
    );
  }
}
