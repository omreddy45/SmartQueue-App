import 'package:flutter/foundation.dart';
import '../models/user_role.dart';
import '../models/canteen.dart';
import '../models/menu_item.dart';
import '../services/backend_service.dart';
import '../services/notification_service.dart';

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

  Future<String?> login(String email, String password) async {
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
            
            if (_currentRole != UserRole.student && details.containsKey('canteenId')) {
               final canteen = await _backendService.getCanteen(details['canteenId']);
               if (canteen != null) {
                 _selectedCanteen = canteen;
               }
            }
            
            await _initApp(); // Initialize Notifications
            notifyListeners();
            return null; // Success (no error)
         }
       }
       return "User user not found in database or invalid credentials.";
     } catch (e) {
       print("Login Provider Error: $e");
       return e.toString();
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
       await _initApp();
       notifyListeners();
       return true;
     }
     return false;
  }

  Future<String?> registerCanteen(String canteenName, String campus, String email, String password) async {
      final user = await _backendService.registerCanteen(canteenName, campus, email, password);
      if (user != null) {
         // Re-fetch to get correct state including canteenId
         return await login(email, password);
      }
      return "Registration failed. Please check your details.";
  }

  void setRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  void selectCanteen(Canteen canteen) {
    _selectedCanteen = canteen;
    notifyListeners();
  }

  Future<void> _initApp() async {
    // 1. Init Notification Service
    try {
      final notif = NotificationService();
      await notif.initialize();
      final token = await notif.getDeviceToken();
      if (token != null && _currentUser != null && _currentUser!['role'] == UserRole.student.name) {
         await _backendService.saveUserFcmToken(_currentUser!['uid'], token);
      }
    } catch (e) {
      print("Notification Init Error: $e");
    }
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
    // Do NOT reset _currentRole. This allows "Scan QR" to go back to Scanner without full logout.
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
