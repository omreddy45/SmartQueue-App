import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';
import '../models/canteen.dart';

import '../widgets/active_orders_list.dart';
import '../widgets/menu_management_tab.dart';

import '../widgets/admin_dashboard_tab.dart';
import '../widgets/admin_pos_tab.dart';

class AdminView extends StatefulWidget {
  final Canteen? canteen; // Optional direct pass
  const AdminView({super.key, this.canteen});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  Canteen? _currentCanteen;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AppState>(context, listen: false);
    if (widget.canteen != null) {
      _currentCanteen = widget.canteen;
    } else if (state.selectedCanteen != null) {
      _currentCanteen = state.selectedCanteen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        // Ensure we have a canteen. If not, redirect or show error.
        // In this flow, AdminView is only reached after login/reg which sets selectedCanteen.
        if (_currentCanteen == null && state.selectedCanteen != null) {
           _currentCanteen = state.selectedCanteen;
        }

        if (_currentCanteen == null) {
          return const Scaffold(body: Center(child: Text("No Canteen Selected. Please Login.")));
        }

        return DefaultTabController(
          length: 5, 
          child: Scaffold(
            appBar: AppBar(
              title: const Text("Admin Portal"),
              bottom: const TabBar(
                isScrollable: false, // Fill width
                labelPadding: EdgeInsets.zero, // Compact
                tabs: [
                  Tab(icon: Icon(LucideIcons.layoutDashboard, size: 20), text: "Dash"),
                  Tab(icon: Icon(LucideIcons.chefHat, size: 20), text: "Queue"), 
                  Tab(icon: Icon(LucideIcons.utensils, size: 20), text: "Menu"),
                  Tab(icon: Icon(LucideIcons.banknote, size: 20), text: "POS"),
                  Tab(icon: Icon(LucideIcons.users, size: 20), text: "Staff"),
                ],
              ),
              leading: IconButton(
                icon: const Icon(LucideIcons.logOut),
                onPressed: () => state.logout(),
              ),
            ),
            body: TabBarView(
              children: [
                AdminDashboardTab(canteen: _currentCanteen!),
                ActiveOrdersList(canteen: _currentCanteen!),
                MenuManagementTab(canteen: _currentCanteen!),
                AdminPosTab(canteen: _currentCanteen!),
                _buildStaffManagement(state),
              ],
            ),
          ),
        );
      },
    );
  }


  // --- Staff Management Tab ---
  Widget _buildStaffManagement(AppState state) {
     final emailCtrl = TextEditingController();
     final passCtrl = TextEditingController();
     
     return Padding(
       padding: const EdgeInsets.all(24),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: [
           const Text("Create Kitchen Staff Account", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
           const SizedBox(height: 8),
           const Text("Staff can login to the Kitchen View to manage orders.", style: TextStyle(color: Colors.grey)),
           const SizedBox(height: 24),
           
           TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Staff Email", border: OutlineInputBorder(), prefixIcon: Icon(LucideIcons.mail))),
           const SizedBox(height: 16),
           TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(LucideIcons.lock))),
           const SizedBox(height: 24),
           
           ElevatedButton.icon(
             icon: const Icon(LucideIcons.userPlus),
             label: const Text("Create Staff Account"),
             style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.black, foregroundColor: Colors.white),
             onPressed: () async {
                if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                
                final res = await state.backendService.createStaffAccount(_currentCanteen!.id, emailCtrl.text, passCtrl.text);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res == "Success" ? "Staff Account Created!" : "Error: $res")));
                  if (res == "Success") {
                    emailCtrl.clear();
                    passCtrl.clear();
                  }
                }
             },
           )
         ],
       ),
     );
  }
}
