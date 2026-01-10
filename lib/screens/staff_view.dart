import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/canteen.dart';
import '../models/token.dart';

import '../widgets/active_orders_list.dart';

class StaffView extends StatelessWidget {
  const StaffView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final canteen = state.selectedCanteen;
        if (canteen == null) return const Center(child: Text("No Canteen Selected"));

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text("Order Management", style: TextStyle(fontSize: 16)),
                   Text(canteen.name, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(LucideIcons.chefHat), text: "Kitchen"),
                  Tab(icon: Icon(LucideIcons.history), text: "Canteen History"),
                ],
              ),
              actions: [
                 IconButton(
                   icon: const Icon(Icons.logout), 
                   onPressed: state.logout 
                 )
              ],
            ),
            body: TabBarView(
              children: [
                ActiveOrdersList(canteen: canteen),
                _buildCanteenTab(state, canteen),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCanteenTab(AppState state, Canteen canteen) {
      return StreamBuilder<List<Token>>(
         stream: state.backendService.getCanteenHistoryStream(canteen.id),
         builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            final tokens = snapshot.data ?? [];
            if (tokens.isEmpty) return const Center(child: Text("No completed orders yet today."));
            
            return ListView.builder(
               padding: const EdgeInsets.all(16),
               itemCount: tokens.length,
               itemBuilder: (context, index) {
                   final t = tokens[index];
                   return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                         leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            child: const Icon(LucideIcons.check, color: Colors.green, size: 16),
                         ),
                         title: Text(t.tokenNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                         subtitle: Text("${t.foodItem}\nCompleted at ${DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(t.completedAt ?? t.timestamp))}"),
                         isThreeLine: true,
                         trailing: Text(t.id.substring(t.id.length-4), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                   );
               },
            );
         }
      );
  }
}

