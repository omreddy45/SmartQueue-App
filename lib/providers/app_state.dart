import 'package:flutter/foundation.dart';
import '../models/user_role.dart';
import '../models/canteen.dart';
import '../models/menu_item.dart';
import '../services/backend_service.dart';

class AppState extends ChangeNotifier {
  UserRole _currentRole = UserRole.none;
  Canteen? _selectedCanteen;
  final BackendService _backendService = BackendService();
  
  // Auth State
  Map<String, dynamic>? _currentUser; // {uid, email, role, name}
  Map<String, dynamic>? get currentUser => _currentUser;

  UserRole get currentRole => _currentRole;
  Canteen? get selectedCanteen => _selectedCanteen;
  BackendService get backendService => _backendService;

  Future<bool> login(String email, String password) async {
     // Reset state on new login attempt
     _selectedCanteen = null;
     _cart.clear();
     
     try {
       final user = await _backendService.login(email, password);
       if (user != null) {
         // Fetch details from DB
         final details = await _backendService.getUserDetails(user.uid);
         if (details != null) {
            _currentUser = {
              ...details,
              "uid": user.uid,
            };
            
            final roleStr = details['role'] as String;
            _currentRole = UserRole.values.firstWhere((e) => e.toString().split('.').last == roleStr, orElse: () => UserRole.student);
            
            // Only set canteen if user is Admin/Staff (typically has canteenId)
            // Explicitly skip for Students to force QR scan
            if (_currentRole != UserRole.student && details.containsKey('canteenId')) {
               final canteen = await _backendService.getCanteen(details['canteenId']);
               if (canteen != null) {
                 _selectedCanteen = canteen;
               }
            }
            
            notifyListeners();
            return true;
         }
       }
       return false;
     } catch (e) {
       print("Login Provider Error: $e");
       return false;
     }
  }

  Future<bool> signupStudent(String email, String password, String name) async {
     final user = await _backendService.signUpStudent(email, password, name);
     if (user != null) {
       _currentUser = {
         "uid": user.uid,
         "email": user.email,
         "role": "student",
         "name": name
       };
       _currentRole = UserRole.student;
       notifyListeners();
       return true;
     }
     return false;
  }

  Future<bool> registerCanteen(String canteenName, String campus, String email, String password) async {
      final user = await _backendService.registerCanteen(canteenName, campus, email, password);
      if (user != null) {
         // Re-fetch to get correct state including canteenId
         return await login(email, password);
      }
      return false;
  }

  void setRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  void selectCanteen(Canteen canteen) {
    _selectedCanteen = canteen;
    notifyListeners();
  }

  Future<void> selectCanteenById(String id) async {
    final canteen = await _backendService.getCanteen(id);
    if (canteen != null) {
      _selectedCanteen = canteen;
      notifyListeners();
    }
  }

  void exitCanteen() {
    _selectedCanteen = null;
    _currentRole = UserRole.none; // Typically keeps role but exits canteen context? User said "Student logs out".
    // If just exiting canteen (like back button), we keep Role.
    // But since this is exitCanteen mostly for student switching:
    _cart.clear(); // Clear cart for that canteen
    notifyListeners();
  }

  void logout() {
    _currentRole = UserRole.none;
    _selectedCanteen = null;
    _currentUser = null;
    _cart.clear();
    notifyListeners();
  }

  // Cart State: { menuItemId: CartItem }
  final Map<String, CartItem> _cart = {};

  Map<String, CartItem> get cart => _cart;

  void addToCart(MenuItem item) {
    if (_cart.containsKey(item.id)) {
      _cart[item.id]!.quantity++;
    } else {
      _cart[item.id] = CartItem(item: item, quantity: 1);
    }
    notifyListeners();
  }

  void toggleItem(MenuItem item) {
    if (_cart.containsKey(item.id)) {
      _cart.remove(item.id);
    } else {
      _cart[item.id] = CartItem(item: item, quantity: 1);
    }
    notifyListeners();
  }

  void removeFromCart(String itemId) {
    if (_cart.containsKey(itemId)) {
      if (_cart[itemId]!.quantity > 1) {
        _cart[itemId]!.quantity--;
      } else {
        _cart.remove(itemId);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  int getItemQuantity(String itemId) => _cart[itemId]?.quantity ?? 0;

  int get cartTotalItems {
    return _cart.values.fold(0, (sum, item) => sum + item.quantity);
  }
}

class CartItem {
  final MenuItem item;
  int quantity;

  CartItem({required this.item, this.quantity = 1});
}
