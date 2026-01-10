import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';
import '../widgets/student_menu_tab.dart';
import '../widgets/student_orders_tab.dart';

class StudentView extends StatefulWidget {
  const StudentView({super.key});

  @override
  State<StudentView> createState() => _StudentViewState();
}

class _StudentViewState extends State<StudentView> {
  // Steps: 0 = Scan, 1 = Menu/Cart, 2 = Active Token
  int _step = 0;
  
  // Scanner controller
  MobileScannerController controller = MobileScannerController();
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AppState>(context, listen: false);
    // If Backend/AppState remembers selection, skip scan
    if (state.selectedCanteen != null) {
      _step = 1;
      _isScanning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        // If we have an active token effectively, we should show it (Step 2)
        // For simplicity, we manage steps manually.

        if (_step == 0) {
          return _buildQRScanner(state);
        }

        // Guard: If no canteen selected, always show scanner
        if (state.selectedCanteen == null) {
           if (_step != 0) {
              // Reset local state if out of sync
              WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() { _step = 0; _isScanning = true; });
              });
           }
           return _buildQRScanner(state);
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(state.selectedCanteen!.name),

              bottom: PreferredSize(
                 preferredSize: const Size.fromHeight(60),
                 child: Container(
                   margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   padding: const EdgeInsets.all(4),
                   decoration: BoxDecoration(
                     color: Colors.grey.shade200,
                     borderRadius: BorderRadius.circular(30),
                   ),
                   child: TabBar(
                     indicator: BoxDecoration(
                       color: Colors.black, // Active color
                       borderRadius: BorderRadius.circular(26),
                     ),
                     labelColor: Colors.white,
                     unselectedLabelColor: Colors.grey.shade600,
                     indicatorSize: TabBarIndicatorSize.tab,
                     dividerColor: Colors.transparent, // Remove line
                     tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.utensils, size: 16),
                              SizedBox(width: 8),
                              Text("Menu", style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.ticket, size: 16),
                              SizedBox(width: 8),
                              Text("My Tokens", style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                     ],
                   ),
                 ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(LucideIcons.scanLine),
                  tooltip: "Scan New Canteen",
                  onPressed: () {
                    setState(() {
                      state.exitCanteen();
                      _step = 0;
                      _isScanning = true;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(LucideIcons.logOut),
                  onPressed: state.logout,
                )
              ],
            ),
            body: const TabBarView(
              children: [
                StudentMenuTab(),
                StudentOrdersTab(), 
              ],
            ),
            floatingActionButton: _step == 1 && state.cart.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () => _showCartSheet(context, state),
                  label: Text("Checkout (${state.cart.length})"),
                  icon: const Icon(LucideIcons.shoppingBag),
                )
              : null,
          ),
        );
      },
    );
  }

  Widget _buildQRScanner(AppState state) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Canteen QR"),
        actions: [ IconButton(icon: const Icon(LucideIcons.logOut), onPressed: state.logout) ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (!_isScanning) return;
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    final code = barcode.rawValue!;
                    // Format: smartqueue://?canteenId=xyz OR just xyz
                    String? canteenId;
                    if (code.contains("canteenId=")) {
                      canteenId = Uri.parse(code).queryParameters['canteenId'];
                    } else {
                      canteenId = code; // Assume raw ID
                    }

                    if (canteenId != null) {
                      state.selectCanteenById(canteenId).then((_) {
                         if (mounted && state.selectedCanteen != null) setState(() => _step = 1);
                      });
                    }
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     const Text("Point camera at the Canteen QR Code", style: TextStyle(fontSize: 16)),
                     const SizedBox(height: 16),
                     const Text("OR", style: TextStyle(color: Colors.grey)),
                     const SizedBox(height: 16),
                     ElevatedButton(
                       onPressed: () {
                           // Demo Mode
                           state.selectCanteenById(state.backendService.getDemoCanteenId()).then((_) {
                               if (mounted && state.selectedCanteen != null) setState(() => _step = 1);
                           });
                       }, 
                       child: const Text("Use Demo Canteen")
                     )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showCartSheet(BuildContext context, AppState state) {
     showModalBottomSheet(
       context: context,
       builder: (sheetContext) => Consumer<AppState>(
         builder: (context, state, child) => Container(
           padding: const EdgeInsets.all(24),
           height: 400, // Fixed height or wrap
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               const Text("Your Cart", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
               const SizedBox(height: 16),
               Expanded(
                 child: state.cart.isEmpty 
                   ? const Center(child: Text("Cart is empty"))
                   : ListView(
                     children: state.cart.entries.map((e) {
                        final item = e.value.item;
                        final qty = e.value.quantity;
                        return ListTile(
                           title: Text(item.name),
                           subtitle: Text("₹${item.price} each"),
                           trailing: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                                IconButton(icon: const Icon(LucideIcons.minus), onPressed: () => state.removeFromCart(e.key)),
                                Text("$qty"),
                                IconButton(icon: const Icon(LucideIcons.plus), onPressed: () => state.addToCart(item)), 
                             ],
                           ),
                        );
                     }).toList(),
                   ),
               ),
               ElevatedButton(
                 onPressed: state.cart.isEmpty ? null : () async {
                    Navigator.pop(sheetContext); // Close sheet using sheetContext
                    await _placeOrder(context, state); // Use parent context (from method arg)
                 },
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                 child: const Text("Place Order"),
               )
             ],
           ),
         ),
       )
     );
  }

  Future<void> _placeOrder(BuildContext context, AppState state) async {
     try {
       await state.backendService.createToken(
           state.selectedCanteen!.id, 
           state.currentUser!['uid'], 
           state.cart.values.map((cartItem) => {
              'id': cartItem.item.id,
              'name': cartItem.item.name,
              'quantity': cartItem.quantity,
              'price': cartItem.item.price
           }).toList()
       );
       
       state.clearCart();
       
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Order Placed Successfully!")));
          // Navigate to Tokens Tab and Force Refresh
          DefaultTabController.of(context).animateTo(1);
          setState(() {}); 
       }
     } catch (e) {
       print("Order Placement Error: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to place order: $e")));
       }
     }
  }


}


