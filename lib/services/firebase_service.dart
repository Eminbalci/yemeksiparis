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
      phone: '0532 111 22 33',
      address: 'Kadıköy, İstanbul',
    ),
    UserModel(
      uid: 'demo_restaurant_1',
      fullName: 'Kebapçı Mahmut Usta',
      email: 'restoran@yemek.com',
      role: 'restaurant_owner',
      status: 'active',
      createdAt: DateTime.now(),
      restaurantName: 'Mahmut Usta Kebap Evi',
      restaurantAddress: 'Kadıköy, İstanbul',
    ),
  ];

  // Mock address and branch databases
  static final Map<String, List<DeliveryAddress>> _mockAddresses = {
    'demo_customer_1': [
      DeliveryAddress(
        id: 'addr_1',
        title: 'Ev',
        fullAddress: 'Moda Caddesi No:15 Daire:3, Kadıköy, İstanbul',
        phone: '0532 111 22 33',
      ),
    ],
  };

  static final Map<String, List<RestaurantBranch>> _mockBranches = {
    'demo_restaurant_1': [
      RestaurantBranch(
        id: 'branch_1',
        name: 'Merkez Şube',
        address: 'Bahariye Caddesi No:42, Kadıköy, İstanbul',
        phone: '0216 555 44 33',
        isActive: true,
      ),
    ],
  };

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
  static final StreamController<List<UserModel>> _usersStreamController = StreamController<List<UserModel>>.broadcast();
  static final StreamController<List<DeliveryAddress>> _addressStreamController = StreamController<List<DeliveryAddress>>.broadcast();
  static final StreamController<List<RestaurantBranch>> _branchStreamController = StreamController<List<RestaurantBranch>>.broadcast();

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
    _usersStreamController.add(_mockUsers);
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
    String phone = '',
    String address = '',
    String restaurantName = '',
    String restaurantAddress = '',
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
          phone: phone,
          address: address,
          restaurantName: restaurantName,
          restaurantAddress: restaurantAddress,
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
        phone: phone,
        address: address,
        restaurantName: restaurantName,
        restaurantAddress: restaurantAddress,
      );

      _mockUsers.add(newUser);
      _usersStreamController.add(List.from(_mockUsers));
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

  // Edit Meal (Restaurant Owner)
  static Future<String?> updateFoodItem(FoodItem item) async {
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance.collection('meals').doc(item.id).update(item.toMap());
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      final idx = _mockFoodItems.indexWhere((f) => f.id == item.id);
      if (idx != -1) {
        _mockFoodItems[idx] = item;
        _foodStreamController.add(List.from(_mockFoodItems));
      }
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

  // Stream of all Users in the system (Admin only)
  static Stream<List<UserModel>> streamUsers() {
    if (!useDemoMode) {
      return FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          data['uid'] = doc.id;
          return UserModel.fromMap(data);
        }).toList();
      });
    } else {
      return _usersStreamController.stream;
    }
  }

  // Update user role (Admin authorization)
  static Future<String?> updateUserRole(String uid, String newRole) async {
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'role': newRole,
        });
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      int index = _mockUsers.indexWhere((u) => u.uid == uid);
      if (index != -1) {
        _mockUsers[index] = UserModel(
          uid: _mockUsers[index].uid,
          fullName: _mockUsers[index].fullName,
          email: _mockUsers[index].email,
          role: newRole,
          status: _mockUsers[index].status,
          createdAt: _mockUsers[index].createdAt,
        );
        _usersStreamController.add(List.from(_mockUsers));
        
        // If current user's role is updated, sync it live as well
        if (currentUser?.uid == uid) {
          currentUser = _mockUsers[index];
        }
        return null;
      }
      return "Kullanıcı bulunamadı.";
    }
  }

  // ─────────────────────────────────────────
  // PROFILE UPDATE
  // ─────────────────────────────────────────
  static Future<String?> updateUserProfile({
    required String uid,
    String? phone,
    String? address,
    String? restaurantName,
    String? restaurantAddress,
  }) async {
    if (!useDemoMode) {
      try {
        final data = <String, dynamic>{};
        if (phone != null) data['phone'] = phone;
        if (address != null) data['address'] = address;
        if (restaurantName != null) data['restaurantName'] = restaurantName;
        if (restaurantAddress != null) data['restaurantAddress'] = restaurantAddress;
        await FirebaseFirestore.instance.collection('users').doc(uid).update(data);
        if (currentUser?.uid == uid) {
          currentUser = currentUser!.copyWith(
            phone: phone,
            address: address,
            restaurantName: restaurantName,
            restaurantAddress: restaurantAddress,
          );
        }
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      final idx = _mockUsers.indexWhere((u) => u.uid == uid);
      if (idx != -1) {
        _mockUsers[idx] = _mockUsers[idx].copyWith(
          phone: phone,
          address: address,
          restaurantName: restaurantName,
          restaurantAddress: restaurantAddress,
        );
        if (currentUser?.uid == uid) currentUser = _mockUsers[idx];
        _usersStreamController.add(List.from(_mockUsers));
      }
      return null;
    }
  }

  // ─────────────────────────────────────────
  // DELIVERY ADDRESSES (Customer)
  // ─────────────────────────────────────────


  static Stream<List<DeliveryAddress>> streamAddresses(String uid) {
    if (!useDemoMode) {
      return FirebaseFirestore.instance
          .collection('users').doc(uid).collection('addresses')
          .snapshots()
          .map((s) => s.docs.map((d) => DeliveryAddress.fromMap(d.data())).toList());
    }
    Future.microtask(() =>
        _addressStreamController.add(List.from(_mockAddresses[uid] ?? [])));
    return _addressStreamController.stream;
  }

  static Future<String?> saveAddress(String uid, DeliveryAddress addr) async {
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('addresses')
            .doc(addr.id).set(addr.toMap());
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 200));
      _mockAddresses.putIfAbsent(uid, () => []);
      final list = _mockAddresses[uid]!;
      final idx = list.indexWhere((a) => a.id == addr.id);
      if (idx == -1) { list.add(addr); } else { list[idx] = addr; }
      _addressStreamController.add(List.from(list));
      return null;
    }
  }

  static Future<String?> deleteAddress(String uid, String addressId) async {
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('addresses')
            .doc(addressId).delete();
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      _mockAddresses[uid]?.removeWhere((a) => a.id == addressId);
      _addressStreamController.add(List.from(_mockAddresses[uid] ?? []));
      return null;
    }
  }

  // ─────────────────────────────────────────
  // RESTAURANT BRANCHES
  // ─────────────────────────────────────────


  static Stream<List<RestaurantBranch>> streamBranches(String uid) {
    if (!useDemoMode) {
      return FirebaseFirestore.instance
          .collection('restaurants').doc(uid).collection('branches')
          .snapshots()
          .map((s) => s.docs.map((d) => RestaurantBranch.fromMap(d.data())).toList());
    }
    Future.microtask(() =>
        _branchStreamController.add(List.from(_mockBranches[uid] ?? [])));
    return _branchStreamController.stream;
  }

  static Future<String?> saveBranch(String uid, RestaurantBranch branch) async {
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance
            .collection('restaurants').doc(uid).collection('branches')
            .doc(branch.id).set(branch.toMap());
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 200));
      _mockBranches.putIfAbsent(uid, () => []);
      final list = _mockBranches[uid]!;
      final idx = list.indexWhere((b) => b.id == branch.id);
      if (idx == -1) { list.add(branch); } else { list[idx] = branch; }
      _branchStreamController.add(List.from(list));
      return null;
    }
  }

  static Future<String?> deleteBranch(String uid, String branchId) async {
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance
            .collection('restaurants').doc(uid).collection('branches')
            .doc(branchId).delete();
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      _mockBranches[uid]?.removeWhere((b) => b.id == branchId);
      _branchStreamController.add(List.from(_mockBranches[uid] ?? []));
      return null;
    }
  }

  // ─────────────────────────────────────────
  // FOOD ITEM CRUD (edit + delete)
  // ─────────────────────────────────────────
  // DISCOUNT CODES
  // ─────────────────────────────────────────
  static final StreamController<List<DiscountCode>> _discountStreamController =
      StreamController<List<DiscountCode>>.broadcast();

  static final List<DiscountCode> _mockDiscountCodes = [
    DiscountCode(
      id: 'dc_1',
      code: 'HOSGELDIN20',
      type: DiscountType.percentage,
      value: 20,
      restaurantOwnerId: 'demo_restaurant_1',
      branchName: 'Tüm Şubeler',
      minimumOrderAmount: 100,
      stackable: false,
      maxUses: 100,
      currentUses: 3,
      isActive: true,
    ),
  ];

  static Stream<List<DiscountCode>> streamDiscountCodes(String ownerUid) {
    if (!useDemoMode) {
      return FirebaseFirestore.instance
          .collection('discount_codes')
          .where('restaurantOwnerId', isEqualTo: ownerUid)
          .snapshots()
          .map((s) => s.docs.map((d) => DiscountCode.fromMap(d.data())).toList());
    }
    Future.microtask(() => _discountStreamController.add(
        _mockDiscountCodes.where((d) => d.restaurantOwnerId == ownerUid).toList()));
    return _discountStreamController.stream;
  }

  static Future<String?> saveDiscountCode(DiscountCode code) async {
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance
            .collection('discount_codes').doc(code.id).set(code.toMap());
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      final idx = _mockDiscountCodes.indexWhere((d) => d.id == code.id);
      if (idx == -1) { _mockDiscountCodes.add(code); } else { _mockDiscountCodes[idx] = code; }
      _discountStreamController.add(List.from(_mockDiscountCodes));
      return null;
    }
  }

  static Future<String?> deleteDiscountCode(String id) async {
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance.collection('discount_codes').doc(id).delete();
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      _mockDiscountCodes.removeWhere((d) => d.id == id);
      _discountStreamController.add(List.from(_mockDiscountCodes));
      return null;
    }
  }

  /// Validate a discount code and return DiscountCode if valid, null otherwise
  static Future<DiscountCode?> validateDiscountCode(String code, double cartTotal) async {
    if (!useDemoMode) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('discount_codes')
            .where('code', isEqualTo: code.toUpperCase())
            .limit(1)
            .get();
        if (snap.docs.isEmpty) return null;
        final dc = DiscountCode.fromMap(snap.docs.first.data());
        if (!dc.isValid || cartTotal < dc.minimumOrderAmount) return null;
        return dc;
      } catch (_) {
        return null;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
      try {
        return _mockDiscountCodes.firstWhere(
          (d) => d.code == code.toUpperCase() && d.isValid && cartTotal >= d.minimumOrderAmount,
        );
      } catch (_) {
        return null;
      }
    }
  }

  // ─────────────────────────────────────────
  // NEARBY RESTAURANTS (text-based matching)
  // ─────────────────────────────────────────
  static List<UserModel> getNearbyRestaurants(String userAddress) {
    if (userAddress.trim().isEmpty) return [];
    // Extract keywords (split by comma/space, filter short words)
    final keywords = userAddress
        .toLowerCase()
        .split(RegExp(r'[,\s]+'))
        .where((w) => w.length >= 3)
        .toList();

    final restaurants = _mockUsers.where((u) => u.role == 'restaurant_owner').toList();
    return restaurants.where((r) {
      final haystack = '${r.restaurantAddress} ${r.restaurantName}'.toLowerCase();
      return keywords.any((kw) => haystack.contains(kw));
    }).toList();
  }

  // ─────────────────────────────────────────
  // DYNAMIC CATEGORIES MANAGEMENT
  // ─────────────────────────────────────────
  static final StreamController<List<String>> _categoryStreamController =
      StreamController<List<String>>.broadcast();
  static final List<String> _mockCategories = ["Çorba", "Ana Yemek", "Tatlı", "İçecek"];

  static Stream<List<String>> streamCategories() {
    if (!useDemoMode) {
      return FirebaseFirestore.instance
          .collection('categories')
          .snapshots()
          .map((s) => s.docs.map((d) => d.id).toList());
    }
    Future.microtask(() {
      if (!_categoryStreamController.isClosed) {
        _categoryStreamController.add(List.from(_mockCategories));
      }
    });
    return _categoryStreamController.stream;
  }

  static Future<String?> addCategory(String categoryName) async {
    final name = categoryName.trim();
    if (name.isEmpty) return "Kategori adı boş olamaz";
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance.collection('categories').doc(name).set({});
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      if (!_mockCategories.contains(name)) {
        _mockCategories.add(name);
        _categoryStreamController.add(List.from(_mockCategories));
      }
      return null;
    }
  }

  static Future<String?> deleteCategory(String categoryName) async {
    if (!useDemoMode) {
      try {
        await FirebaseFirestore.instance.collection('categories').doc(categoryName).delete();
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      _mockCategories.remove(categoryName);
      _categoryStreamController.add(List.from(_mockCategories));
      return null;
    }
  }

  // ─────────────────────────────────────────
  // LIVE SUPPORT CHAT
  // ─────────────────────────────────────────
  static final StreamController<List<ChatSession>> _chatSessionsController =
      StreamController<List<ChatSession>>.broadcast();
  static final Map<String, StreamController<ChatSession>> _chatRoomControllers = {};

  static final List<ChatSession> _mockChatSessions = [];

  /// Customer: open a new support session (or return existing open one)
  static Future<ChatSession?> startChatSession() async {
    final user = currentUser;
    if (user == null) return null;

    if (!useDemoMode) {
      try {
        // Check if customer already has a non-closed session
        final existing = await FirebaseFirestore.instance
            .collection('support_chats')
            .where('customerId', isEqualTo: user.uid)
            .where('status', whereIn: ['waiting', 'active'])
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          return ChatSession.fromMap(existing.docs.first.data());
        }
        final id = 'chat_${DateTime.now().millisecondsSinceEpoch}';
        final session = ChatSession(
          id: id,
          customerId: user.uid,
          customerName: user.fullName,
          status: 'waiting',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await FirebaseFirestore.instance
            .collection('support_chats').doc(id).set(session.toMap());
        return session;
      } catch (_) {
        return null;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 600));
      // Return existing open session if any
      final existing = _mockChatSessions.firstWhere(
        (s) => s.customerId == user.uid && (s.isWaiting || s.isActive),
        orElse: () => ChatSession(id: '', customerId: '', customerName: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );
      if (existing.id.isNotEmpty) return existing;

      final session = ChatSession(
        id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
        customerId: user.uid,
        customerName: user.fullName,
        status: 'waiting',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _mockChatSessions.add(session);
      _chatSessionsController.add(List.from(_mockChatSessions));
      return session;
    }
  }

  /// Agent: stream of all support sessions
  static Stream<List<ChatSession>> streamChatSessions() {
    if (!useDemoMode) {
      return FirebaseFirestore.instance
          .collection('support_chats')
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map((d) => ChatSession.fromMap(d.data())).toList());
    }
    Future.microtask(() => _chatSessionsController.add(List.from(_mockChatSessions)));
    return _chatSessionsController.stream;
  }

  /// Customer: stream their own session
  static Stream<ChatSession?> streamMySession(String sessionId) {
    if (!useDemoMode) {
      return FirebaseFirestore.instance
          .collection('support_chats').doc(sessionId)
          .snapshots()
          .map((d) => d.exists ? ChatSession.fromMap(d.data()!) : null);
    }
    _chatRoomControllers.putIfAbsent(sessionId, () => StreamController<ChatSession>.broadcast());
    // Emit current state
    Future.microtask(() {
      final s = _mockChatSessions.firstWhere((x) => x.id == sessionId,
          orElse: () => ChatSession(id: '', customerId: '', customerName: '', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      if (s.id.isNotEmpty) _chatRoomControllers[sessionId]?.add(s);
    });
    return _chatRoomControllers[sessionId]!.stream;
  }

  /// Agent: claim a waiting session (lock it — returns error if already claimed)
  static Future<String?> claimChatSession(String sessionId) async {
    final agent = currentUser;
    if (agent == null) return "Oturum açık değil.";

    if (!useDemoMode) {
      try {
        final ref = FirebaseFirestore.instance.collection('support_chats').doc(sessionId);
        return await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(ref);
          if (!snap.exists) return "Oturum bulunamadı.";
          final data = snap.data()!;
          if (data['status'] != 'waiting') return "Bu oturum zaten başka bir yetkili tarafından alındı.";
          tx.update(ref, {
            'assignedAgentId': agent.uid,
            'assignedAgentName': agent.fullName,
            'status': 'active',
            'updatedAt': DateTime.now().toIso8601String(),
          });
          return null;
        });
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      final idx = _mockChatSessions.indexWhere((s) => s.id == sessionId);
      if (idx == -1) return "Oturum bulunamadı.";
      final session = _mockChatSessions[idx];
      if (session.status != 'waiting') return "Bu oturum zaten ${session.assignedAgentName ?? 'başka bir yetkili'} tarafından alındı.";
      session.assignedAgentId = agent.uid;
      session.assignedAgentName = agent.fullName;
      session.status = 'active';
      session.updatedAt = DateTime.now();
      _chatSessionsController.add(List.from(_mockChatSessions));
      _chatRoomControllers[sessionId]?.add(session);
      return null;
    }
  }

  /// Send a chat message
  static Future<String?> sendChatMessage(String sessionId, String text) async {
    final user = currentUser;
    if (user == null) return "Oturum açık değil.";

    final msg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: user.uid,
      senderName: user.fullName,
      isFromCustomer: user.role == 'customer',
      text: text,
      timestamp: DateTime.now(),
    );

    if (!useDemoMode) {
      try {
        final ref = FirebaseFirestore.instance.collection('support_chats').doc(sessionId);
        await ref.update({
          'messages': FieldValue.arrayUnion([msg.toMap()]),
          'lastMessage': text,
          'updatedAt': DateTime.now().toIso8601String(),
        });
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 100));
      final idx = _mockChatSessions.indexWhere((s) => s.id == sessionId);
      if (idx == -1) return "Oturum bulunamadı.";
      _mockChatSessions[idx].messages = [..._mockChatSessions[idx].messages, msg];
      _mockChatSessions[idx].lastMessage = text;
      _mockChatSessions[idx].updatedAt = DateTime.now();
      _chatSessionsController.add(List.from(_mockChatSessions));
      _chatRoomControllers[sessionId]?.add(_mockChatSessions[idx]);
      return null;
    }
  }

  /// Close/end a chat session
  static Future<void> closeChatSession(String sessionId) async {
    if (!useDemoMode) {
      await FirebaseFirestore.instance.collection('support_chats').doc(sessionId).update({
        'status': 'closed',
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } else {
      final idx = _mockChatSessions.indexWhere((s) => s.id == sessionId);
      if (idx != -1) {
        _mockChatSessions[idx].status = 'closed';
        _chatSessionsController.add(List.from(_mockChatSessions));
        _chatRoomControllers[sessionId]?.add(_mockChatSessions[idx]);
      }
    }
  }
}

