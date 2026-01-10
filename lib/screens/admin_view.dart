import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';
import '../models/canteen.dart';
import '../models/queue_stats.dart';
import '../services/backend_service.dart';

import '../widgets/active_orders_list.dart';
import '../widgets/menu_management_tab.dart';

class AdminView extends StatefulWidget {
  final Canteen? canteen; // Optional direct pass
  const AdminView({super.key, this.canteen});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  Canteen? _currentCanteen;
  String? _aiInsight;
  bool _aiLoading = false;

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
          length: 4, 
          child: Scaffold(
            appBar: AppBar(
              title: const Text("Admin Portal"),
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(icon: Icon(LucideIcons.layoutDashboard), text: "Dashboard"),
                  Tab(icon: Icon(LucideIcons.chefHat), text: "Live Queue"), 
                  Tab(icon: Icon(LucideIcons.utensils), text: "Menu"),
                  Tab(icon: Icon(LucideIcons.users), text: "Staff"),
                ],
              ),
              leading: IconButton(
                icon: const Icon(LucideIcons.logOut),
                onPressed: () => state.logout(),
              ),
            ),
            body: TabBarView(
              children: [
                _buildDashboard(),
                ActiveOrdersList(canteen: _currentCanteen!),
                MenuManagementTab(canteen: _currentCanteen!),
                _buildStaffManagement(state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboard() {
    final canteenId = _currentCanteen!.id;
    final backend = Provider.of<AppState>(context, listen: false).backendService;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Real-time Stats Stream
        StreamBuilder<QueueStats>(
          stream: backend.getStatsStream(canteenId),
          builder: (context, snapshot) {
            final stats = snapshot.data ?? QueueStats(totalOrdersToday: 0, averageWaitTime: 0, peakHour: 'N/A', activeQueueLength: 0);
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStatCard("Total Orders", "${stats.totalOrdersToday}", LucideIcons.shoppingBag, Colors.blue),
                    _buildStatCard("Active Queue", "${stats.activeQueueLength}", LucideIcons.users, Colors.orange),
                    _buildStatCard("Avg Wait", "${stats.averageWaitTime}m", LucideIcons.clock, Colors.green),
                    _buildStatCard("Peak Hour", stats.peakHour.split(' ')[0], LucideIcons.trendingUp, Colors.purple),
                  ],
                ),
                
                const SizedBox(height: 24),

                // AI Insights Card
                _buildAIInsightCard(backend, stats),
              ],
            );
          }
        ),

        const SizedBox(height: 24),

        // Hourly Traffic Stream
        const Text("Hourly Traffic", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
           height: 200, 
           child: StreamBuilder<Map<String, int>>(
             stream: backend.getHourlyTrafficStream(canteenId),
             builder: (context, snapshot) {
                 // Initialize defaults for 9 AM to 6 PM
                 final Map<String, int> traffic = {
                   "9 AM": 0, "10 AM": 0, "11 AM": 0, "12 PM": 0, 
                   "1 PM": 0, "2 PM": 0, "3 PM": 0, "4 PM": 0, 
                   "5 PM": 0, "6 PM": 0
                 };
                 
                 if (snapshot.hasData && snapshot.data != null) {
                    // Overlay actual data if it matches our keys
                    snapshot.data!.forEach((k, v) {
                       if (traffic.containsKey(k)) {
                         traffic[k] = v;
                       }
                    });
                 }
                 
                 int maxOrders = 1;
                 traffic.forEach((_, v) { if(v > maxOrders) maxOrders = v; });

                 // Ensure fixed order by existing map keys if we iterate manually, but map order isn't guaranteed in Dart unless LinkedHashMap (default is).
                 // Safest to list keys.
                 final keys = ["9 AM", "10 AM", "11 AM", "12 PM", "1 PM", "2 PM", "3 PM", "4 PM", "5 PM", "6 PM"];

                 return ListView(
                   scrollDirection: Axis.horizontal,
                   children: keys.map((key) {
                      final value = traffic[key] ?? 0;
                      final heightPct = maxOrders > 0 ? value / maxOrders : 0.0;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text("$value", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                            const SizedBox(height: 8),
                            Container(
                              width: 30, // Slightly wider
                              height: (120 * heightPct).clamp(10, 120).toDouble(), 
                              decoration: BoxDecoration(
                                color: value > 0 ? Colors.blue : Colors.grey.shade200, // Dim empty bars
                                borderRadius: BorderRadius.circular(6)
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(key, style: const TextStyle(fontSize: 11, color: Colors.grey)), 
                          ],
                        ),
                      );
                   }).toList(),
                 );
             }
           )
        ),
        
        const SizedBox(height: 24),
        
        // QR Code Section
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
             boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))], 
          ),
          child: Column(
             children: [
               const Text("Canteen QR Code", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               const Text("Students can scan this to order from your canteen.", style: TextStyle(color: Colors.grey)),
               const SizedBox(height: 24),
               QrImageView(
                 data: "smartqueue://?canteenId=${_currentCanteen!.id}",
                 version: QrVersions.auto,
                 size: 200.0,
               ),
               const SizedBox(height: 16),
               SelectableText(
                  "Canteen ID: ${_currentCanteen!.id}",
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
               )
             ],
          ),
        ),
      ],
    );
  }

  Widget _buildAIInsightCard(BackendService backend, QueueStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.indigo.shade100),
        boxShadow: [BoxShadow(color: Colors.indigo.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                child: Icon(LucideIcons.sparkles, color: Colors.indigo.shade600, size: 20)
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text("Queue Analysis", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                   const Text("AI-driven staffing insights", style: TextStyle(fontSize: 11, color: Colors.indigo)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
             width: double.infinity,
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Colors.indigo.shade50.withOpacity(0.3),
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: Colors.indigo.shade50)
             ),
             child: _aiLoading 
               ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
               : _aiInsight == null 
                  ? Center(
                      child: TextButton.icon(
                        onPressed: () => _refreshAnalysis(backend, stats),
                        icon: const Icon(LucideIcons.play),
                        label: const Text("Generate Report"),
                      )
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         // Simple markdown-ish parser for the specific format
                         ..._aiInsight!.split('\n').map((line) {
                            if (line.trim().isEmpty) return const SizedBox(height: 4);
                            if (line.startsWith('Report Generated')) {
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 8.0),
                                 child: Text(line, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade900, fontSize: 10, letterSpacing: 1.5)),
                               );
                            }
                            if (line.startsWith('✓')) {
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 8.0),
                                 child: Text(line, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 16)),
                               );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(line, style: TextStyle(color: Colors.indigo.shade900, fontSize: 13, height: 1.4)),
                            );
                         }),
                         const SizedBox(height: 12),
                         Align(
                           alignment: Alignment.centerRight,
                           child: InkWell(
                             onTap: () => _refreshAnalysis(backend, stats),
                             child: const Text("Refresh Analysis", style: TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                           ),
                         )
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  void _refreshAnalysis(BackendService backend, QueueStats stats) async {
      setState(() { _aiLoading = true; });
      // Pass empty map as traffic isn't strictly used in updated prompt but kept for future
      final res = await backend.getDashboardInsights(stats, {}); 
      if (mounted) setState(() { _aiLoading = false; _aiInsight = res; });
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
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)), // Fixed
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))], // Fixed
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Icon(icon, color: color, size: 20),
             ],
           ),
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
             ],
           )
        ],
      ),
    );
  }
}
