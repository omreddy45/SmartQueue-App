import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/token.dart';
import '../providers/app_state.dart';

class StudentTokenCard extends StatefulWidget {
  final Token token;
  final int? queuePosition;
  final bool isHistory;

  const StudentTokenCard({
    super.key,
    required this.token,
    this.queuePosition,
    this.isHistory = false,
  });

  @override
  State<StudentTokenCard> createState() => _StudentTokenCardState();
}

class _StudentTokenCardState extends State<StudentTokenCard> {
  String? _aiInsight;

  @override
  void initState() {
    super.initState();
    // Only fetch if active and recent
    if (!widget.isHistory && 
        widget.token.status != OrderStatus.COMPLETED && 
        widget.token.status != OrderStatus.CANCELLED) {
       _fetchInsight();
    }
  }
  
  void _fetchInsight() async {
     // Small delay to ensure build context
     await Future.delayed(Duration.zero);
     if (!mounted) return;
     
     final backend = Provider.of<AppState>(context, listen: false).backendService;
     final insight = await backend.getStudentTokenInsight(
       widget.token.status.toString().split('.').last, 
       widget.queuePosition ?? 0, 
       widget.token.estimatedWaitTimeMinutes
     );
     
     if (mounted) setState(() { _aiInsight = insight; });
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    final isReady = token.status == OrderStatus.READY;
    final isCompleted = token.status == OrderStatus.COMPLETED;
    final isCancelled = token.status == OrderStatus.CANCELLED;

    // Design Colors from Reference
    final Color headerColor = const Color(0xFF4F46E5); // Indigo/Purple
    final Color readyColor = const Color(0xFF22C55E); // Green for ready override

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          // --- Header Section ---
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                decoration: BoxDecoration(
                  color: isReady ? readyColor : headerColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Text(
                      isReady ? "ORDER READY" : "VIT", 
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: isReady ? 1.0 : 0.7), 
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 2.0,
                        fontSize: isReady ? 14 : 10
                      )
                    ),
                    const SizedBox(height: 8),
                    Text(
                      token.tokenNumber,
                      style: const TextStyle(
                        fontSize: 64, 
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -1.0
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2), 
                        borderRadius: BorderRadius.circular(30)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.utensils, color: Colors.white, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            token.foodItem.length > 20 ? '${token.foodItem.substring(0, 18)}...' : token.foodItem,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badges (Completed/Cancelled only now, Ready is handled by main header text/color)
              if (isCompleted)
                 Positioned(top: 16, right: 16, child: _buildStatusBadge("COMPLETED", Colors.white, Colors.black)),
              if (isCancelled)
                 Positioned(top: 16, right: 16, child: _buildStatusBadge("CANCELLED", Colors.white, Colors.red)),
            ],
          ),

          // --- Body Section ---
          if (!widget.isHistory && !isCompleted && !isCancelled && !isReady) ...[
             Padding(
               padding: const EdgeInsets.all(24),
               child: Column(
                 children: [
                   // Stats Row
                   Row(
                     children: [
                       Expanded(child: _buildStatBox("POSITION", "${widget.queuePosition ?? '-'}", LucideIcons.users)),
                       const SizedBox(width: 16),
                       Expanded(
                         child: _buildStatBox("EST. WAIT", "${token.estimatedWaitTimeMinutes}", LucideIcons.clock, unit: "m")
                       ),
                     ],
                   ),
                   const SizedBox(height: 24),
                   
                   // AI Insight Box
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: const Color(0xFFEEF2FF), // Light indigo
                       borderRadius: BorderRadius.circular(16),
                     ),
                     child: Row(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Icon(LucideIcons.sparkles, size: 18, color: headerColor), // Use header color for icon
                         const SizedBox(width: 12),
                         Expanded(
                           child: Text(
                             _aiInsight != null 
                             ? '"$_aiInsight"'
                             : '"Calculating best estimate based on current kitchen load..."',
                             style: const TextStyle(
                               fontSize: 13, 
                               color: Color(0xFF3730A3), // Darker indigo text
                               height: 1.5
                             ),
                           ),
                         ),
                       ],
                     ),
                   ),
                 ],
               ),
             )
          ] else if (isReady) ...[
             const Padding(
               padding: EdgeInsets.all(32),
               child: Text("Please collect your food from the counter.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
             )
          ]
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color bg, Color textCol) {
     return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 10)),
     );
  }

  Widget _buildStatBox(String label, String value, IconData icon, {String? unit}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF4F46E5), size: 20),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
              if (unit != null)
                 Text(unit, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}
