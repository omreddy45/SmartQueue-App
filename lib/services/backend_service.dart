import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_generative_ai/google_generative_ai.dart'; // Replaced by Manual REST
import '../models/canteen.dart';
import '../models/token.dart';
import '../models/queue_stats.dart';
import '../models/menu_item.dart';
import '../secrets.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class BackendService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Gemini API Key (Manual REST)
  final String _apiKey = geminiApiKey; 

  BackendService();

  // --- Auth & User Management ---
  
  // 1. Student Signup
  Future<User?> signUpStudent(String email, String password, String name) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (cred.user != null) {
         await _db.child('users/${cred.user!.uid}').set({
           'email': email,
           'name': name,
           'role': 'student',
           'createdAt': DateTime.now().millisecondsSinceEpoch
         });
      }
      return cred.user;
    } catch (e) {
      print("Student SignUp Error: $e");
      return null;
    }
  }

  // 2. Canteen Registration (Creates Admin)
  Future<User?> registerCanteen(String canteenName, String campus, String email, String password) async {
    try {
      // Create Admin User
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (cred.user == null) return null;

      // Create Canteen
      final canteenId = _generateId();
       final themes = [
        'from-blue-500 to-indigo-600',
        'from-amber-600 to-orange-600',
        'from-red-500 to-pink-600',
        'from-green-500 to-emerald-600',
        'from-purple-500 to-violet-600'
      ];
      final randomTheme = themes[Random().nextInt(themes.length)];

      final newCanteen = Canteen(
        id: canteenId,
        name: canteenName,
        campus: campus,
        themeColor: randomTheme,
      );

      // Save Canteen
      await _db.child('canteens/$canteenId').set(newCanteen.toJson());

      // Save Admin User with Canteen ID
      await _db.child('users/${cred.user!.uid}').set({
           'email': email,
           'role': 'admin',
           'canteenId': canteenId,
           'createdAt': DateTime.now().millisecondsSinceEpoch
      });

      // Initialize Default Menu
      for (var item in _defaultMenuItems) {
         await addMenuItem(canteenId, item);
      }

      return cred.user;
    } catch (e) {
      print("Canteen Registration Error: $e");
      return null;
    }
  }

  // 3. Create Staff Account (Only by Admin)
  Future<String?> createStaffAccount(String canteenId, String email, String password) async {
     try {
       // Only strictly separate if we check currentUser role, but for now allow flow.
       // Note: Creating secondary user logs out the current user in client SDK usually. 
       // We will assume this is handled or return instructions.
       final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
       if (cred.user != null) {
         await _db.child('users/${cred.user!.uid}').set({
           'email': email,
           'role': 'staff',
           'canteenId': canteenId,
           'createdAt': DateTime.now().millisecondsSinceEpoch
         });
         return "Success";
       }
       return "Failed to create user";
     } catch (e) {
       return e.toString();
     }
  }

  Future<User?> login(String email, String password) async {
     try {
       final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
       return cred.user;
     } catch (e) {
       print("Login Error: $e");
       return null;
     }
  }

  Future<Map<String, dynamic>?> getUserDetails(String uid) async {
     final snap = await _db.child('users/$uid').get();
     if (snap.exists) {
       return Map<String, dynamic>.from(snap.value as Map);
     }
     return null;
  }

  Future<String?> getUserRole(String uid) async {
     final snap = await _db.child('users/$uid/role').get();
     return snap.exists ? snap.value as String : null;
  }

  // --- Menu Management ---
  
  static final List<MenuItem> _defaultMenuItems = [
    MenuItem(id: 'vadapav', name: 'Vada Pav', icon: 'pizza', color: 'orange-100', price: 20, isAvailable: true, category: 'Snacks'),
    MenuItem(id: 'samosa', name: 'Samosa', icon: 'pizza', color: 'amber-100', price: 15, isAvailable: true, category: 'Snacks'),
    MenuItem(id: 'tea', name: 'Masala Tea', icon: 'coffee', color: 'brown-100', price: 10, isAvailable: true, category: 'Drinks'),
  ];

  Future<void> addMenuItem(String canteenId, MenuItem item) async {
    await _db.child('canteens/$canteenId/menu/${item.id}').set(item.toJson());
  }

  Future<void> updateMenuItem(String canteenId, MenuItem item) async {
    await _db.child('canteens/$canteenId/menu/${item.id}').update(item.toJson());
  }
  
  Future<void> deleteMenuItem(String canteenId, String itemId) async {
    await _db.child('canteens/$canteenId/menu/$itemId').remove();
  }

  Stream<List<MenuItem>> getMenuStream(String canteenId) {
    return _db.child('canteens/$canteenId/menu').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <MenuItem>[]; // Typed empty list
      final Map<dynamic, dynamic> map = data as Map;
      return map.values.map((e) => MenuItem.fromJson(e as Map)).toList();
    }).asBroadcastStream();
  }

  // --- Canteen & Order Management ---

  Stream<List<Canteen>> getAllCanteens() {
    return _db.child('canteens').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      final Map<dynamic, dynamic> map = data as Map;
      return map.values.map((e) => Canteen.fromJson(e as Map)).toList();
    });
  }

  Future<Canteen?> getCanteen(String id) async {
    final snapshot = await _db.child('canteens/$id').get();
    if (snapshot.exists) {
      return Canteen.fromJson(snapshot.value as Map);
    }
    return null;
  }

  // Updated to include userId and CanteenId
  Future<Token> createToken(String canteenId, String userId, List<Map<String, dynamic>> items) async {
    final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0).millisecondsSinceEpoch;
    
    // Get numeric ID for today
    int count = 0;
    try {
      final snapshot = await _db.child('tokens').orderByChild('canteenId').equalTo(canteenId).get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        count = data.values.where((e) => (e['timestamp'] as int) >= todayStart).length;
      }
    } catch (e) {
      print("Indexing Error (Using fallback count): $e");
      // Fallback: Use random/timestamp to avoid blocking order
      count = DateTime.now().millisecondsSinceEpoch % 1000; 
    }

    final foodItemSummary = items.map((e) => "${e['quantity']}x ${e['name']}").join(", ");
    final newId = _generateId();
    
    final newToken = Token(
      id: newId,
      canteenId: canteenId,
      couponCode: userId, 
      tokenNumber: _generateTokenNumber(count),
      foodItem: foodItemSummary,
      items: items,
      status: OrderStatus.WAITING,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      estimatedWaitTimeMinutes: 5 * items.length, 
    );

    // Save under global tokens (indexed)
    await _db.child('tokens/$newId').set(newToken.toJson());
    // Save reference in User History
    await _db.child('users/$userId/history/$newId').set(true);
    
    return newToken;
  }
  
  // Backwards compatibility or generic stream
  Stream<Token?> getTokenStream(String tokenId) {
    return _db.child('tokens/$tokenId').onValue.map((event) {
      if (event.snapshot.exists) {
        return Token.fromJson(event.snapshot.value as Map);
      }
      return null;
    });
  }

  Stream<int> getQueuePositionStream(String canteenId, String tokenId) {
    return _db.child('tokens').orderByChild('canteenId').equalTo(canteenId).onValue.map((event) {
       final data = event.snapshot.value;
       if (data == null) return 0;
       
       final Map<dynamic, dynamic> map = data as Map;
       final tokens = map.values.map((e) => Token.fromJson(e as Map)).toList();
       
       // Filter for Waiting
       final activeTokens = tokens.where((t) => t.status == OrderStatus.WAITING).toList();
       activeTokens.sort((a, b) => a.timestamp.compareTo(b.timestamp));
       
       final index = activeTokens.indexWhere((t) => t.id == tokenId);
       return index == -1 ? 0 : index + 1;
    }).asBroadcastStream();
  }

  // --- Staff & Kitchen ---
  
  Stream<List<Token>> getActiveQueueStream(String canteenId) {
     return getKitchenOrdersStream(canteenId);
  }

  Stream<List<Token>> getKitchenOrdersStream(String canteenId) {
    return _db.child('tokens').orderByChild('canteenId').equalTo(canteenId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <Token>[]; // Typed empty list
      final Map<dynamic, dynamic> map = data as Map;
      final tokens = map.values.map((e) => Token.fromJson(e as Map)).toList();
      
      // Kitchen wants WAITING and READY (to see what's done)
      return tokens.where((t) => t.status != OrderStatus.COMPLETED)
        .toList()..sort((a,b) => a.timestamp.compareTo(b.timestamp));
    }).asBroadcastStream();
  }

  Future<void> markOrderReady(String tokenId) async {
      await _db.child('tokens/$tokenId').update({'status': 'READY'});
  }
  
  Future<void> completeOrder(String tokenId) async {
      await markOrderCompleted(tokenId);
  }

  Future<void> markOrderCompleted(String tokenId) async {
      await _db.child('tokens/$tokenId').update({
        'status': 'COMPLETED', // String for enum
        'completedAt': DateTime.now().millisecondsSinceEpoch
      });
  }

  // --- User History ---
  
  Future<List<Token>> getStudentHistory(String userId) async {
    // 1. Get list of Token IDs from user node
    final snap = await _db.child('users/$userId/history').get();
    if (!snap.exists) return [];
    
    final tokenIds = (snap.value as Map).keys.toList();
    List<Token> history = [];
    
    // 2. Fetch each token (In efficient app, duplicate critical data to user node)
    // Using Future.wait for parallel fetch
    final futures = tokenIds.map((id) => _db.child('tokens/$id').get());
    final snapshots = await Future.wait(futures);
    
    for (var tSnap in snapshots) {
       if (tSnap.exists) {
          try {
             history.add(Token.fromJson(Map<String, dynamic>.from(tSnap.value as Map)));
          } catch (e) {
             print("Error parsing token: $e");
          }
       }
    }
    history.sort((a,b) => b.timestamp.compareTo(a.timestamp));
    return history;
  }

  Stream<List<Token>> getStudentHistoryStream(String userId) {
    // Listen to the history node for keys
    return _db.child('users/$userId/history').onValue.asyncMap((event) async {
       if (!event.snapshot.exists) return <Token>[];
       
       final tokenIds = (event.snapshot.value as Map).keys.toList();
       List<Token> history = [];
       
       final futures = tokenIds.map((id) => _db.child('tokens/$id').get());
       final snapshots = await Future.wait(futures);
       
       for (var tSnap in snapshots) {
          if (tSnap.exists) {
              try {
                history.add(Token.fromJson(Map<String, dynamic>.from(tSnap.value as Map)));
              } catch (e) { print("Parse Error: $e"); }
          }
       }
       history.sort((a,b) => b.timestamp.compareTo(a.timestamp));
       return history;
    }).asBroadcastStream();
  }
  
  // --- Admin Stats (Real-time) ---
  
  // Kept for backward compat if needed, but streams are preferred
  Future<QueueStats> getStats(String canteenId) async {
      return getCanteenStats(canteenId);
  }

  Future<QueueStats> getCanteenStats(String canteenId) async {
     // reuse logic or just one-time fetch using stream logic
     return await getStatsStream(canteenId).first;
  }

  Stream<QueueStats> getStatsStream(String canteenId) {
    return _db.child('tokens').orderByChild('canteenId').equalTo(canteenId).onValue.map((event) {
      if (!event.snapshot.exists) {
        return QueueStats(totalOrdersToday: 0, averageWaitTime: 0, peakHour: 'N/A', activeQueueLength: 0);
      }
      
      final data = event.snapshot.value as Map;
      final tokens = data.values.map((e) => Token.fromJson(e as Map)).toList();
      
      final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0).millisecondsSinceEpoch;
      final todayTokens = tokens.where((t) => t.timestamp >= todayStart).toList();
      
      final completed = todayTokens.where((t) => t.status == OrderStatus.COMPLETED && t.completedAt != null).toList();
      
      double totalWait = 0;
      for (var t in completed) {
          totalWait += (t.completedAt! - t.timestamp);
      }
      
      final avgWait = completed.isNotEmpty ? (totalWait / completed.length / 60000).round() : 0;
      final active = todayTokens.where((t) => t.status == OrderStatus.WAITING).length;

      // Peak Hour Calculation
      final hourCounts = <int, int>{};
      for (var t in todayTokens) {
         final hour = DateTime.fromMillisecondsSinceEpoch(t.timestamp).hour;
         hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
      }
      
      String peakHour = "N/A";
      if (hourCounts.isNotEmpty) {
        final maxHour = hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        final ampm = maxHour >= 12 ? 'PM' : 'AM';
        final displayHour = maxHour > 12 ? maxHour - 12 : (maxHour == 0 ? 12 : maxHour);
        peakHour = "$displayHour $ampm";
      }

      return QueueStats(
        totalOrdersToday: todayTokens.length,
        averageWaitTime: avgWait,
        peakHour: peakHour, 
        activeQueueLength: active
      );
    }).asBroadcastStream();
  }

  // Kitchen History (Completed Orders)
  Stream<List<Token>> getCanteenHistoryStream(String canteenId) {
    return _db.child('tokens').orderByChild('canteenId').equalTo(canteenId).onValue.map((event) {
       if (!event.snapshot.exists) return <Token>[];
       
       final data = event.snapshot.value as Map;
       final tokens = data.values.map((e) => Token.fromJson(e as Map)).toList();
       
       // Filter for COMPLETED
       return tokens.where((t) => t.status == OrderStatus.COMPLETED)
         .toList()..sort((a,b) => b.timestamp.compareTo(a.timestamp)); 
    }).asBroadcastStream();
  }
  
  Stream<Map<String, int>> getHourlyTrafficStream(String canteenId) {
     return _db.child('tokens').orderByChild('canteenId').equalTo(canteenId).onValue.map((event) {
        if (!event.snapshot.exists) return <String, int>{};
        
        final data = event.snapshot.value as Map;
        final tokens = data.values.map((e) => Token.fromJson(e as Map)).toList();
        
        final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0).millisecondsSinceEpoch;
        final todayTokens = tokens.where((t) => t.timestamp >= todayStart).toList();
        
        final Map<String, int> traffic = {};
        
        for (var t in todayTokens) {
           final dt = DateTime.fromMillisecondsSinceEpoch(t.timestamp);
           final hour = dt.hour;
           final ampm = hour >= 12 ? 'PM' : 'AM';
           final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
           final key = "$displayHour $ampm";
           
           traffic[key] = (traffic[key] ?? 0) + 1;
        }
        
        return traffic;
     }).asBroadcastStream();
  }
  
  // Used by old consumers, bridging to stream now
  Future<Map<String, int>> getHourlyTraffic(String canteenId) async {
       return await getHourlyTrafficStream(canteenId).first;
  }

  // --- AI Insights (Manual REST v1 to bypass SDK v1beta issues) ---

  Future<String> getDashboardInsights(QueueStats stats, Map<String, int> traffic) async {
    try {
      final prompt = """
Analyze this canteen data: 
Total Orders: ${stats.totalOrdersToday}
Active Queue: ${stats.activeQueueLength}
Avg Wait: ${stats.averageWaitTime}m
Peak Hour: ${stats.peakHour}

Generate a report in this EXACT format:
Report Generated
✓ [One short bold status, e.g. Queue Clear]
• [Actionable insight 1]
• [Actionable insight 2]
• [System readiness status]

Keep it professional and concise.
""";
      
      return await _callGeminiRest(prompt);
      
    } catch (e) {
      if (e.toString().contains("429")) return "Daily Quota Exceeded (Try later).";
      return "Insight generation failed: ${e.toString().substring(0, min(e.toString().length, 50))}...";
    }
  }

  Future<String> getStudentTokenInsight(String tokenStatus, int queuePos, int waitTime) async {
     try {
        final randomContext = Random().nextBool() ? "Checking kitchen load..." : "Analyzing chef speed...";
        final prompt = "Student order status: $tokenStatus, Queue Position: $queuePos, Est Wait: $waitTime min. Current Context: $randomContext. Give a 1 unique sentence reassuring insight (max 15 words) for the student. Vary the tone.";
        
        print("CALLING GEMINI REST API (v1) - Status: $tokenStatus"); 

        return await _callGeminiRest(prompt);

     } catch(e) {
       print("GEMINI REST API ERROR: $e"); 
       if (e.toString().contains("429")) return "Daily Quota Exceeded (Try later).";
       return "Kitchen is working on your order.";
     }
  }

  // Helper for Raw HTTP Call to v1beta (v1 returned 404, so 1.5 Flash requires v1beta)
  Future<String> _callGeminiRest(String promptText) async {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [{"text": promptText}]
          }]
        })
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Navigate JSON: candidates[0].content.parts[0].text
        try {
           return data['candidates'][0]['content']['parts'][0]['text'];
        } catch (e) {
           return "Analysis unavailable.";
        }
      } else {
        throw Exception('Failed to load: ${response.statusCode} ${response.body}');
      }
  }


  // Helpers
  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString();
  String _generateTokenNumber(int count) => 'A-${(count + 1).toString().padLeft(3, '0')}';

  // --- Gemini (Unchanged mostly) ---
  Future<String> getAIWaitTimeReasoning(int activeOrders, int chefs) async {
      try {
        final prompt = "Explain briefly (1 sentence) why the wait time might be high. Context: $activeOrders active orders, $chefs chefs working.";
        return await _callGeminiRest(prompt);
      } catch (e) {
        // Fallback or explicit error handling
        return "Analyzing queue dynamics...";
      }
  }
  
  Future<void> updateTokenEstimation(String tokenId, int minutes, {String? reasoning}) async {
    final Map<String, dynamic> updates = {'estimatedWaitTimeMinutes': minutes};
    if (reasoning != null) updates['aiReasoning'] = reasoning;
    await _db.child('tokens/$tokenId').update(updates);
  }

  String getDemoCanteenId() {
    return "demo_canteen_1"; 
  }
}
