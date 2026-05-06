import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../firebase_options.dart';

class FirebaseService {
  static bool isFirebaseInitialized = false;
  static bool useDemoMode = true; // Automatically falls back to Demo Mode if Firebase init fails

  // Active Session
  static UserModel? currentUser;

  // Mock Databases (In-Memory for Demo Mode)
  static final List<UserModel> _mockUsers = [
    UserModel(
      uid: 'demo_customer_1',
      fullName: 'Muhammet Demir',
      email: 'musteri@yemek.com',
      role: 'customer',
      status: 'active',
      createdAt: DateTime.now(),
    ),
    UserModel(
      uid: 'demo_restaurant_1',
      fullName: 'Kebapçı Mahmut Usta',
      email: 'restoran@yemek.com',
      role: 'restaurant_owner',
      status: 'active',
      createdAt: DateTime.now(),
    ),
  ];

  static final List<FoodItem> _mockFoodItems = [
    FoodItem(
      id: 'food_1',
      name: 'Özel Adana Kebabı',
      description: 'Zırhta çekilmiş kuzu kıyması, közlenmiş biber, domates ve sumaklı soğan salatası ile.',
      price: 240.0,
      imageUrl: 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
      category: 'Kebaplar',
      rating: 4.9,
    ),
    FoodItem(
      id: 'food_2',
      name: 'Tombik Tavuk Döner',
      description: 'Özel marinasyonlu taze tavuk göğsü, patates kızartması ve sarımsaklı mayonez sos eşliğinde.',
      price: 130.0,
      imageUrl: 'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
      category: 'Dönerler',
      rating: 4.6,
    ),
    FoodItem(
      id: 'food_3',
      name: 'Gurme Cheddar Burger',
      description: '150g katkısız dana köftesi, karamelize soğan, çift cheddar peyniri ve özel burger sos.',
      price: 185.0,
      imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
      category: 'Burgerler',
      rating: 4.8,
    ),
    FoodItem(
      id: 'food_4',
      name: 'Margarita Pizza',
      description: 'Taş fırında taze mozzarella, ev yapımı İtalyan domates sosu ve taze fesleğen yaprakları.',
      price: 175.0,
      imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
      category: 'Pizzalar',
      rating: 4.5,
    ),
    FoodItem(
      id: 'food_5',
      name: 'Cevizli Ev Baklavası',
      description: '40 kat incecik açılmış hamur, bol Giresun cevizi ve özel kıvamlı şerbeti ile enfes lezzet.',
      price: 110.0,
      imageUrl: 'https://images.unsplash.com/photo-1519676867240-f03562e64548?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
      category: 'Tatlılar',
      rating: 4.7,
    ),
    FoodItem(
      id: 'food_6',
      name: 'Hatay Usulü Künefe',
      description: 'Tuzsuz Hatay peyniri, çıtır kadayıf, tereyağı ve fıstık tozu ile sıcak servis edilir.',
      price: 125.0,
      imageUrl: 'https://images.unsplash.com/photo-1519676867240-f03562e64548?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
      category: 'Tatlılar',
      rating: 4.9,
    ),
    FoodItem(
      id: 'food_7',
      name: 'Yayık Ayranı',
      description: 'Doğal yoğurttan bol köpüklü, taze nane yaprağı ile serinletici lezzet.',
      price: 35.0,
      imageUrl: 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
      category: 'İçecekler',
      rating: 4.8,
    ),
  ];

  static final List<OrderModel> _mockOrders = [
    OrderModel(
      id: 'ord_101',
      customerId: 'demo_customer_1',
      customerName: 'Muhammet Demir',
      items: [
        OrderItem(
          foodItem: FoodItem(
            id: 'food_1',
            name: 'Özel Adana Kebabı',
            description: '',
            price: 240.0,
            imageUrl: '',
            category: 'Kebaplar',
            rating: 4.9,
          ),
          quantity: 2,
        ),
        OrderItem(
          foodItem: FoodItem(
            id: 'food_7',
            name: 'Yayık Ayranı',
            description: '',
            price: 35.0,
            imageUrl: '',
            category: 'İçecekler',
            rating: 4.8,
          ),
          quantity: 2,
        ),
      ],
      totalAmount: 550.0,
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
  ];

  // Stream Controllers for Mock Real-Time Updates
  static final StreamController<List<FoodItem>> _foodStreamController = StreamController<List<FoodItem>>.broadcast();
  static final StreamController<List<OrderModel>> _orderStreamController = StreamController<List<OrderModel>>.broadcast();

  // Initialization
  static Future<void> initialize() async {
    try {
      // Firebase options is typically generated by FlutterFire CLI.
      // We attempt initialization. If no configuration is present, it will throw an error.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isFirebaseInitialized = true;
      useDemoMode = false;
      debugPrint("Firebase successfully initialized! App will run on Cloud Firestore.");
    } catch (e) {
      isFirebaseInitialized = false;
      useDemoMode = true;
      debugPrint("Firebase initialization failed ($e). App will run in Offline Demo Mode.");
    }

    // Initialize mock streams
    _foodStreamController.add(_mockFoodItems);
    _orderStreamController.add(_mockOrders);
  }

  // Auth Operations
  static Future<String?> signIn({
    required String email,
    required String password,
    required String role, // customer or restaurant_owner
  }) async {
    if (!useDemoMode) {
      try {
        UserCredential credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Fetch User details from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          String dbRole = data['role'] ?? 'customer';
          
          if (dbRole != role && dbRole != 'admin') {
            await FirebaseAuth.instance.signOut();
            return "Seçilen giriş türü bu hesapla eşleşmiyor. Lütfen doğru rolü seçin.";
          }

          currentUser = UserModel.fromMap(data);
          return null; // Success
        } else {
          await FirebaseAuth.instance.signOut();
          return "Kullanıcı kaydı bulunamadı.";
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') return "Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.";
        if (e.code == 'wrong-password') return "Hatalı şifre girdiniz.";
        return e.message ?? "Giriş yapılamadı.";
      } catch (e) {
        return "Bir hata oluştu: ${e.toString()}";
      }
    } else {
      // Demo Mode Authentication
      await Future.delayed(const Duration(milliseconds: 800)); // Simulate network latency

      // Check if user exists in mock database
      final match = _mockUsers.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase() && (u.role == role || u.role == 'admin'),
        orElse: () => UserModel(uid: '', fullName: '', email: '', role: '', createdAt: DateTime.now()),
      );

      if (match.uid.isEmpty) {
        // Allow creating demo account on the fly if it's the correct credentials but password is correct
        if (email.contains('@') && password.length >= 6) {
          // If they try logging in with demo credentials, check passwords
          if (email == 'musteri@yemek.com' && role == 'customer') {
            currentUser = _mockUsers.firstWhere((u) => u.uid == 'demo_customer_1');
            return null;
          }
          if (email == 'restoran@yemek.com' && role == 'restaurant_owner') {
            currentUser = _mockUsers.firstWhere((u) => u.uid == 'demo_restaurant_1');
            return null;
          }
          return "Bu e-posta ile kayıtlı bir $role bulunamadı. Lütfen 'Hemen Kayıt Ol' kısmından yeni hesap oluşturun.";
        }
        return "Geçersiz e-posta adresi veya şifre (Min. 6 karakter).";
      }

      currentUser = match;
      return null; // Success
    }
  }

  static Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    if (!useDemoMode) {
      try {
        UserCredential credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Query Firestore users collection to check if empty
        final usersSnapshot = await FirebaseFirestore.instance.collection('users').limit(1).get();
        final bool isFirstUser = usersSnapshot.docs.isEmpty;
        
        final finalRole = isFirstUser ? 'admin' : role;

        UserModel newUser = UserModel(
          uid: credential.user!.uid,
          fullName: fullName,
          email: email,
          role: finalRole,
          status: 'active',
          createdAt: DateTime.now(),
        );

        // Save to Firestore users collection
        await FirebaseFirestore.instance.collection('users').doc(newUser.uid).set(newUser.toMap());
        
        currentUser = newUser;
        return null; // Success
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') return "Bu e-posta adresi zaten kullanımda.";
        if (e.code == 'weak-password') return "Belirlenen şifre çok zayıf.";
        return e.message ?? "Kayıt işlemi başarısız.";
      } catch (e) {
        return "Bir hata oluştu: ${e.toString()}";
      }
    } else {
      // Demo Mode Registration
      await Future.delayed(const Duration(milliseconds: 800));

      final exists = _mockUsers.any((u) => u.email.toLowerCase() == email.toLowerCase());
      if (exists) {
        return "Bu e-posta adresi zaten kullanımda.";
      }

      // Check if there are no manually registered demo users yet
      final bool isFirstManualRegister = !_mockUsers.any((u) => u.uid != 'demo_customer_1' && u.uid != 'demo_restaurant_1');
      final finalRole = isFirstManualRegister ? 'admin' : role;

      UserModel newUser = UserModel(
        uid: 'demo_user_${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName,
        email: email,
        role: finalRole,
        status: 'active',
        createdAt: DateTime.now(),
      );

      _mockUsers.add(newUser);
      currentUser = newUser;
      return null; // Success
    }
  }

  static Future<String?> resetPassword(String email) async {
    if (!useDemoMode) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        return null; // Success
      } on FirebaseAuthException catch (e) {
        return e.message ?? "Şifre sıfırlama e-postası gönderilemedi.";
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 600));
      return null; // Mock Success
    }
  }

  static Future<void> signOut() async {
    if (!useDemoMode) {
      await FirebaseAuth.instance.signOut();
    }
    currentUser = null;
  }

  // Database Streams (Real-Time)
  static Stream<List<FoodItem>> streamFoodItems() {
    if (!useDemoMode) {
      return FirebaseFirestore.instance.collection('meals').snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          data['id'] = doc.id;
          return FoodItem.fromMap(data);
        }).toList();
      });
    } else {
      return _foodStreamController.stream;
    }
  }

  static Stream<List<OrderModel>> streamOrders() {
    if (!useDemoMode) {
      return FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          data['id'] = doc.id;
          return OrderModel.fromMap(data);
        }).toList();
      });
    } else {
      return _orderStreamController.stream;
    }
  }

  // Add Meal (Restaurant Owner)
  static Future<String?> addFoodItem(FoodItem meal) async {
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance.collection('meals').add(meal.toMap());
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
      FoodItem newItem = FoodItem(
        id: 'food_${DateTime.now().millisecondsSinceEpoch}',
        name: meal.name,
        description: meal.description,
        price: meal.price,
        imageUrl: meal.imageUrl.isNotEmpty ? meal.imageUrl : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.0.3',
        category: meal.category,
        rating: meal.rating,
      );
      _mockFoodItems.insert(0, newItem);
      _foodStreamController.add(List.from(_mockFoodItems));
      return null;
    }
  }

  // Delete Meal (Restaurant Owner)
  static Future<String?> deleteFoodItem(String foodId) async {
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance.collection('meals').doc(foodId).delete();
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
      _mockFoodItems.removeWhere((item) => item.id == foodId);
      _foodStreamController.add(List.from(_mockFoodItems));
      return null;
    }
  }

  // Submit Order (Customer)
  static Future<String?> placeOrder(List<OrderItem> items, double total) async {
    if (currentUser == null) return "Giriş yapmış bir kullanıcı bulunamadı.";

    if (!useDemoMode) {
      try {
        OrderModel newOrder = OrderModel(
          id: '',
          customerId: currentUser!.uid,
          customerName: currentUser!.fullName,
          items: items,
          totalAmount: total,
          status: 'pending',
          createdAt: DateTime.now(),
        );

        await FirebaseFirestore.instance.collection('orders').add(newOrder.toMap());
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 600));
      OrderModel newOrder = OrderModel(
        id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
        customerId: currentUser!.uid,
        customerName: currentUser!.fullName,
        items: items,
        totalAmount: total,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      _mockOrders.insert(0, newOrder);
      _orderStreamController.add(List.from(_mockOrders));
      return null;
    }
  }

  // Update Order Status (Restaurant Owner / Admin)
  static Future<String?> updateOrderStatus(String orderId, String newStatus) async {
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
          'status': newStatus,
        });
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      int index = _mockOrders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _mockOrders[index].status = newStatus;
        _orderStreamController.add(List.from(_mockOrders));
        return null;
      }
      return "Sipariş bulunamadı.";
    }
  }
}
