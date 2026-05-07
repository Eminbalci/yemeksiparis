class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String role; // 'customer', 'restaurant_owner', or 'admin'
  final String status;
  final DateTime createdAt;

  // Customer delivery info
  final String phone;
  final String address;
  final String selectedAddressId;

  // Restaurant location info
  final String restaurantName;
  final String restaurantAddress;
  final double minOrderAmount;
  final String restaurantLogo;
  final String restaurantDescription;
  final double maxDeliveryDistance; // in kilometers (km)

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    this.status = 'active',
    required this.createdAt,
    this.phone = '',
    this.address = '',
    this.selectedAddressId = '',
    this.restaurantName = '',
    this.restaurantAddress = '',
    this.minOrderAmount = 0.0,
    this.restaurantLogo = '',
    this.restaurantDescription = '',
    this.maxDeliveryDistance = 5.0, // Default 5.0 km
  });

  UserModel copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? selectedAddressId,
    String? restaurantName,
    String? restaurantAddress,
    double? minOrderAmount,
    String? restaurantLogo,
    String? restaurantDescription,
    double? maxDeliveryDistance,
    String? role,
    String? status,
  }) {
    return UserModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      selectedAddressId: selectedAddressId ?? this.selectedAddressId,
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantAddress: restaurantAddress ?? this.restaurantAddress,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      restaurantLogo: restaurantLogo ?? this.restaurantLogo,
      restaurantDescription: restaurantDescription ?? this.restaurantDescription,
      maxDeliveryDistance: maxDeliveryDistance ?? this.maxDeliveryDistance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'role': role,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'phone': phone,
      'address': address,
      'selectedAddressId': selectedAddressId,
      'restaurantName': restaurantName,
      'restaurantAddress': restaurantAddress,
      'minOrderAmount': minOrderAmount,
      'restaurantLogo': restaurantLogo,
      'restaurantDescription': restaurantDescription,
      'maxDeliveryDistance': maxDeliveryDistance,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'customer',
      status: map['status'] ?? 'active',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      selectedAddressId: map['selectedAddressId'] ?? '',
      restaurantName: map['restaurantName'] ?? '',
      restaurantAddress: map['restaurantAddress'] ?? '',
      minOrderAmount: (map['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
      restaurantLogo: map['restaurantLogo'] ?? '',
      restaurantDescription: map['restaurantDescription'] ?? '',
      maxDeliveryDistance: (map['maxDeliveryDistance'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

class FoodItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final double rating;
  final int stock;
  final String restaurantOwnerId; // which restaurant owns this item

  FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.rating,
    this.stock = 99,
    this.restaurantOwnerId = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'rating': rating,
      'stock': stock,
      'restaurantOwnerId': restaurantOwnerId,
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 4.5,
      stock: map['stock'] ?? 99,
      restaurantOwnerId: map['restaurantOwnerId'] ?? '',
    );
  }
}

class OrderItem {
  final FoodItem foodItem;
  final int quantity;

  OrderItem({required this.foodItem, required this.quantity});

  Map<String, dynamic> toMap() {
    return {
      'foodItem': foodItem.toMap(),
      'quantity': quantity,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      foodItem: FoodItem.fromMap(map['foodItem']),
      quantity: map['quantity'] ?? 1,
    );
  }
}

class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final List<OrderItem> items;
  final double totalAmount;
  String status; // 'pending', 'preparing', 'on_the_way', 'delivered', 'ready_for_pickup'
  final DateTime createdAt;
  final bool isTakeaway;
  int? rating; // 1 to 5 stars rating given by customer after delivery
  final String? note; // Optional order note for delivery instructions

  OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.isTakeaway = false,
    this.rating,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'items': items.map((x) => x.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'isTakeaway': isTakeaway,
      'rating': rating,
      'note': note,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      items: List<OrderItem>.from(
        (map['items'] as List).map((x) => OrderItem.fromMap(Map<String, dynamic>.from(x))),
      ),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      isTakeaway: map['isTakeaway'] ?? false,
      rating: map['rating'] as int?,
      note: map['note'] as String?,
    );
  }
}

// --- Customer Delivery Address Model ---
class DeliveryAddress {
  final String id;
  final String title;       // e.g. 'Ev', 'İş', 'Diğer'
  final String fullAddress;
  final String phone;

  DeliveryAddress({
    required this.id,
    required this.title,
    required this.fullAddress,
    required this.phone,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'fullAddress': fullAddress,
    'phone': phone,
  };

  factory DeliveryAddress.fromMap(Map<String, dynamic> map) => DeliveryAddress(
    id: map['id'] ?? '',
    title: map['title'] ?? 'Diğer',
    fullAddress: map['fullAddress'] ?? '',
    phone: map['phone'] ?? '',
  );
}

// --- Restaurant Branch Model ---
class RestaurantBranch {
  final String id;
  final String name;        // Branch display name, e.g. 'Merkez Şube', 'Kadıköy Şubesi'
  final String address;
  final String phone;
  final bool isActive;

  RestaurantBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'phone': phone,
    'isActive': isActive,
  };

  factory RestaurantBranch.fromMap(Map<String, dynamic> map) => RestaurantBranch(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    address: map['address'] ?? '',
    phone: map['phone'] ?? '',
    isActive: map['isActive'] ?? true,
  );
}

// --- Discount Code Model ---
enum DiscountType { percentage, flatAmount }

class DiscountCode {
  final String id;
  final String code;                     // e.g. 'YEMEK20'
  final DiscountType type;               // percentage or flatAmount
  final double value;                    // 20.0 => 20% or 20 TL
  final String restaurantOwnerId;
  final String? branchId;               // null = all branches
  final String branchName;
  final double minimumOrderAmount;       // 0 = no minimum
  final bool stackable;                  // can it be combined with other codes?
  final int maxUses;                     // 0 = unlimited
  int currentUses;
  final DateTime? expiresAt;
  final bool isActive;

  DiscountCode({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.restaurantOwnerId,
    this.branchId,
    this.branchName = 'Tüm Şubeler',
    this.minimumOrderAmount = 0,
    this.stackable = false,
    this.maxUses = 0,
    this.currentUses = 0,
    this.expiresAt,
    this.isActive = true,
  });

  DiscountCode copyWith({
    String? id,
    String? code,
    DiscountType? type,
    double? value,
    String? restaurantOwnerId,
    String? branchId,
    String? branchName,
    double? minimumOrderAmount,
    bool? stackable,
    int? maxUses,
    int? currentUses,
    DateTime? expiresAt,
    bool? isActive,
  }) {
    return DiscountCode(
      id: id ?? this.id,
      code: code ?? this.code,
      type: type ?? this.type,
      value: value ?? this.value,
      restaurantOwnerId: restaurantOwnerId ?? this.restaurantOwnerId,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      minimumOrderAmount: minimumOrderAmount ?? this.minimumOrderAmount,
      stackable: stackable ?? this.stackable,
      maxUses: maxUses ?? this.maxUses,
      currentUses: currentUses ?? this.currentUses,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isValid {
    if (!isActive) return false;
    if (maxUses > 0 && currentUses >= maxUses) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  /// Calculates actual discount amount for a given cart total
  double calculateDiscount(double cartTotal) {
    if (cartTotal < minimumOrderAmount) return 0;
    if (type == DiscountType.percentage) {
      return cartTotal * (value / 100);
    } else {
      return value.clamp(0, cartTotal);
    }
  }

  String get typeLabel => type == DiscountType.percentage ? '%${value.toStringAsFixed(0)}' : '${value.toStringAsFixed(0)} TL';

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'type': type.name,
    'value': value,
    'restaurantOwnerId': restaurantOwnerId,
    'branchId': branchId,
    'branchName': branchName,
    'minimumOrderAmount': minimumOrderAmount,
    'stackable': stackable,
    'maxUses': maxUses,
    'currentUses': currentUses,
    'expiresAt': expiresAt?.toIso8601String(),
    'isActive': isActive,
  };

  factory DiscountCode.fromMap(Map<String, dynamic> map) => DiscountCode(
    id: map['id'] ?? '',
    code: (map['code'] ?? '').toString().toUpperCase(),
    type: map['type'] == 'flatAmount' ? DiscountType.flatAmount : DiscountType.percentage,
    value: (map['value'] as num?)?.toDouble() ?? 0.0,
    restaurantOwnerId: map['restaurantOwnerId'] ?? '',
    branchId: map['branchId'],
    branchName: map['branchName'] ?? 'Tüm Şubeler',
    minimumOrderAmount: (map['minimumOrderAmount'] as num?)?.toDouble() ?? 0.0,
    stackable: map['stackable'] ?? false,
    maxUses: map['maxUses'] ?? 0,
    currentUses: map['currentUses'] ?? 0,
    expiresAt: map['expiresAt'] != null ? DateTime.parse(map['expiresAt']) : null,
    isActive: map['isActive'] ?? true,
  );
}

// --- Live Support Chat Models ---

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final bool isFromCustomer;
  final String text;
  final String imageUrl;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.isFromCustomer,
    required this.text,
    this.imageUrl = '',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'isFromCustomer': isFromCustomer,
    'text': text,
    'imageUrl': imageUrl,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] ?? '',
    senderId: map['senderId'] ?? '',
    senderName: map['senderName'] ?? '',
    isFromCustomer: map['isFromCustomer'] ?? true,
    text: map['text'] ?? '',
    imageUrl: map['imageUrl'] ?? '',
    timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
  );
}

class ChatSession {
  final String id;
  final String customerId;
  final String customerName;
  String? assignedAgentId;    // null = waiting, set = agent locked in
  String? assignedAgentName;
  String status;              // 'waiting' | 'active' | 'closed'
  final DateTime createdAt;
  DateTime updatedAt;
  String lastMessage;
  List<ChatMessage> messages;
  String? orderId;            // The order associated with this support request
  int? rating;                // Rating (1-5 stars) given to this support session by the customer

  ChatSession({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.assignedAgentId,
    this.assignedAgentName,
    this.status = 'waiting',
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage = '',
    this.messages = const [],
    this.orderId,
    this.rating,
  });

  bool get isWaiting => status == 'waiting';
  bool get isActive => status == 'active';
  bool get isClosed => status == 'closed';

  Map<String, dynamic> toMap() => {
    'id': id,
    'customerId': customerId,
    'customerName': customerName,
    'assignedAgentId': assignedAgentId,
    'assignedAgentName': assignedAgentName,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastMessage': lastMessage,
    'messages': messages.map((m) => m.toMap()).toList(),
    'orderId': orderId,
    'rating': rating,
  };

  factory ChatSession.fromMap(Map<String, dynamic> map) => ChatSession(
    id: map['id'] ?? '',
    customerId: map['customerId'] ?? '',
    customerName: map['customerName'] ?? '',
    assignedAgentId: map['assignedAgentId'],
    assignedAgentName: map['assignedAgentName'],
    status: map['status'] ?? 'waiting',
    createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    lastMessage: map['lastMessage'] ?? '',
    messages: map['messages'] != null
        ? List<ChatMessage>.from(
            (map['messages'] as List).map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m))),
          )
        : [],
    orderId: map['orderId'],
    rating: map['rating'] as int?,
  );
}

// --- Branch Invitation Model ---
class BranchInvitation {
  final String id;
  final String restaurantOwnerId;
  final String restaurantName;
  final String inviteeEmail;
  final String inviteeUid;
  String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;

  BranchInvitation({
    required this.id,
    required this.restaurantOwnerId,
    required this.restaurantName,
    required this.inviteeEmail,
    required this.inviteeUid,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'restaurantOwnerId': restaurantOwnerId,
    'restaurantName': restaurantName,
    'inviteeEmail': inviteeEmail,
    'inviteeUid': inviteeUid,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BranchInvitation.fromMap(Map<String, dynamic> map) => BranchInvitation(
    id: map['id'] ?? '',
    restaurantOwnerId: map['restaurantOwnerId'] ?? '',
    restaurantName: map['restaurantName'] ?? '',
    inviteeEmail: map['inviteeEmail'] ?? '',
    inviteeUid: map['inviteeUid'] ?? '',
    status: map['status'] ?? 'pending',
    createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
  );
}



