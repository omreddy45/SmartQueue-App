import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/menu_item.dart';
import '../widgets/menu_item_card.dart';

class StudentMenuTab extends StatefulWidget {
  const StudentMenuTab({super.key});

  @override
  State<StudentMenuTab> createState() => _StudentMenuTabState();
}

class _StudentMenuTabState extends State<StudentMenuTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for KeepAlive
    
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.selectedCanteen == null) return const Center(child: Text("No Canteen Selected"));

        return StreamBuilder<List<dynamic>>(
          stream: state.backendService.getMenuStream(state.selectedCanteen!.id),
          builder: (context, snapshot) {
             if (snapshot.connectionState == ConnectionState.waiting) {
               return const Center(child: CircularProgressIndicator());
             }
             if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
               return const Center(child: Text("Menu is empty"));
             }
             
             final List<MenuItem> allItems = snapshot.data as List<MenuItem>;
             final List<MenuItem> items = allItems.where((i) => i.isAvailable).toList();
             
             return GridView.builder(
               padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                 crossAxisCount: 2,
                 childAspectRatio: 0.85,
                 crossAxisSpacing: 16,
                 mainAxisSpacing: 16,
               ),
               itemCount: items.length,
               itemBuilder: (context, index) {
                  final item = items[index];
                  final qty = state.getItemQuantity(item.id);
                  return MenuItemCard(
                    item: item,
                    isSelected: qty > 0,
                    onTap: () => state.toggleItem(item),
                  );
               },
             );
          },
        );
      },
    );
  }
}
