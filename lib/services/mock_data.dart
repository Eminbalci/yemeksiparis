import '../models/models.dart';

class MockData {
  static List<UserModel> getInitialUsers() {
    return [
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
        minOrderAmount: 0.0,
        maxDeliveryDistance: 5.0,
      ),
      UserModel(
        uid: 'demo_support_1',
        fullName: 'Ahmet Destek Yetkilisi',
        email: 'destek@yemek.com',
        role: 'support',
        status: 'active',
        createdAt: DateTime.now(),
        phone: '0533 999 88 77',
      ),
    ];
  }

  static Map<String, List<DeliveryAddress>> getInitialAddresses() {
    return {
      'demo_customer_1': [
        DeliveryAddress(
          id: 'addr_1',
          title: 'Ev',
          fullAddress: 'Moda Caddesi No:15 Daire:3, Kadıköy, İstanbul',
          phone: '0532 111 22 33',
        ),
      ],
    };
  }

  static Map<String, List<RestaurantBranch>> getInitialBranches() {
    return {
      'demo_restaurant_1': [
        RestaurantBranch(
          id: 'branch_1',
          name: 'Merkez Şube',
          address: 'Bahariye Caddesi No:42, Kadıköy, İstanbul',
          phone: '0216 555 44 33',
          isActive: true,
          restaurantOwnerId: 'demo_restaurant_1',
        ),
      ],
    };
  }

  static List<FoodItem> getInitialFoodItems() {
    return [
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
  }

  static List<OrderModel> getInitialOrders() {
    return [
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
        note: 'Lütfen kebapların sosu bol olsun, ayranlar soğuk gelsin.',
      ),
    ];
  }

  static List<DiscountCode> getInitialDiscountCodes() {
    return [
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
  }

  static List<ChatSession> getInitialChatSessions() {
    return [];
  }
}
