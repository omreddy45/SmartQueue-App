import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';
import '../models/canteen.dart';
import '../models/token.dart';

class ActiveOrdersList extends StatelessWidget {
  final Canteen canteen;
  
  const ActiveOrdersList({super.key, required this.canteen});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return StreamBuilder<List<Token>>(
          stream: state.backendService.getActiveQueueStream(canteen.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final tokens = snapshot.data ?? [];
            if (tokens.isEmpty) return _buildEmptyState("No active orders");

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tokens.length,
              itemBuilder: (context, index) {
                final token = tokens[index];
                return _buildOrderCard(token, state);
              },
            );
          },
        );
      }
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.coffee, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Token token, AppState state) {
    final isReady = token.status == OrderStatus.READY;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
             Row(
              children: [
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     decoration: BoxDecoration(
                       color: token.isOffline ? Colors.amber.shade100 : (isReady ? Colors.green.shade50 : Colors.blue.shade50),
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: token.isOffline ? Colors.amber.shade700 : (isReady ? Colors.green.shade100 : Colors.blue.shade100), width: token.isOffline ? 2 : 1)
                     ),
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(
                           token.tokenNumber,
                           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: token.isOffline ? Colors.amber.shade900 : (isReady ? Colors.green.shade700 : Colors.blue.shade700)),
                         ),
                         if (token.isOffline) 
                           Padding(
                             padding: const EdgeInsets.only(left: 8.0),
                             child: Icon(LucideIcons.megaphone, size: 20, color: Colors.amber.shade900),
                           )
                       ],
                     ),
                   ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(token.foodItem, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                       Text(isReady ? "Ready for pickup" : "Waiting for prep", style: TextStyle(color: isReady ? Colors.green : Colors.grey))
                     ],
                   ),
                 ),
                 if (!isReady)
                   IconButton(onPressed: () => state.backendService.markOrderReady(token.id), icon: const Icon(LucideIcons.bellRing, color: Colors.orange), style: IconButton.styleFrom(backgroundColor: Colors.orange.shade50),)
                 else
                   IconButton(onPressed: () => state.backendService.completeOrder(token.id), icon: const Icon(LucideIcons.check, color: Colors.green), style: IconButton.styleFrom(backgroundColor: Colors.green.shade50),)
              ],
             ),
             if (token.items != null) ...[
                 const Divider(),
                 ...token.items!.map((i) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(i['name']), Text("x${i['quantity']}")],
                 ))
             ]
          ],
        ),
      ),
    );
  }
}
