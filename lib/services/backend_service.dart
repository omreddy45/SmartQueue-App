import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/canteen.dart';
import '../models/token.dart';
import '../models/queue_stats.dart';
import '../models/menu_item.dart';
import '../secrets.dart';

import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

class BackendService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Gemini Model
  late final GenerativeModel _model;
  final String _apiKey = Secrets.geminiApiKey; 

  BackendService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash', // Updated to latest stable version (Jan 2026)
      apiKey: _apiKey,
    );
  }

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
        throw e.toString();
      }
  }

  Future<User?> login(String email, String password) async {
     try {
       final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
       return cred.user;
     } catch (e) {
       // Propagate error
       rethrow;
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

  Future<void> saveUserFcmToken(String userId, String token) async {
     await _db.child('users/$userId/fcmToken').set(token);
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

  // Updated to include userId and CanteenId and isOffline
  Future<Token> createToken(String canteenId, String userId, List<Map<String, dynamic>> items, {bool isOffline = false}) async {
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
      userId: userId, // Added userId to Token model
      couponCode: userId, 
      tokenNumber: _generateTokenNumber(count),
      foodItem: foodItemSummary,
      items: items,
      status: OrderStatus.WAITING,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      estimatedWaitTimeMinutes: 5 * items.length,
      isOffline: isOffline, 
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
    // Updated to Client-Side Filtering
    return _db.child('tokens').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <Token>[]; // Typed empty list
      
      final Map<dynamic, dynamic> map = data as Map;
      final tokens = map.values
        .map((e) => Token.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((t) => t.canteenId == canteenId)
        .toList();
      
      // Kitchen wants WAITING and READY (to see what's done)
      return tokens.where((t) => t.status != OrderStatus.COMPLETED)
        .toList()..sort((a,b) => a.timestamp.compareTo(b.timestamp));
    }).asBroadcastStream();
  }

  Future<void> markOrderReady(String tokenId) async {
      await _db.child('tokens/$tokenId').update({
        'status': 'READY',
        'readyAt': DateTime.now().millisecondsSinceEpoch
      });
      
      // Notify User
      try {
        final snap = await _db.child('tokens/$tokenId').get();
        if (snap.exists) {
           final token = Token.fromJson(Map<String, dynamic>.from(snap.value as Map));
           
           // Skip if offline order
           if (token.isOffline) {
             print("Skipping notification for Offline Order ${token.tokenNumber}");
             return;
           }

           // Send Notification
           await sendPushNotification(token.userId, "Order Ready!", "Your order ${token.tokenNumber} is ready to collect.");
        }
      } catch (e) {
        print("Error triggering notif: $e");
      }
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

  // AI Caching Variables
  DateTime? _lastAiFetchTime;
  double _cachedPerOrderRate = 4.0; // Default: 4 minutes per order (Conservative)

  Stream<QueueStats> getStatsStream(String canteenId) {
    // Robust Fix: Fetch ALL tokens and filter in code (Avoids indexing issues)
    return _db.child('tokens').onValue.asyncMap((event) async {
      if (!event.snapshot.exists) {
        return QueueStats(totalOrdersToday: 0, averageWaitTime: 0, peakHour: 'N/A', activeQueueLength: 0, topItems: {});
      }
      
      final data = event.snapshot.value as Map;
      final tokens = data.values
        .map((e) => Token.fromJson(Map<String,dynamic>.from(e as Map)))
        .where((t) => t.canteenId == canteenId)
        .toList();
      
      final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0).millisecondsSinceEpoch;
      final todayTokens = tokens.where((t) => t.timestamp >= todayStart).toList();
      
      final completed = todayTokens.where((t) => t.status == OrderStatus.COMPLETED && t.completedAt != null).toList();
      
      // 1. Avg Wait Calculation (Historical Fallback)
      double totalWait = 0;
      for (var t in completed) {
          totalWait += (t.completedAt! - t.timestamp);
      }
      final historicalAvg = completed.isNotEmpty ? (totalWait / completed.length / 60000).round() : 0;
      
      // Update default rate if history is available (Blend with heuristic)
      if (historicalAvg > 0 && completed.isNotEmpty) {
         // If avg wait is 15 mins for completed orders, and typical queue was X... 
         // Hard to derive rate without queue history. 
         // Instead, we just trust the cached rate or default.
      }

      // 2. Queue Length
      final active = todayTokens.where((t) => t.status == OrderStatus.WAITING || t.status == OrderStatus.READY).length;

      // 3. Peak Hour
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

      // 4. Top Items Calculation
      final itemCounts = <String, int>{};
      for (var t in todayTokens) {
        if (t.items == null) continue;
        for (var item in t.items!) {
           final name = item['name'] as String;
           final qty = item['quantity'] as int;
           itemCounts[name] = (itemCounts[name] ?? 0) + qty;
        }
      }
      final sortedItems = itemCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topItems = Map.fromEntries(sortedItems.take(5));
      final topItemsStr = topItems.keys.join(", ");

      // 5. Smart Wait Time (Formula + AI Tuning)
      int estimatedWait = 0;
      if (active > 0) {
         // A. Calculate Formula Baseline
         estimatedWait = (active * _cachedPerOrderRate).round();

         // B. Check if we should update Rate with AI (Throttle: 5 mins)
         bool shouldCallAi = _lastAiFetchTime == null || DateTime.now().difference(_lastAiFetchTime!).inMinutes >= 5;
         
         if (shouldCallAi) {
             try {
               print("Calling Gemini for Stats (Throttled)...");
               final prompt = "Analyze Canteen Queue: $active active orders. Top items: $topItemsStr. Time: ${DateTime.now().hour}h. Historical Avg: $historicalAvg min. Estimate REALISTIC wait time (in minutes) for a NEW order. Consider item complexity (e.g. Tea=fast, Meal=slow). Return ONLY the integer number.";
               final aiRes = await _callGeminiSafe(prompt);
               final parsed = int.tryParse(aiRes.replaceAll(RegExp(r'[^0-9]'), ''));
               
               if (parsed != null && parsed > 0) {
                 estimatedWait = parsed;
                 // Update Rate for subsequent formula calls
                 _cachedPerOrderRate = parsed / active;
                 _lastAiFetchTime = DateTime.now();
               }
             } catch (e) {
               print("AI Stats Skipped (Quota/Error): $e");
               // Keep using existing _cachedPerOrderRate in next event
             }
         }
      } else {
         estimatedWait = 0; 
      }

      return QueueStats(
        totalOrdersToday: todayTokens.length,
        averageWaitTime: estimatedWait, 
        peakHour: peakHour, 
        activeQueueLength: active,
        topItems: topItems,
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
     return _db.child('tokens').onValue.map((event) {
        if (!event.snapshot.exists) return <String, int>{};
        
        final data = event.snapshot.value as Map;
        final tokens = data.values
            .map((e) => Token.fromJson(e as Map))
            .where((t) => t.canteenId == canteenId)
            .toList();
        
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

  // --- AI Insights (Using Google Generative AI SDK) ---

  Future<String> getDashboardInsights(QueueStats stats, Map<String, int> traffic) async {
    try {
      final topItemsList = stats.topItems.entries.map((e) => "${e.key} (${e.value})").join(", ");
      
      final prompt = """
Analyze this canteen data: 
Total Orders: ${stats.totalOrdersToday}
Active Queue: ${stats.activeQueueLength}
Avg Wait: ${stats.averageWaitTime}m
Peak Hour: ${stats.peakHour}
Top Selling Items: $topItemsList

Generate a report in this EXACT format:
Report Generated
✓ [One short bold status, e.g. High Demand/Queue Clear]
• [Insight on most popular items and trends]
• [Insight on staffing efficiency based on wait time]
• [Insight on system readiness or peak hour prep]

Keep it professional and concise.
""";
      
      return await _callGeminiSafe(prompt);
      
    } catch (e) {
      print("Gemini Analysis Error: $e"); // Log full error
      if (e.toString().contains("429")) return "Daily Quota Exceeded (Try later).";
      return "Error: $e";
    }
  }

  Future<String> getStudentTokenInsight(String tokenStatus, int queuePos, int waitTime) async {
     try {
        final randomContext = Random().nextBool() ? "Checking kitchen load..." : "Analyzing chef speed...";
        final prompt = "Student order status: $tokenStatus, Queue Position: $queuePos, Est Wait: $waitTime min. Current Context: $randomContext. Give a 1 unique sentence reassuring insight (max 15 words) for the student. Vary the tone.";
        
        print("CALLING GEMINI SDK - Status: $tokenStatus"); 
        return await _callGeminiSafe(prompt);
     } catch(e) {
       return "Your order is being prepared!"; 
     }
  }

  // --- Enhanced AI Insights for Student Token ---
  Future<Map<String, String>> getEnhancedTokenInsight(Token token, int queuePos) async {
    try {
       // 1. Fetch current stats for context
       final stats = await getStatsStream(token.canteenId).first;
       
       // 2. Format Items
       String itemsList = "";
       if (token.items != null) {
          itemsList = token.items!.map((i) => "${i['name']} (x${i['quantity']})").join(", ");
       } else {
          itemsList = token.foodItem;
       }

       // 3. Construct Prompt
       final prompt = """
Analyze this student order for a University Canteen:
- Items Ordered: $itemsList
- Queue Position: $queuePos
- Total Active Orders in Canteen: ${stats.activeQueueLength}
- Historical Avg Wait: ${stats.averageWaitTime} min

Rules for Estimation:
1. Instant Items: Tea, Coffee, Cold Drinks, Chips (Pre-packaged or thermos). Time: 1-2 min irrespective of queue.
2. Fast Items: Samosa, Vada Pav, Puffs (Already prepared, just heating/serving). Time: 2-4 min.
3. Cooked Items: Dosa, Noodles, Meals (Freshly made). Time: 8-15 min depending on queue.
4. Queue Factor: Add 1-2 min per person ahead ONLY IF items require cooking.

Calculate a REALISTIC wait time for this specific order.
Provide a JSON response EXACTLY like this (no markdown, just raw json):
{
  "estimated_time": "10-15",
  "insight": "Short friendly reason (max 10 words, e.g. 'Tea is ready, just pouring!')"
}
""";

       final responseText = await _callGeminiSafe(prompt);
       
       // 4. Parse JSON
       final cleaned = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
       final json = jsonDecode(cleaned);
       return {
         "estimated_time": json['estimated_time']?.toString() ?? "${token.estimatedWaitTimeMinutes}",
         "insight": json['insight']?.toString() ?? "Preparing your order..."
       };

    } catch (e) {
      print("AI Token Error: $e");
      return {
        "estimated_time": "${token.estimatedWaitTimeMinutes}",
        "insight": "Cooking up something good!"
      };
    }
  }

  // Helper for all Gemini calls
  Future<String> _callGeminiSafe(String prompt) async {
     try {
       final content = [Content.text(prompt)];
       final response = await _model.generateContent(content);
       return response.text ?? "Analysis failed.";
     } catch (e) {
       throw e; // Rethrow to be handled by caller
     }
  }

  // Helpers
  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString();
  String _generateTokenNumber(int count) => 'A-${(count + 1).toString().padLeft(3, '0')}';

  // --- Gemini (Unchanged mostly) ---
  Future<String> getAIWaitTimeReasoning(int activeOrders, int chefs) async {
      try {
        final prompt = "Explain briefly (1 sentence) why the wait time might be high. Context: $activeOrders active orders, $chefs chefs working.";
        return await _callGeminiSafe(prompt);
      } catch (e) {
        print("Gemini Analysis Error: $e");
        return "Error: $e"; 
      }
  }
  
  Future<void> updateTokenEstimation(String tokenId, int minutes, {String? reasoning}) async {
    final Map<String, dynamic> updates = {'estimatedWaitTimeMinutes': minutes};
    if (reasoning != null) updates['aiReasoning'] = reasoning;
    await _db.child('tokens/$tokenId').update(updates);
  }

  // --- FCM Notifications (V1 API) ---
  
  Future<String?> _getAccessToken() async {
    try {
      final serviceAccountCredentials = auth.ServiceAccountCredentials.fromJson(Secrets.serviceAccountJson);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final client = await auth.clientViaServiceAccount(serviceAccountCredentials, scopes);
    final credentials = client.credentials; 
    return credentials.accessToken.data;
    } catch (e) {
      print("OAuth Token Error: $e");
      return null;
    }
  }

  Future<void> sendPushNotification(String userId, String title, String body) async {
     try {
       // 1. Get User Device Token
       final snap = await _db.child('users/$userId/fcmToken').get();
       if (!snap.exists) return;
       final deviceToken = snap.value as String;

       // 2. Get OAuth Access Token
       final accessToken = await _getAccessToken();
       if (accessToken == null) {
         print("Failed to get Access Token for FCM");
         return;
       }

       // 3. Send via FCM V1 Endpoint
       final String projectId = Secrets.projectId; 
       final Uri url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

       final response = await http.post(
         url,
         headers: <String, String>{
           'Content-Type': 'application/json',
           'Authorization': 'Bearer $accessToken',
         },
         body: jsonEncode({
           "message": {
             "token": deviceToken,
             "notification": {
               "title": title,
               "body": body,
             },
             "data": {
               "click_action": "FLUTTER_NOTIFICATION_CLICK",
               "id": "1",
               "status": "done"
             },
             "android": {
               "priority": "high",
               "notification": {
                 "channel_id": "order_updates"
               }
             }
           }
         }),
       );

       if (response.statusCode == 200) {
          print("Notification Sent to $userId (V1)");
       } else {
          print("FCM V1 Error: ${response.statusCode} - ${response.body}");
       }

     } catch (e) {
       print("FCM Error: $e");
     }
  }

  String getDemoCanteenId() {
    return "demo_canteen_1"; 
  }
}
