import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';
import '../models/canteen.dart';
import '../models/menu_item.dart';

class AdminPosTab extends StatefulWidget {
  final Canteen canteen;
  const AdminPosTab({super.key, required this.canteen});

  @override
  State<AdminPosTab> createState() => _AdminPosTabState();
}

class _AdminPosTabState extends State<AdminPosTab> {
  final Map<String, int> _localCart = {}; // ItemId -> Qty

  void _addToCart(String itemId) {
    setState(() {
      _localCart[itemId] = (_localCart[itemId] ?? 0) + 1;
    });
  }

  void _removeFromCart(String itemId) {
    setState(() {
      if (_localCart.containsKey(itemId)) {
        if (_localCart[itemId]! > 1) {
          _localCart[itemId] = _localCart[itemId]! - 1;
        } else {
          _localCart.remove(itemId);
        }
      }
    });
  }

  double _calculateTotal(List<MenuItem> menu) {
    double total = 0;
    _localCart.forEach((id, qty) {
      final item = menu.firstWhere((i) => i.id == id, orElse: () => MenuItem(id: 'err', name: 'Unknown', icon: 'x', color: 'gray', price: 0));
      total += item.price * qty;
    });
    return total;
  }

  Future<void> _processOfflineOrder(AppState state, List<MenuItem> menu) async {
    if (_localCart.isEmpty) return;
    
    // Construct Items List
    final List<Map<String, dynamic>> items = [];
    _localCart.forEach((id, qty) {
       final item = menu.firstWhere((i) => i.id == id);
       items.add({
         "id": item.id,
         "name": item.name,
         "price": item.price,
         "quantity": qty
       });
    });

    try {
      await state.backendService.createToken(
        widget.canteen.id, 
        state.currentUser?['uid'] ?? 'admin_pos', 
        items,
        isOffline: true
      );
      
      if (mounted) {
        setState(() { _localCart.clear(); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Offline Order Placed! Check Live Queue.")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return StreamBuilder<List<MenuItem>>(
          stream: state.backendService.getMenuStream(widget.canteen.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final menu = snapshot.data!;
            final total = _calculateTotal(menu);
            final cartCount = _localCart.values.fold(0, (sum, val) => sum + val);

            return LayoutBuilder(
              builder: (context, constraints) {
                bool isMobile = constraints.maxWidth < 600;

                if (isMobile) {
                  return Column(
                    children: [
                      // Full Width Grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Bottom padding for floating bar
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, // 2 cols for mobile
                            childAspectRatio: 0.75, // Better aspect ratio
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12
                          ),
                          itemCount: menu.length,
                          itemBuilder: (context, index) {
                            final item = menu[index];
                            final qty = _localCart[item.id] ?? 0;
                            return _buildPosCard(item, qty);
                          },
                        ),
                      ),
                      
                      // Bottom Cart Summary Bar
                      if (_localCart.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))]
                          ),
                          child: SafeArea(
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("$cartCount Items", style: const TextStyle(color: Colors.grey)),
                                    Text("₹$total", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  icon: const Icon(LucideIcons.shoppingBag),
                                  label: const Text("View Cart"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                                  ),
                                  onPressed: () => _showCartSheet(context, menu, state),
                                )
                              ],
                            ),
                          ),
                        )
                    ],
                  );
                } else {
                  // Desktop/Tablet Layout (Split View - Fixed)
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.8, 
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16
                          ),
                          itemCount: menu.length,
                          itemBuilder: (context, index) {
                            final item = menu[index];
                            final qty = _localCart[item.id] ?? 0;
                            return _buildPosCard(item, qty);
                          },
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildCartPanel(context, menu, total, state),
                      )
                    ],
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  // Extracted Cart Panel for Desktop & BottomSheet
  Widget _buildCartPanel(BuildContext context, List<MenuItem> menu, double total, AppState state) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Current Order (Cash)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: _localCart.isEmpty 
              ? const Center(child: Text("Cart is Empty", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _localCart.length,
                  itemBuilder: (context, index) {
                    final itemId = _localCart.keys.elementAt(index);
                    final qty = _localCart[itemId]!;
                    final item = menu.firstWhere((i) => i.id == itemId);
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                 Text("₹${item.price} x $qty", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                               ],
                             ),
                           ),
                           IconButton(
                             icon: const Icon(LucideIcons.minusCircle, size: 20), 
                             visualDensity: VisualDensity.compact,
                             onPressed: () => _removeFromCart(itemId)
                           ),
                           Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold)),
                           IconButton(
                             icon: const Icon(LucideIcons.plusCircle, size: 20), 
                             visualDensity: VisualDensity.compact,
                             onPressed: () => _addToCart(itemId)
                           ),
                        ],
                      ),
                    );
                  },
                ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text("₹$total", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(LucideIcons.banknote),
            label: const Text("Place Offline Order"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16)
            ),
            onPressed: _localCart.isEmpty ? null : () {
              if (Navigator.canPop(context)) Navigator.pop(context); // Close sheet if open
              _processOfflineOrder(state, menu);
            },
          )
        ],
      ),
    );
  }

  void _showCartSheet(BuildContext context, List<MenuItem> menu, AppState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true, // Allow full height
      builder: (context) {
        final total = _calculateTotal(menu);
        return SizedBox(
           height: MediaQuery.of(context).size.height * 0.7,
           child: _buildCartPanel(context, menu, total, state)
        );
      }
    );
  }

  // Helper to parse color strings (from student portal)
  Color _getColor(String colorClass) {
    if (colorClass.contains('orange')) return Colors.orange.shade100;
    if (colorClass.contains('yellow')) return Colors.yellow.shade100;
    if (colorClass.contains('amber')) return Colors.amber.shade100;
    if (colorClass.contains('red')) return Colors.red.shade100;
    if (colorClass.contains('green')) return Colors.green.shade100;
    if (colorClass.contains('stone')) return Colors.grey.shade300;
    return Colors.blue.shade100;
  }

  Color _getTextColor(String colorClass) {
     if (colorClass.contains('orange')) return Colors.orange.shade900;
     if (colorClass.contains('yellow')) return Colors.yellow.shade900;
     if (colorClass.contains('amber')) return Colors.amber.shade900;
     if (colorClass.contains('red')) return Colors.red.shade900;
     if (colorClass.contains('green')) return Colors.green.shade900;
     if (colorClass.contains('stone')) return Colors.grey.shade800;
     return Colors.blue.shade900;
  }
  
  // Helper to map string icon names to IconData
  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'pizza': return LucideIcons.pizza;
      case 'utensils': return LucideIcons.utensils;
      case 'sandwich': return LucideIcons.sandwich;
      case 'coffee': return LucideIcons.coffee;
      default: return LucideIcons.utensils;
    }
  }

  Widget _buildPosCard(MenuItem item, int qty) {
    // If sold out, force grey colors
    final bool isAvailable = item.isAvailable;
    final bgColor = isAvailable ? _getColor(item.color) : Colors.grey.shade100;
    final textColor = isAvailable ? _getTextColor(item.color) : Colors.grey.shade400;

    return GestureDetector(
      // Disable tap if sold out
      onTap: isAvailable ? () => _addToCart(item.id) : null,
      child: Container(
        decoration: BoxDecoration(
          color: qty > 0 ? bgColor : (isAvailable ? Colors.white : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
             color: qty > 0 ? textColor : Colors.grey.shade200, 
             width: qty > 0 ? 2 : 1
          ),
          boxShadow: [
             if (qty > 0)
                BoxShadow(color: bgColor.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))
             else if (isAvailable)
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                       color: qty > 0 ? Colors.white.withOpacity(0.5) : bgColor, 
                       shape: BoxShape.circle
                    ),
                    child: Icon(_getIcon(item.icon), color: textColor, size: 24)
                 ),
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 4.0),
                   child: Text(
                     item.name, 
                     textAlign: TextAlign.center, 
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                     style: TextStyle(
                       fontWeight: FontWeight.bold, 
                       fontSize: 15, 
                       color: qty > 0 ? textColor : (isAvailable ? Colors.grey.shade800 : Colors.grey.shade400),
                       decoration: isAvailable ? null : TextDecoration.lineThrough
                     )
                   ),
                 ),
                 const SizedBox(height: 4),
                 Text(
                   isAvailable ? "₹${item.price}" : "Sold Out", 
                   textAlign: TextAlign.center, 
                   style: TextStyle(
                     color: qty > 0 ? textColor.withOpacity(0.8) : (isAvailable ? Colors.grey.shade600 : Colors.red.shade300), 
                     fontSize: 13,
                     fontWeight: isAvailable ? FontWeight.normal : FontWeight.bold
                   )
                 ),
              ],
            ),
            if (qty > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: textColor, borderRadius: BorderRadius.circular(12)),
                  child: Text("$qty", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              
            if (!isAvailable)
               Positioned(
                 top: 8,
                 right: 8,
                 child: Icon(LucideIcons.ban, color: Colors.grey.shade300, size: 20),
               )
          ],
        ),
      ),
    );
  }
}
