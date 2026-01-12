import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/canteen.dart';
import '../models/queue_stats.dart';
import '../providers/app_state.dart';
import '../services/backend_service.dart';

class AdminDashboardTab extends StatefulWidget {
  final Canteen canteen;
  const AdminDashboardTab({super.key, required this.canteen});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> with AutomaticKeepAliveClientMixin {
  String? _aiInsight;
  bool _aiLoading = false;

  @override
  bool get wantKeepAlive => true; // Keeps state alive

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for mixin
    final canteenId = widget.canteen.id;
    final backend = Provider.of<AppState>(context, listen: false).backendService;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Real-time Stats Stream
        StreamBuilder<QueueStats>(
          stream: backend.getStatsStream(canteenId),
          builder: (context, snapshot) {
            final stats = snapshot.data ?? QueueStats(totalOrdersToday: 0, averageWaitTime: 0, peakHour: 'N/A', activeQueueLength: 0, topItems: {});
            
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
                 final Map<String, int> trafficData = snapshot.data ?? {};
                 
                 // Standard Business Hours (Defaults)
                 final Set<String> allKeys = {
                   "9 AM", "10 AM", "11 AM", "12 PM", 
                   "1 PM", "2 PM", "3 PM", "4 PM", 
                   "5 PM", "6 PM"
                 };
                 // Merge with actual data (e.g. if open late until 8 PM)
                 allKeys.addAll(trafficData.keys);
                 
                 final sortedKeys = allKeys.toList()..sort((a, b) => _parseTime(a).compareTo(_parseTime(b)));

                 int maxOrders = 1;
                 trafficData.forEach((_, v) { if(v > maxOrders) maxOrders = v; });

                 return ListView(
                   scrollDirection: Axis.horizontal,
                   children: sortedKeys.map((key) {
                      final value = trafficData[key] ?? 0;
                      final heightPct = maxOrders > 0 ? value / maxOrders : 0.0;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text("$value", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                            const SizedBox(height: 8),
                            Container(
                              width: 30, 
                              height: (120 * heightPct).clamp(10, 120).toDouble(), 
                              decoration: BoxDecoration(
                                color: value > 0 ? Colors.blue : Colors.grey.shade200,
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
             boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))], 
          ),
          child: Column(
             children: [
               const Text("Canteen QR Code", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               const Text("Students can scan this to order from your canteen.", style: TextStyle(color: Colors.grey)),
               const SizedBox(height: 24),
               QrImageView(
                 data: "smartqueue://?canteenId=${canteenId}",
                 version: QrVersions.auto,
                 size: 200.0,
               ),
               const SizedBox(height: 16),
               SelectableText(
                  "Canteen ID: $canteenId",
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
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 4))],
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
                   Text("Queue Analysis (Gemini 2.5)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                   const Text("AI-driven staffing & product insights", style: TextStyle(fontSize: 11, color: Colors.indigo)),
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
      // Fetch actual traffic data for accurate analysis
      final traffic = await backend.getHourlyTraffic(widget.canteen.id);
      final res = await backend.getDashboardInsights(stats, traffic); 
      if (mounted) setState(() { _aiLoading = false; _aiInsight = res; });
  }

  // Helper to parse "9 AM", "1 PM" etc for sorting
  int _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      int h = int.parse(parts[0]);
      final ampm = parts[1];
      if (ampm == "PM" && h != 12) h += 12;
      if (ampm == "AM" && h == 12) h = 0;
      return h;
    } catch (e) {
      return 0; // Fallback
    }
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)), 
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
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
