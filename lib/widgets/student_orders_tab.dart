import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';
import '../models/token.dart';
import '../widgets/student_token_card.dart';

class StudentOrdersTab extends StatefulWidget {
  const StudentOrdersTab({super.key});

  @override
  State<StudentOrdersTab> createState() => _StudentOrdersTabState();
}

class _StudentOrdersTabState extends State<StudentOrdersTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.currentUser == null) return const Center(child: Text("Please Login"));

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
               Container(
                height: 55, // Explicit larger height
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24), // More spacing
                padding: const EdgeInsets.all(4), // Padding for the indicator to float inside
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: "Active Orders"),
                    Tab(text: "History"),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Token>>(
                  stream: state.backendService.getStudentHistoryStream(state.currentUser!['uid']),
                  builder: (context, snapshot) {
                     if (snapshot.connectionState == ConnectionState.waiting) {
                       return const Center(child: CircularProgressIndicator());
                     }
                     
                     // If error, show but don't hang
                     if (snapshot.hasError) {
                       return Center(child: Text("Error: ${snapshot.error}"));
                     }

                     final allTokens = snapshot.data ?? [];
                     
                     // Partition
                     final activeTokens = allTokens.where((t) => t.status != OrderStatus.COMPLETED && t.status != OrderStatus.CANCELLED).toList();
                     final historyTokens = allTokens.where((t) => t.status == OrderStatus.COMPLETED || t.status == OrderStatus.CANCELLED).toList();
                     
                     return TabBarView(
                       children: [
                         _buildActiveList(state, activeTokens),
                         _buildHistoryList(historyTokens),
                       ],
                     );
                  }
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveList(AppState state, List<Token> tokens) {
    if (tokens.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.chefHat, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("No active orders", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tokens.length,
      itemBuilder: (context, index) {
         final staticToken = tokens[index];
         // Listen for status updates
         return StreamBuilder<Token?>(
           stream: state.backendService.getTokenStream(staticToken.id),
           initialData: staticToken,
           builder: (context, tokenSnap) {
             final token = tokenSnap.data ?? staticToken;
             
             return StreamBuilder<int>(
               stream: state.backendService.getQueuePositionStream(token.canteenId, token.id),
               initialData: 0,
               builder: (context, queueSnap) {
                 return StudentTokenCard(
                   token: token, 
                   queuePosition: queueSnap.data,
                   isHistory: false,
                 );
               }
             );
           },
         );
      },
    );
  }

  Widget _buildHistoryList(List<Token> tokens) {
     if (tokens.isEmpty) return const Center(child: Text("No past orders"));
     
     return ListView.builder(
       padding: const EdgeInsets.all(16),
       itemCount: tokens.length,
       itemBuilder: (context, index) {
         return StudentTokenCard(token: tokens[index], isHistory: true);
       },
     );
  }
}
