import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';
import '../widgets/student_menu_tab.dart';
import '../widgets/student_orders_tab.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../secrets.dart';
import 'package:image_picker/image_picker.dart';

class StudentView extends StatefulWidget {
  const StudentView({super.key});

  @override
  State<StudentView> createState() => _StudentViewState();
}

class _StudentViewState extends State<StudentView> with SingleTickerProviderStateMixin {
  // Steps: 0 = Scan, 1 = Menu/Cart, 2 = Active Token
  int _step = 0;
  
  // Scanner controller
  MobileScannerController controller = MobileScannerController();
  bool _isScanning = true;

  late Razorpay _razorpay;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    
    final state = Provider.of<AppState>(context, listen: false);
    // If Backend/AppState remembers selection, skip scan
    if (state.selectedCanteen != null) {
      _step = 1;
      _isScanning = false;
    }
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear();
    _tabController.dispose();
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

        return Scaffold(
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
                     controller: _tabController,
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
            body: TabBarView(
              controller: _tabController,
              children: const [
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
          );
      },
    );
  }

  // _buildQRScanner and _showCartSheet unchanged... (omitted from replacement for brevity, but tool needs exact target match so might need careful splicing if targeting whole file)
  // Wait, I am using StartLine/EndLine, so I'll target the top of the class down to before _buildQRScanner.

  // Actually, I can target specific chunks to be safer.



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
                     
                     // Gallery Scan Button
                     ElevatedButton.icon(
                       onPressed: _scanFromGallery,
                       icon: const Icon(LucideIcons.image),
                       label: const Text("Scan from Gallery"),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.blue.shade50,
                         foregroundColor: Colors.blue.shade700,
                         elevation: 0,
                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                       ),
                     ),
                     
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

  Future<void> _scanFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analyzing image...")));
    }

    final success = await controller.analyzeImage(image.path);
    if (!success) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No QR code found in image!")));
      }
    }
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
                 onPressed: state.cart.isEmpty ? null : () {
                    final total = state.cart.values.fold(0.0, (sum, item) => sum + (item.item.price * item.quantity));
                    Navigator.pop(sheetContext); 
                    _openCheckout(total, state);
                 },
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                 child: Builder(
                   builder: (context) {
                      final total = state.cart.values.fold(0.0, (sum, item) => sum + (item.item.price * item.quantity));
                      return Text("Pay ₹${total.toStringAsFixed(2)}");
                   }
                 ),
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
          _tabController.animateTo(1);
          setState(() {}); 
       }
     } catch (e) {
       print("Order Placement Error: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to place order: $e")));
       }
     }
  }

  void _openCheckout(double amount, AppState state) {
    debugPrint("Razorpay Key: ${Secrets.razorpayKeyId} (Length: ${Secrets.razorpayKeyId.length})");
    var options = {
      'key': Secrets.razorpayKeyId.trim(), // Ensure no whitespace
      'amount': (amount * 100).toInt(), // in paisa
      'name': state.selectedCanteen?.name ?? 'SmartQueue',
      'description': 'Order Payment',
      'prefill': {
        'contact': '9876543210', 
        'email': state.currentUser?['email'] ?? 'student@example.com'
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    final state = Provider.of<AppState>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text("Payment Successful! Ref: ${response.paymentId}")),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      )
    );
    _placeOrder(context, state);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.xCircle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text("Payment Failed: ${response.code} - ${response.message}")),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      )
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("External Wallet Selected: ${response.walletName}"))
       );
    }
  }

}
