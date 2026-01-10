import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';
import '../models/canteen.dart';
import '../models/menu_item.dart';

// --- Extracted Menu Management Widget ---
class MenuManagementTab extends StatefulWidget {
  final Canteen canteen;
  const MenuManagementTab({super.key, required this.canteen});

  @override
  State<MenuManagementTab> createState() => _MenuManagementTabState();
}

class _MenuManagementTabState extends State<MenuManagementTab> with AutomaticKeepAliveClientMixin {
  late Stream<List<MenuItem>> _menuStream;

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    // Initialize stream ONCE
    final state = Provider.of<AppState>(context, listen: false);
    _menuStream = state.backendService.getMenuStream(widget.canteen.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final state = Provider.of<AppState>(context); // Listen for updates if needed (e.g. adding item)

    return StreamBuilder<List<MenuItem>>(
      stream: _menuStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        
        final items = snapshot.data!;
        
        return Scaffold(
          floatingActionButton: FloatingActionButton(
             onPressed: () => _showAddMenuItemDialog(context, state),
             child: const Icon(LucideIcons.plus),
          ),
          body: items.isEmpty 
              ? const Center(child: Text("Menu is empty. Add items!"))
              : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Icon(_getIconData(item.icon), color: Colors.blue),
                  ),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("₹${item.price} • ${item.category}"),
                  trailing: Switch(
                     value: item.isAvailable,
                     onChanged: (val) {
                       final updated = item.copyWith(isAvailable: val);
                       state.backendService.updateMenuItem(widget.canteen.id, updated);
                     },
                  ),
                  onLongPress: () {
                     // Delete option
                     showDialog(context: context, builder: (c) => AlertDialog(
                       title: const Text("Delete Item?"),
                       actions: [
                         TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
                         TextButton(onPressed: () {
                           state.backendService.deleteMenuItem(widget.canteen.id, item.id);
                           Navigator.pop(c);
                         }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
                       ],
                     ));
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showAddMenuItemDialog(BuildContext context, AppState state) {
     final nameCtrl = TextEditingController();
     final priceCtrl = TextEditingController();
     final catCtrl = TextEditingController(text: "Snacks");
     
     showDialog(
       context: context, 
       builder: (context) => AlertDialog(
         title: const Text("Add Menu Item"),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Dish Name")),
             TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Price"), keyboardType: TextInputType.number),
             TextField(controller: catCtrl, decoration: const InputDecoration(labelText: "Category (Snacks, Drinks, Meal)")),
           ],
         ),
         actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                 if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;

                 final newItem = MenuItem(
                   id: DateTime.now().millisecondsSinceEpoch.toString(),
                   name: nameCtrl.text,
                   price: double.tryParse(priceCtrl.text) ?? 50,
                   category: catCtrl.text,
                   isAvailable: true,
                   icon: 'utensils',
                   color: 'blue-100'
                 );
                 
                 await state.backendService.addMenuItem(widget.canteen.id, newItem);
                 if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Add"),
            )
         ],
       )
     );
  }
  
  IconData _getIconData(String name) {
    switch (name) {
      case 'pizza': return LucideIcons.pizza;
      case 'coffee': return LucideIcons.coffee;
      case 'sandwich': return LucideIcons.sandwich;
      default: return LucideIcons.utensils;
    }
  }
}
