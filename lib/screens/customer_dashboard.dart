import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/location_api_service.dart';
import 'login_screen.dart';
import 'restaurant_dashboard.dart';
import 'live_support_screen.dart';
import 'restaurant_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';

class CartManager {
  static final Map<String, OrderItem> cart = {};

  static double get total {
    double sum = 0;
    cart.forEach((_, item) => sum += item.foodItem.price * item.quantity);
    return sum;
  }

  static int get itemCount {
    int count = 0;
    cart.forEach((_, item) => count += item.quantity);
    return count;
  }

  static void clear() {
    cart.clear();
  }
}

class CustomerDashboard extends StatefulWidget {
  final bool showCart;
  final int initialTab;
  const CustomerDashboard({super.key, this.showCart = false, this.initialTab = 0});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  late int _currentTab; // 0: Menu, 1: Orders
  String _searchQuery = "";
  String _selectedCategory = "Hepsi";

  TextEditingController? _phoneController;
  TextEditingController? _addressController;

  StreamSubscription<List<OrderModel>>? _ordersSubscription;
  StreamSubscription<String>? _geocodeCompletedSubscription;
  final Map<String, String> _lastStatuses = {};

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _ordersSubscription = FirebaseService.streamOrders().listen((orders) {
      final customerId = FirebaseService.currentUser?.uid;
      if (customerId == null) return;

      for (var order in orders) {
        if (order.customerId == customerId) {
          final prevStatus = _lastStatuses[order.id];
          if (prevStatus != null && prevStatus != order.status) {
            // Status updated! Trigger custom overlay notification!
            _showTopNotification(order);
          }
          _lastStatuses[order.id] = order.status;
        }
      }
    });

    _geocodeCompletedSubscription = FirebaseService.geocodeCompletedStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    if (widget.showCart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCartSheet();
      });
    }
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {});
    }
  }

  void _showTopNotification(OrderModel order) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    String statusTitle = "Sipariş Güncellemesi";
    String statusDesc = "Siparişinizin durumu güncellendi.";
    IconData icon = Icons.notifications_active;
    Color color = const Color(0xFFFF9F43);

    switch (order.status) {
      case 'pending':
        statusTitle = "Sipariş Alındı";
        statusDesc = "Siparişiniz restoran tarafından onay bekliyor.";
        icon = Icons.hourglass_empty;
        color = Colors.white54;
        break;
      case 'preparing':
        statusTitle = "Sipariş Hazırlanıyor 🍳";
        statusDesc = "Leziz siparişiniz sevgiyle hazırlanıyor!";
        icon = Icons.restaurant;
        color = const Color(0xFFFF9F43);
        break;
      case 'on_the_way':
        statusTitle = "Sipariş Yolda! 🛵";
        statusDesc = "Siparişiniz kuryemizle kapınıza doğru yola çıktı.";
        icon = Icons.delivery_dining;
        color = const Color(0xFF10B981);
        break;
      case 'ready_for_pickup':
        statusTitle = "Sipariş Hazır! 🛍️";
        statusDesc = "Gel-Al siparişiniz hazır! İstediğiniz zaman teslim alabilirsiniz.";
        icon = Icons.shopping_bag;
        color = const Color(0xFF10B981);
        break;
      case 'delivered':
        statusTitle = "Sipariş Teslim Edildi 🎉";
        statusDesc = "Afiyet olsun! Siparişiniz başarıyla teslim edildi.";
        icon = Icons.check_circle;
        color = const Color(0xFF10B981);
        break;
    }

    // Trigger system background native local notification!
    NotificationService.showLocalNotification(
      id: order.id.hashCode,
      title: statusTitle,
      body: statusDesc,
      payload: 'orders',
    ).catchError((e) => debugPrint('Local notification error: $e'));

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: _AnimatedNotificationToast(
              title: statusTitle,
              desc: statusDesc,
              icon: icon,
              color: color,
              onDismiss: () {
                overlayEntry.remove();
              },
            ),
          ),
        );
      },
    );

    overlayState.insert(overlayEntry);
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _geocodeCompletedSubscription?.cancel();
    _phoneController?.dispose();
    _addressController?.dispose();
    super.dispose();
  }

  // Shopping Cart state mapped to CartManager (persists across screen switches)
  Map<String, OrderItem> get _cart => CartManager.cart;
  double get _cartTotal => CartManager.total;
  int get _cartItemCount => CartManager.itemCount;

  Future<bool> _checkCartRestaurantConstraint(FoodItem item) async {
    if (_cart.isEmpty) return true;
    final firstItem = _cart.values.first;
    if (firstItem.foodItem.restaurantOwnerId == item.restaurantOwnerId) {
      return true;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Farklı Restoran Seçimi ⚠️",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        content: Text(
          "Sepetinizde zaten başka bir restorandan ürünler bulunuyor. Yeni restorandan ürün eklemek için mevcut sepetinizi boşaltmak ister misiniz?",
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("İptal", style: GoogleFonts.outfit(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Sepeti Boşalt", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _cart.clear();
      });
      return true;
    }
    return false;
  }

  void _addToCart(FoodItem item) async {
    final canAdd = await _checkCartRestaurantConstraint(item);
    if (!canAdd) return;

    setState(() {
      if (_cart.containsKey(item.id)) {
        _cart[item.id] = OrderItem(
          foodItem: item,
          quantity: _cart[item.id]!.quantity + 1,
        );
      } else {
        _cart[item.id] = OrderItem(foodItem: item, quantity: 1);
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "${item.name} sepete eklendi!",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _updateCartQuantity(String itemId, int change) {
    setState(() {
      if (_cart.containsKey(itemId)) {
        final newQty = _cart[itemId]!.quantity + change;
        if (newQty <= 0) {
          _cart.remove(itemId);
        } else {
          _cart[itemId] = OrderItem(
            foodItem: _cart[itemId]!.foodItem,
            quantity: newQty,
          );
        }
      }
    });
  }

  // Handle Sign Out
  Future<void> _handleSignOut() async {
    CartManager.clear();
    await FirebaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // Show sliding shopping cart modal
  void _showCartSheet() {
    DiscountCode? appliedDiscount;
    String discountError = "";
    final TextEditingController couponController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    final Future<UserModel?>? restFuture = _cart.isNotEmpty
        ? FirebaseService.getUserById(_cart.values.first.foodItem.restaurantOwnerId)
        : null;
    bool isTakeawaySelected = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final user = FirebaseService.currentUser;
            final double subtotal = _cartTotal;
            double discountAmount = 0.0;
            if (appliedDiscount != null) {
              discountAmount = appliedDiscount!.calculateDiscount(subtotal);
            }
            final double finalSubtotal = (subtotal - discountAmount) < 0 ? 0 : (subtotal - discountAmount);
            final double deliveryFee = isTakeawaySelected
                ? 0.0
                : (finalSubtotal > 200 || finalSubtotal == 0 ? 0 : 30);
            final double total = finalSubtotal + deliveryFee;

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pull indicator
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined, color: Theme.of(context).primaryColor, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        "Sepetim",
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        "$_cartItemCount Ürün",
                        style: GoogleFonts.outfit(color: Colors.white54, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),
                  Expanded(
                    child: _cart.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.white24),
                                const SizedBox(height: 16),
                                Text(
                                  "Sepetiniz henüz boş.",
                                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Cart items list
                                ..._cart.values.map((item) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      children: [
                                        // Leading food thumbnail image
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            item.foodItem.imageUrl,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => Container(
                                              color: Colors.white10,
                                              width: 60,
                                              height: 60,
                                              child: const Icon(Icons.fastfood, color: Colors.white30),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Name and subtotal
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.foodItem.name,
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "${item.foodItem.price.toStringAsFixed(0)} TL",
                                                style: GoogleFonts.outfit(color: Theme.of(context).primaryColor, fontSize: 14, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Quantity increment/decrement buttons
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                                                onPressed: () {
                                                  _updateCartQuantity(item.foodItem.id, -1);
                                                  setModalState(() {});
                                                  setState(() {});
                                                },
                                              ),
                                              Text(
                                                "${item.quantity}",
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                                                onPressed: () {
                                                  _updateCartQuantity(item.foodItem.id, 1);
                                                  setModalState(() {});
                                                  setState(() {});
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                const Divider(color: Colors.white12, height: 24),

                                // Discount Code Input
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 42,
                                        child: TextField(
                                          controller: couponController,
                                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                                          decoration: InputDecoration(
                                            hintText: "İndirim Kodu Girin",
                                            hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                                            filled: true,
                                            fillColor: Colors.white.withValues(alpha: 0.04),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final code = couponController.text.trim();
                                        if (code.isEmpty) return;
                                        final dc = await FirebaseService.validateDiscountCode(code, subtotal);
                                        setModalState(() {
                                          if (dc != null) {
                                            appliedDiscount = dc;
                                            discountError = "";
                                          } else {
                                            discountError = "Geçersiz kod veya alt limite ulaşılmadı.";
                                          }
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(80, 42),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: Text("Uygula", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                if (discountError.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4, left: 4),
                                    child: Text(discountError, style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 11)),
                                  ),
                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Ara Toplam", style: GoogleFonts.outfit(color: Colors.white60)),
                                    Text("${subtotal.toStringAsFixed(0)} TL", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                if (appliedDiscount != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.tag, color: Colors.greenAccent, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            "İndirim (${appliedDiscount!.code})",
                                            style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.w500),
                                          ),
                                          IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.only(left: 4),
                                            icon: const Icon(Icons.cancel, color: Colors.white30, size: 16),
                                            onPressed: () {
                                              setModalState(() {
                                                appliedDiscount = null;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "-${discountAmount.toStringAsFixed(0)} TL",
                                        style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Gönderim Ücreti", style: GoogleFonts.outfit(color: Colors.white60)),
                                    Text(
                                      deliveryFee == 0 ? "Bedava" : "${deliveryFee.toStringAsFixed(0)} TL",
                                      style: GoogleFonts.outfit(
                                        color: deliveryFee == 0 ? Colors.greenAccent : Colors.white,
                                        fontWeight: deliveryFee == 0 ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (subtotal < 200) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    "Kampanya: 200 TL üzeri kargo bedava! (Eksik: ${(200 - subtotal).toStringAsFixed(0)} TL)",
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.secondary, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                const Divider(color: Colors.white12),
                                const SizedBox(height: 12),

                                // Delivery Method Selection Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            isTakeawaySelected = false;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: !isTakeawaySelected 
                                                ? Theme.of(context).primaryColor.withValues(alpha: 0.15) 
                                                : Colors.white.withValues(alpha: 0.02),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: !isTakeawaySelected 
                                                  ? Theme.of(context).primaryColor 
                                                  : Colors.white.withValues(alpha: 0.08),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.delivery_dining_rounded, 
                                                color: !isTakeawaySelected ? Theme.of(context).primaryColor : Colors.white54, 
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                "Adrese Teslimat",
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: !isTakeawaySelected ? Colors.white : Colors.white54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            isTakeawaySelected = true;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isTakeawaySelected 
                                                ? Theme.of(context).primaryColor.withValues(alpha: 0.15) 
                                                : Colors.white.withValues(alpha: 0.02),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isTakeawaySelected 
                                                  ? Theme.of(context).primaryColor 
                                                  : Colors.white.withValues(alpha: 0.08),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.shopping_bag_rounded, 
                                                color: isTakeawaySelected ? Theme.of(context).primaryColor : Colors.white54, 
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                "Gel-Al (Pick-up)",
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isTakeawaySelected ? Colors.white : Colors.white54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Conditionally show Address Picker or Takeaway Instructions
                                if (isTakeawaySelected)
                                  FutureBuilder<UserModel?>(
                                    future: restFuture,
                                    builder: (context, restSnap) {
                                      final restUser = restSnap.data;
                                      final restName = restUser?.restaurantName.isNotEmpty == true ? restUser!.restaurantName : "Restoran Merkez Şubesi";
                                      final restAddr = restUser?.restaurantAddress.isNotEmpty == true ? restUser!.restaurantAddress : "Restoran Şubesi";

                                      return Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.15)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.storefront_rounded, color: Theme.of(context).primaryColor, size: 18),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Gel-Al Teslim Noktası",
                                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              restName,
                                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              restAddr,
                                              style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              "💡 Siparişiniz hazırlandığında bilgilendirileceksiniz. Lütfen restoranımıza gelerek sıcak sıcak teslim alınız.",
                                              style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38, fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  )
                                else
                                  // Delivery Address Selection Section inside Cart
                                  StreamBuilder<List<DeliveryAddress>>(
                                    stream: FirebaseService.streamAddresses(user?.uid ?? ''),
                                    builder: (context, addrSnapshot) {
                                      final addresses = addrSnapshot.data ?? [];
                                      final hasSelected = user?.address.isNotEmpty == true;
                                      
                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.02),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: hasSelected 
                                                ? Theme.of(context).primaryColor.withValues(alpha: 0.2) 
                                                : Colors.redAccent.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on_rounded, 
                                                  color: hasSelected ? Theme.of(context).primaryColor : Colors.redAccent, 
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Teslimat Adresi",
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12, 
                                                    fontWeight: FontWeight.bold, 
                                                    color: hasSelected ? Colors.white : Colors.redAccent,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (addresses.isNotEmpty)
                                                  PopupMenuButton<DeliveryAddress>(
                                                    icon: Icon(Icons.swap_horiz_rounded, color: Theme.of(context).primaryColor, size: 18),
                                                    tooltip: "Adresi Değiştir",
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    onSelected: (addr) async {
                                                      if (user != null) await FirebaseService.selectAddress(user.uid, addr.id, addr.fullAddress, addr.phone);
                                                      setModalState(() {});
                                                      setState(() {});
                                                    },
                                                    itemBuilder: (context) {
                                                      return addresses.map((addr) {
                                                        return PopupMenuItem<DeliveryAddress>(
                                                          value: addr,
                                                          child: Text(
                                                            "${addr.title}: ${addr.fullAddress}",
                                                            style: GoogleFonts.outfit(fontSize: 12),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        );
                                                      }).toList();
                                                    },
                                                  )
                                                else
                                                  GestureDetector(
                                                    onTap: () {
                                                      Navigator.pop(context); // close cart
                                                      setState(() {
                                                        _currentTab = 2; // Swap to profile
                                                      });
                                                    },
                                                    child: Text(
                                                      "+ Adres Ekle",
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 12, 
                                                        fontWeight: FontWeight.bold, 
                                                        color: Theme.of(context).primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              hasSelected 
                                                  ? (user?.address ?? '') 
                                                  : "Lütfen sipariş için bir teslimat adresi belirleyin.",
                                              style: GoogleFonts.outfit(
                                                fontSize: 11, 
                                                color: hasSelected ? Colors.white60 : Colors.redAccent.withValues(alpha: 0.8),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                const SizedBox(height: 12),
                                const Divider(color: Colors.white12),
                                const SizedBox(height: 12),

                                // Premium Custom Order Note Input Field
                                TextField(
                                  controller: noteController,
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.02),
                                    hintText: "Sipariş Notu Ekle (örn. Kapıyı çalmayın)",
                                    hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                                    prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.white38, size: 18),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.03)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),

                  // Pinned bottom bar actions
                  if (_cart.isNotEmpty) ...[
                    const Divider(color: Colors.white12, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Toplam Tutar", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(
                          "${total.toStringAsFixed(0)} TL",
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).primaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Pre-fetch restaurant limits validation inside FutureBuilder
                    FutureBuilder<UserModel?>(
                      future: restFuture,
                      builder: (context, snapshot) {
                        final restUser = snapshot.data;
                        final bool underMin = restUser != null && restUser.minOrderAmount > 0 && total < restUser.minOrderAmount;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (underMin) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Minimum sipariş tutarı ${restUser.minOrderAmount.toStringAsFixed(0)} TL'dir. Sipariş için sepetinize ${(restUser.minOrderAmount - total).toStringAsFixed(0)} TL değerinde daha ürün eklemelisiniz.",
                                        style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            ElevatedButton(
                              onPressed: () async {
                                if (underMin) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Minimum sipariş tutarı ${restUser.minOrderAmount.toStringAsFixed(0)} TL'dir.",
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }

                                final u = FirebaseService.currentUser;
                                // Only require address verification if NOT doing takeaway/pickup!
                                if (!isTakeawaySelected && (u == null || u.address.isEmpty)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Lütfen sipariş vermeden önce geçerli bir teslimat adresi seçin.", 
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }

                                Navigator.of(context).pop(); // Close bottom sheet
                                _placeCustomerOrder(total, isTakeaway: isTakeawaySelected, note: noteController.text.trim());
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: underMin ? Colors.white12 : Theme.of(context).primaryColor,
                                foregroundColor: underMin ? Colors.white30 : Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(underMin 
                                      ? "Minimum Tutara Ulaşılmadı" 
                                      : (isTakeawaySelected ? "Gel-Al Siparişi Onayla" : "Siparişi Onayla")),
                                  const SizedBox(width: 8),
                                  Icon(underMin 
                                      ? Icons.lock_outline_rounded 
                                      : (isTakeawaySelected ? Icons.shopping_bag_outlined : Icons.payment), 
                                      size: 18),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10), const SizedBox(height: 10),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Handle Checkout Action
  Future<void> _placeCustomerOrder(double totalAmount, {bool isTakeaway = false, String? note}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CupertinoActivityIndicator(radius: 16, color: Colors.white),
      ),
    );

    final error = await FirebaseService.placeOrder(
      _cart.values.toList(),
      totalAmount,
      isTakeaway: isTakeaway,
      note: note,
    );

    if (mounted) Navigator.of(context).pop(); // Dismiss loading spinner

    if (error != null) {
      _showErrorDialog("Sipariş Verilemedi", error);
    } else {
      setState(() {
        _cart.clear(); // Clear local shopping cart
        _currentTab = 1; // Switch to the live order status timeline tab!
      });

      _showSuccessDialog(
        "Siparişiniz Alındı!",
        "En kısa sürede hazırlanarak kapınıza ulaştırılacaktır. Siparişlerim sekmesinden anlık durumunu izleyebilirsiniz.",
      );
    }
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text(content, style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Tamam"),
          )
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 28),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        content: Text(content, style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Harika!"),
          )
        ],
      ),
    );
  }

  // Visual order timeline builders
  Widget _buildTimelineStep(String label, bool isCompleted, bool isActive, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? color
                  : isActive
                      ? color.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isCompleted || isActive ? color : Colors.white24,
                width: 1.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              size: 18,
              color: isCompleted
                  ? Colors.black
                  : isActive
                      ? color
                      : Colors.white30,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isCompleted
                  ? Colors.white
                  : isActive
                      ? color
                      : Colors.white30,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseService.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CupertinoActivityIndicator(radius: 12, color: Colors.white),
        ),
      );
    }
    final theme = Theme.of(context);
    final user = FirebaseService.currentUser;
    final String greetingName = user != null ? user.fullName.split(' ')[0] : 'Misafir';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lunch_dining_rounded, color: theme.primaryColor, size: 24),
            const SizedBox(width: 8),
            Text(
              "Yemek Sipariş",
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 22),
            tooltip: "Çıkış Yap",
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: _currentTab == 0
          ? _buildMenuTab(theme, greetingName)
          : _currentTab == 1
              ? _buildOrdersTab(theme)
              : _buildProfileTab(theme),
      
      // Floating cart indicator badge
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showCartSheet,
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 6,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart, size: 20),
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        "$_cartItemCount",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
              label: Text(
                "${_cartTotal.toStringAsFixed(0)} TL",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            )
          : null,
      
      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) => setState(() => _currentTab = index),
          backgroundColor: theme.scaffoldBackgroundColor,
          selectedItemColor: theme.primaryColor,
          unselectedItemColor: Colors.white30,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu),
              activeIcon: Icon(Icons.restaurant_menu_rounded),
              label: "Yemekler",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: "Siparişlerim",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: "Profilim",
            ),
          ],
        ),
      ),
    );
  }

  // Builder for Menu Tab (Listing all tasty dishes)
  Widget _buildMenuTab(ThemeData theme, String userName) {
    final user = FirebaseService.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Greeting & Header Card
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Merhaba, ",
                    style: GoogleFonts.outfit(fontSize: 22, color: Colors.white70),
                  ),
                  Text(
                    "$userName! 👋",
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: theme.primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Bugün canın ne yemek istiyor?",
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white38),
              ),
            ],
          ),
        ),

        // Active Delivery Address Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: InkWell(
            onTap: () {
              setState(() {
                _currentTab = 2; // Swap to Profile tab
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.primaryColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, color: theme.primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user?.address.isNotEmpty == true 
                          ? "Teslimat: ${user?.address ?? ''}" 
                          : "Lütfen bir teslimat adresi seçin (Tıklayın)",
                      style: GoogleFonts.outfit(
                        fontSize: 11, 
                        fontWeight: FontWeight.bold, 
                        color: user?.address.isNotEmpty == true ? Colors.white70 : theme.primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 16),
                ],
              ),
            ),
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: CupertinoSearchTextField(
            backgroundColor: theme.cardColor,
            placeholder: "Yemek, kategori veya tatlı ara...",
            placeholderStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),

        // Nearby Restaurants Section
        if (user != null && FirebaseService.getNearbyRestaurants(user.address).isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "📍 Yakınınızdaki Restoranlar",
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
                Text(
                  "${FirebaseService.getNearbyRestaurants(user.address).length} Aktif",
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 95,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: FirebaseService.getNearbyRestaurants(user.address).length,
              itemBuilder: (context, idx) {
                final r = FirebaseService.getNearbyRestaurants(user.address)[idx];
                return Container(
                  width: 180,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        r.restaurantName.isNotEmpty ? r.restaurantName : r.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        r.restaurantAddress.isNotEmpty ? r.restaurantAddress : "Adres bilgisi yok",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.delivery_dining, size: 12, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            FirebaseService.calculateDistanceString(user.address, r.restaurantAddress),
                            style: GoogleFonts.outfit(fontSize: 9, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Horizontal Category Pill Widgets
        StreamBuilder<List<String>>(
          stream: FirebaseService.streamCategories(),
          builder: (context, catSnapshot) {
            final dynamicCats = ["Hepsi", ...(catSnapshot.data ?? ["Çorba", "Ana Yemek", "Tatlı", "İçecek"])];
            return SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: dynamicCats.length,
                itemBuilder: (context, index) {
                  final cat = dynamicCats[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isSelected ? Colors.white : Colors.white60,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: theme.primaryColor,
                      backgroundColor: theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? theme.primaryColor : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),

        // Main Restaurants Grid
        Expanded(
          child: StreamBuilder<List<FoodItem>>(
            stream: FirebaseService.streamFoodItems(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator(radius: 12, color: Colors.white));
              }

              if (snapshot.hasError) {
                return Center(child: Text("Hata: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
              }

              final allItems = snapshot.data ?? [];
              final nearby = FirebaseService.getNearbyRestaurants(user?.address ?? "");

              // Filter nearby restaurants based on category & search query
              final filteredRestaurants = nearby.where((rest) {
                // 1. Category Filter: must have at least one food item in selected category
                if (_selectedCategory != "Hepsi") {
                  final hasItemInCat = allItems.any((item) =>
                    item.restaurantOwnerId == rest.uid &&
                    item.category == _selectedCategory
                  );
                  if (!hasItemInCat) return false;
                }

                // 2. Search Query Filter
                if (_searchQuery.isNotEmpty) {
                  final restName = rest.restaurantName.isNotEmpty ? rest.restaurantName : rest.fullName;
                  final matchRestName = restName.toLowerCase().contains(_searchQuery) ||
                                        rest.restaurantAddress.toLowerCase().contains(_searchQuery);
                  if (matchRestName) return true;

                  final matchFoods = allItems.any((item) =>
                    item.restaurantOwnerId == rest.uid &&
                    (item.name.toLowerCase().contains(_searchQuery) ||
                     item.description.toLowerCase().contains(_searchQuery))
                  );
                  return matchFoods;
                }

                return true;
              }).toList();

              if (user == null || user.address.trim().isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off_rounded, size: 60, color: Colors.orangeAccent),
                      const SizedBox(height: 16),
                      Text(
                        "Lütfen Önce Teslimat Adresi Seçin",
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Restoranları görebilmek için\nyukarıdan bir teslimat adresi girmeli veya seçmelisiniz.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              if (filteredRestaurants.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: theme.primaryColor,
                  backgroundColor: theme.cardColor,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                      const Icon(Icons.search_off_rounded, size: 54, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        "Aradığınız kriterlere veya mesafeye uygun restoran bulunamadı.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _handleRefresh,
                color: theme.primaryColor,
                backgroundColor: theme.cardColor,
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 80), // bottom spacing for FAB
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: filteredRestaurants.length,
                  itemBuilder: (context, index) {
                    final rest = filteredRestaurants[index];
                    final String rName = rest.restaurantName.isNotEmpty ? rest.restaurantName : rest.fullName;
                    final double dist = FirebaseService.calculateDistanceKm(user.address, rest.restaurantAddress);
                    
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RestaurantDetailScreen(
                              restaurant: rest,
                              cart: _cart,
                              onAdd: _addToCart,
                              onUpdateQuantity: _updateCartQuantity,
                              onShowCart: _showCartSheet,
                              cartItemCount: _cartItemCount,
                              cartTotal: _cartTotal,
                            ),
                          ),
                        ).then((_) {
                          // Force state rebuild when returning from Detail screen to keep cart badge in sync
                          setState(() {});
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Restaurant Image with info overlay
                            Expanded(
                              flex: 11,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&auto=format&fit=crop&q=60",
                                    fit: BoxFit.cover,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.delivery_dining, color: Colors.white, size: 10),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${dist.toStringAsFixed(1)} km",
                                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),

                            // Restaurant Title & Distance
                            Expanded(
                              flex: 10,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rName,
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      rest.restaurantAddress,
                                      style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Min: ${rest.minOrderAmount.toStringAsFixed(0)} TL",
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.white60),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: theme.primaryColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            "Menüye Bak",
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: theme.primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Builder for live Orders Tab with stepper tracking timeline
  Widget _buildOrdersTab(ThemeData theme) {
    final user = FirebaseService.currentUser;
    if (user == null) {
      return Center(
        child: Text("Siparişlerinizi listelemek için giriş yapmalısınız.", style: GoogleFonts.outfit(color: Colors.white54)),
      );
    }

    return StreamBuilder<List<OrderModel>>(
      stream: FirebaseService.streamOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator(radius: 12, color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(child: Text("Hata: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
        }

        final allOrders = snapshot.data ?? [];
        
        // Filter orders only belonging to this logged-in Customer!
        final customerOrders = allOrders.where((o) => o.customerId == user.uid).toList();

        if (customerOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.white12),
                const SizedBox(height: 16),
                Text(
                  "Henüz verilmiş bir siparişiniz bulunmamaktadır.",
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: theme.primaryColor,
          backgroundColor: theme.cardColor,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: customerOrders.length,
          itemBuilder: (context, index) {
            final order = customerOrders[index];

            // Map status values to index and colors
            int stepIndex = 0;
            if (order.status == 'preparing') stepIndex = 1;
            if (order.status == 'on_the_way') stepIndex = 2;
            if (order.status == 'delivered') stepIndex = 3;

            return Container(
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Order Header block
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Sipariş No: #${order.id.length > 8 ? order.id.substring(order.id.length - 6).toUpperCase() : order.id}",
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')} - ${order.createdAt.day}.${order.createdAt.month}.${order.createdAt.year}",
                            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                      Text(
                        "${order.totalAmount.toStringAsFixed(0)} TL",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: theme.primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),

                  // Order Meals Detail Listing
                  ...order.items.map((mealItem) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${mealItem.quantity}x ${mealItem.foodItem.name}",
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            "${(mealItem.foodItem.price * mealItem.quantity).toStringAsFixed(0)} TL",
                            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),

                  // Dynamic Firebase-Aware Realtime Order Tracker Stepper
                  Row(
                    children: [
                      _buildTimelineStep(
                        "Alındı",
                        stepIndex >= 0,
                        stepIndex == 0,
                        Icons.fact_check,
                        Colors.amber.shade600,
                      ),
                      Container(
                        width: 16,
                        height: 2,
                        color: stepIndex >= 1 ? Colors.orange : Colors.white12,
                      ),
                      _buildTimelineStep(
                        "Hazırlanıyor",
                        stepIndex >= 1,
                        stepIndex == 1,
                        Icons.outdoor_grill,
                        Colors.orange,
                      ),
                      Container(
                        width: 16,
                        height: 2,
                        color: stepIndex >= 2 ? Colors.blueAccent : Colors.white12,
                      ),
                      _buildTimelineStep(
                        "Yolda",
                        stepIndex >= 2,
                        stepIndex == 2,
                        Icons.delivery_dining,
                        Colors.blueAccent,
                      ),
                      Container(
                        width: 16,
                        height: 2,
                        color: stepIndex >= 3 ? const Color(0xFF10B981) : Colors.white12,
                      ),
                      _buildTimelineStep(
                        "Teslim Edildi",
                        stepIndex >= 3,
                        stepIndex == 3,
                        Icons.done_all_rounded,
                        const Color(0xFF10B981),
                      ),
                    ],
                  ),
                  if (order.isTakeaway) ...[
                    const SizedBox(height: 16),
                    Builder(
                      builder: (ctx) {
                        final firstItem = order.items.isNotEmpty ? order.items.first.foodItem : null;
                        final restOwner = firstItem != null ? FirebaseService.getRestaurantOwnerSync(firstItem.restaurantOwnerId) : null;
                        final String restAddress = restOwner?.restaurantAddress ?? "Konum bilgisi yükleniyor...";
                        final String restName = restOwner?.restaurantName ?? (restOwner?.fullName ?? "Restoran");

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.primaryColor.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.map_rounded, color: theme.primaryColor, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Gel-Al Sipariş Konumu 📍",
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "$restName: $restAddress",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  final query = Uri.encodeComponent(restAddress);
                                  final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
                                  launchUrl(url, mode: LaunchMode.externalApplication);
                                },
                                child: Text(
                                  "Yol Tarifi",
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 12, color: Colors.white)),
                          );
                          final session = await FirebaseService.startChatSession(order.id);
                          if (context.mounted) Navigator.pop(context); // close loader
                          if (session != null && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LiveSupportScreen(session: session)),
                            );
                          }
                        },
                        icon: const Icon(Icons.support_agent_rounded, size: 16, color: Colors.amber),
                        label: Text(
                          "Sipariş Hakkında Destek Al",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.amber,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          backgroundColor: Colors.white.withValues(alpha: 0.03),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.amber.withValues(alpha: 0.2)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Interactive Rating Section for Delivered Orders
                  if (order.status == 'delivered') ...[
                    const SizedBox(height: 18),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.rating != null ? "Değerlendirmeniz:" : "Siparişi Değerlendirin:",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: order.rating != null ? Colors.white38 : Colors.white70,
                          ),
                        ),
                        if (order.rating != null)
                          Row(
                            children: List.generate(5, (starIndex) {
                              return Icon(
                                Icons.star_rounded,
                                color: starIndex < order.rating! ? const Color(0xFFFFB020) : Colors.white10,
                                size: 20,
                              );
                            }),
                          )
                        else
                          Row(
                            children: List.generate(5, (starIndex) {
                              final currentStar = starIndex + 1;
                              return GestureDetector(
                                onTap: () async {
                                  final err = await FirebaseService.updateOrderRating(order.id, currentStar);
                                  if (!context.mounted) return;
                                  if (err != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Hata: $err", style: GoogleFonts.outfit(color: Colors.white)),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Sipariş puanlandı! Teşekkür ederiz. ❤️", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                                        backgroundColor: const Color(0xFF10B981),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                  child: Icon(
                                    Icons.star_outline_rounded,
                                    color: const Color(0xFFFFB020).withValues(alpha: 0.5),
                                    size: 26,
                                  ),
                                ),
                              );
                            }),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
      },
    );
  }

  // Show Address Editor Sheet (for Add or Edit)
  void _showAddressEditorSheet(DeliveryAddress? existingAddress) {
    final titleController = TextEditingController(text: existingAddress?.title ?? "");
    final addressDetailController = TextEditingController();
    final phoneController = TextEditingController(text: existingAddress?.phone ?? "");
    final formKey = GlobalKey<FormState>();

    // Location Hierarchy State
    String selectedCountry = "Türkiye";
    List<Province> provincesList = [];
    Province? selectedProvince;
    District? selectedDistrict;
    List<Neighborhood> neighborhoodsList = [];
    Neighborhood? selectedNeighborhood;

    bool isLoadingProvinces = true;
    bool isLoadingNeighborhoods = false;
    bool initialLoadDone = false;

    // Parse out address details if editing
    if (existingAddress != null) {
      final parts = existingAddress.fullAddress.split(', ');
      if (parts.length >= 2) {
        addressDetailController.text = parts[1];
      } else {
        addressDetailController.text = existingAddress.fullAddress;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Asynchronous initializer for provinces & matched states
            if (!initialLoadDone) {
              initialLoadDone = true;
              LocationApiService.getProvinces().then((loadedProvinces) async {
                provincesList = loadedProvinces;
                isLoadingProvinces = false;

                // Auto-match values if editing an existing address
                if (existingAddress != null) {
                  final text = existingAddress.fullAddress.toLowerCase();

                  // 1. Match Province (City)
                  for (var p in provincesList) {
                    if (text.contains(p.name.toLowerCase())) {
                      selectedProvince = p;
                      break;
                    }
                  }

                  // 2. Match District
                  if (selectedProvince != null) {
                    for (var d in selectedProvince!.districts) {
                      if (text.contains(d.name.toLowerCase())) {
                        selectedDistrict = d;
                        break;
                      }
                    }
                  }

                  // 3. Load & Match Neighborhood
                  if (selectedDistrict != null) {
                    isLoadingNeighborhoods = true;
                    setModalState(() {});
                    try {
                      final nhList = await LocationApiService.getNeighborhoods(selectedDistrict!.id);
                      neighborhoodsList = nhList;
                      for (var nh in neighborhoodsList) {
                        if (text.contains(nh.name.toLowerCase())) {
                          selectedNeighborhood = nh;
                          break;
                        }
                      }
                    } catch (_) {}
                    isLoadingNeighborhoods = false;
                  }
                }
                setModalState(() {});
              });
            }

            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.78,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_location_alt_rounded, color: Theme.of(context).primaryColor, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            existingAddress == null ? "Yeni Adres Ekle" : "Adresi Düzenle",
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 20),
                      Expanded(
                        child: ListView(
                          children: [
                            TextFormField(
                              controller: titleController,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: "Adres Başlığı (Örn: Ev, İş)",
                                prefixIcon: Icon(Icons.bookmark_outline_rounded, size: 20),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? "Başlık gerekli" : null,
                            ),
                            const SizedBox(height: 12),

                            // --- Country Field ---
                            DropdownButtonFormField<String>(
                              initialValue: selectedCountry,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                              dropdownColor: Theme.of(context).cardColor,
                              decoration: const InputDecoration(
                                labelText: "Ülke",
                                prefixIcon: Icon(Icons.public_rounded, size: 20),
                              ),
                              items: LocationApiService.getCountries().map((c) {
                                return DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    selectedCountry = val;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            // --- Province (City) Field ---
                            DropdownButtonFormField<Province>(
                              initialValue: selectedProvince,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                              dropdownColor: Theme.of(context).cardColor,
                              decoration: InputDecoration(
                                labelText: "Şehir / İl",
                                prefixIcon: const Icon(Icons.location_city_rounded, size: 20),
                                suffixIcon: isLoadingProvinces
                                    ? const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : null,
                              ),
                              items: provincesList.map((p) {
                                return DropdownMenuItem<Province>(
                                  value: p,
                                  child: Text(p.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13)),
                                );
                              }).toList(),
                              validator: (v) => v == null ? "Şehir seçimi zorunludur" : null,
                              onChanged: (val) {
                                setModalState(() {
                                  selectedProvince = val;
                                  selectedDistrict = null;
                                  selectedNeighborhood = null;
                                  neighborhoodsList = [];
                                });
                              },
                            ),
                            const SizedBox(height: 12),

                            // --- District Field ---
                            DropdownButtonFormField<District>(
                              initialValue: selectedDistrict,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                              dropdownColor: Theme.of(context).cardColor,
                              decoration: const InputDecoration(
                                labelText: "İlçe",
                                prefixIcon: Icon(Icons.explore_rounded, size: 20),
                              ),
                              items: (selectedProvince?.districts ?? []).map((d) {
                                return DropdownMenuItem<District>(
                                  value: d,
                                  child: Text(d.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13)),
                                );
                              }).toList(),
                              validator: (v) => v == null ? "İlçe seçimi zorunludur" : null,
                              onChanged: (val) async {
                                if (val == null) return;
                                setModalState(() {
                                  selectedDistrict = val;
                                  selectedNeighborhood = null;
                                  neighborhoodsList = [];
                                  isLoadingNeighborhoods = true;
                                });

                                try {
                                  final nhList = await LocationApiService.getNeighborhoods(val.id);
                                  setModalState(() {
                                    neighborhoodsList = nhList;
                                    isLoadingNeighborhoods = false;
                                  });
                                } catch (_) {
                                  setModalState(() {
                                    isLoadingNeighborhoods = false;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            // --- Neighborhood Field ---
                            DropdownButtonFormField<Neighborhood>(
                              initialValue: selectedNeighborhood,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                              dropdownColor: Theme.of(context).cardColor,
                              decoration: InputDecoration(
                                labelText: "Mahalle / Semt",
                                prefixIcon: const Icon(Icons.holiday_village_rounded, size: 20),
                                suffixIcon: isLoadingNeighborhoods
                                    ? const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : null,
                              ),
                              items: neighborhoodsList.map((nh) {
                                return DropdownMenuItem<Neighborhood>(
                                  value: nh,
                                  child: Text(nh.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13)),
                                );
                              }).toList(),
                              validator: (v) => v == null ? "Mahalle seçimi zorunludur" : null,
                              onChanged: (val) {
                                setModalState(() {
                                  selectedNeighborhood = val;
                                });
                              },
                            ),
                            const SizedBox(height: 12),

                            // --- Address Detail Field ---
                            TextFormField(
                              controller: addressDetailController,
                              maxLines: 2,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: "Açık Adres (Sokak, No, Daire, vb.)",
                                prefixIcon: Icon(Icons.home_rounded, size: 20),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? "Açık adres detayı zorunludur" : null,
                            ),
                            const SizedBox(height: 12),

                            // --- Phone Field ---
                            TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: "İrtibat Telefonu",
                                prefixIcon: Icon(Icons.phone_iphone_rounded, size: 20),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? "Telefon gerekli" : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final user = FirebaseService.currentUser;
                          if (user == null) return;

                          // Construct elegant hierarchical address string representation
                          final String combinedAddress = "${selectedNeighborhood!.name} Mh., ${addressDetailController.text.trim()}, ${selectedDistrict!.name} / ${selectedProvince!.name}, $selectedCountry";

                          final addr = DeliveryAddress(
                            id: existingAddress?.id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
                            title: titleController.text.trim(),
                            fullAddress: combinedAddress,
                            phone: phoneController.text.trim(),
                          );

                          await FirebaseService.saveAddress(user.uid, addr);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Adres başarıyla kaydedildi!", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
                                backgroundColor: Theme.of(context).primaryColor,
                              ),
                            );
                          }
                        },
                        child: const Text("Adresi Kaydet"),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Builder for the stunning Profile & Switch dashboard tab
  Widget _buildProfileTab(ThemeData theme) {
    final user = FirebaseService.currentUser;
    if (user == null) {
      return Center(
        child: Text("Profilinizi görüntülemek için giriş yapmalısınız.", style: GoogleFonts.outfit(color: Colors.white54)),
      );
    }

    _phoneController ??= TextEditingController(text: user.phone);
    _addressController ??= TextEditingController(text: user.address);

    final bool canManage = user.role == 'admin' || user.role == 'restaurant_owner' || user.role == 'support';
    final String roleLabel = user.role == 'admin' 
        ? 'Sistem Yöneticisi (Admin)' 
        : user.role == 'restaurant_owner' 
            ? 'Restoran Sahibi' 
            : user.role == 'support'
                ? 'Destek Görevlisi'
                : 'Müşteri';

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: theme.primaryColor,
      backgroundColor: theme.cardColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Branch Invitation Notifications
          StreamBuilder<List<BranchInvitation>>(
            stream: FirebaseService.streamBranchInvitations(),
            builder: (context, snapshot) {
              final invites = snapshot.data ?? [];
              if (invites.isEmpty) return const SizedBox();

              return Column(
                children: invites.map((invite) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E3A8A).withValues(alpha: 0.8),
                          const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.business_rounded, color: Color(0xFF60A5FA), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Şube Yetkilisi Daveti!",
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF93C5FD),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    invite.restaurantName,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Bu restoran sizi yönetici/şube yetkilisi olarak atamak istiyor. Kabul ettiğiniz takdirde restoran yönetim paneline erişebileceksiniz.",
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final error = await FirebaseService.respondToBranchInvitation(invite.id, false);
                                if (context.mounted && error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error, style: GoogleFonts.outfit())),
                                  );
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white38,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: Text("Reddet", style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () async {
                                final error = await FirebaseService.respondToBranchInvitation(invite.id, true);
                                if (context.mounted) {
                                  if (error != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error, style: GoogleFonts.outfit())),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "${invite.restaurantName} şube yetkilisi davetini kabul ettiniz!",
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                        backgroundColor: theme.primaryColor,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        margin: const EdgeInsets.all(16),
                                      ),
                                    );
                                    // Refresh layout to update dashboards
                                    setState(() {});
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                              child: Text("Kabul Et", style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          // Profile Card with Glowing Avatar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [theme.primaryColor, theme.colorScheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                      style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.white38),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: user.role == 'admin' 
                              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                              : user.role == 'restaurant_owner'
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          roleLabel,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: user.role == 'admin' 
                                ? const Color(0xFFF87171)
                                : user.role == 'restaurant_owner'
                                    ? const Color(0xFF34D399)
                                    : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Glowing Support Session Launcher
          GestureDetector(
            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 14, color: Colors.white)),
              );
              final session = await FirebaseService.startChatSession();
              if (mounted) Navigator.pop(context); // close loader
              if (session != null && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LiveSupportScreen(session: session)),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "7/24 Canlı Destek",
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          "Müşteri temsilcisiyle anında sohbet edin",
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Profile fields editable section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "İletişim Bilgileri",
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Divider(color: Colors.white10, height: 20),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: "Telefon Numarası",
                    prefixIcon: Icon(Icons.phone_iphone_rounded, size: 16),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 14, color: Colors.white)),
                    );
                    final err = await FirebaseService.updateUserProfile(
                      uid: user.uid,
                      phone: _phoneController!.text.trim(),
                    );
                    if (mounted) Navigator.pop(context); // close loader
                    if (mounted) {
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Telefon numarası başarıyla güncellendi!", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
                            backgroundColor: theme.primaryColor,
                          ),
                        );
                        setState(() {});
                      }
                    }
                  },
                  child: const Text("Bilgileri Güncelle"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Registered Delivery Addresses Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Kayıtlı Adreslerim",
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddressEditorSheet(null),
                      icon: const Icon(Icons.add, size: 14),
                      label: Text("Ekle", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 20),
                StreamBuilder<List<DeliveryAddress>>(
                  stream: FirebaseService.streamAddresses(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CupertinoActivityIndicator(radius: 10, color: Colors.white30));
                    }
                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          "Henüz kayıtlı bir adresiniz bulunmuyor.",
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.white30),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      itemBuilder: (context, idx) {
                        final addr = list[idx];
                        final isSelected = addr.id == user.selectedAddressId || (user.selectedAddressId.isEmpty && user.address == addr.fullAddress);
                        
                        return GestureDetector(
                          onTap: () async {
                            await FirebaseService.selectAddress(user.uid, addr.id, addr.fullAddress, addr.phone);
                            setState(() {});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? theme.primaryColor.withValues(alpha: 0.05) 
                                  : Colors.white.withValues(alpha: 0.01),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected 
                                    ? theme.primaryColor.withValues(alpha: 0.4) 
                                    : Colors.white.withValues(alpha: 0.04),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: theme.primaryColor.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ] : [],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, 
                                  color: isSelected ? theme.primaryColor : Colors.white30, 
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            addr.title,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13, 
                                              fontWeight: FontWeight.bold, 
                                              color: isSelected ? theme.primaryColor : Colors.white,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: theme.primaryColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                "Seçili",
                                                style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: theme.primaryColor),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          GestureDetector(
                                            onTap: () => _showAddressEditorSheet(addr),
                                            child: Icon(Icons.edit_outlined, color: theme.primaryColor, size: 15),
                                          ),
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () async {
                                              await FirebaseService.deleteAddress(user.uid, addr.id);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("Adres silindi.")),
                                                );
                                              }
                                            },
                                            child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 15),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        addr.fullAddress,
                                        style: GoogleFonts.outfit(fontSize: 11, color: Colors.white54),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        addr.phone,
                                        style: GoogleFonts.outfit(fontSize: 10, color: Colors.white30),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Past Support Tickets & Live Chats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_edu_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Aldığım Destekler & Sohbetler",
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 20),
                StreamBuilder<List<ChatSession>>(
                  stream: FirebaseService.streamCustomerChatSessions(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CupertinoActivityIndicator(radius: 10, color: Colors.white30));
                    }
                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          "Henüz geçmiş bir canlı destek talebiniz bulunmuyor.",
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.white30, fontStyle: FontStyle.italic),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length > 5 ? 5 : list.length, // Let's show up to 5 most recent tickets
                      itemBuilder: (context, idx) {
                        final session = list[idx];
                        final isClosed = session.status == 'closed';
                        final String lastMsg = session.messages.isNotEmpty 
                            ? (session.messages.last.imageUrl.isNotEmpty 
                                ? "🖼️ Fotoğraf gönderildi" 
                                : session.messages.last.text)
                            : "Mesaj yok";

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LiveSupportScreen(session: session)),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.01),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isClosed 
                                        ? Colors.white.withValues(alpha: 0.04) 
                                        : Colors.amber.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isClosed ? Icons.chat_bubble_outline_rounded : Icons.chat_bubble_rounded, 
                                    color: isClosed ? Colors.white38 : Colors.amber, 
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              session.orderId != null && session.orderId!.isNotEmpty
                                                  ? "Sipariş Destek #${session.orderId!.length > 8 ? session.orderId!.substring(session.orderId!.length - 6).toUpperCase() : session.orderId}"
                                                  : "Genel Canlı Destek",
                                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isClosed 
                                                  ? Colors.white.withValues(alpha: 0.1) 
                                                  : Colors.blueAccent.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isClosed ? "Sonlandı" : "Aktif",
                                              style: GoogleFonts.outfit(
                                                fontSize: 8, 
                                                fontWeight: FontWeight.bold, 
                                                color: isClosed ? Colors.white38 : Colors.blueAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastMsg,
                                        style: GoogleFonts.outfit(fontSize: 11, color: Colors.white54),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            "${session.updatedAt.day}/${session.updatedAt.month}/${session.updatedAt.year} ${session.updatedAt.hour}:${session.updatedAt.minute.toString().padLeft(2, '0')}",
                                            style: GoogleFonts.outfit(fontSize: 9, color: Colors.white24),
                                          ),
                                          const Spacer(),
                                          if (session.rating != null && session.rating! > 0) ...[
                                            const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                                            const SizedBox(width: 2),
                                            Text(
                                              "${session.rating}/5 Puan",
                                              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                                            ),
                                          ] else if (isClosed) ...[
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "Puan Ver: ",
                                                  style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38),
                                                ),
                                                ...List.generate(5, (starIdx) {
                                                  final score = starIdx + 1;
                                                  return InkWell(
                                                    onTap: () async {
                                                      final err = await FirebaseService.rateSupportSession(session.id, score);
                                                      if (err != null && context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text("Puan iletilemedi: $err"),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      } else if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text("Desteğe $score/5 puan verdiniz. Teşekkürler!"),
                                                            backgroundColor: Colors.green,
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                                      child: Icon(
                                                        Icons.star_border_rounded,
                                                        color: Colors.amber,
                                                        size: 14,
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Admin/Owner portal switch
          if (canManage) ...[
            GestureDetector(
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RestaurantDashboard()),
                  (route) => false,
                );
              },
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [theme.primaryColor, theme.colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.dashboard_customize_rounded, color: Colors.black, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      user.role == 'restaurant_owner' 
                          ? "Restoran Paneline Geç" 
                          : (user.role == 'support' ? "Destek Paneline Geç" : "Yönetim Paneline Geç"),
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // App Settings & Logout Cards
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Column(
              children: [
                _buildProfileItem(
                  icon: Icons.logout_rounded,
                  title: "Oturumu Kapat",
                  color: Colors.redAccent,
                  onTap: _handleSignOut,
                ),
              ],
            ),
          ),
        ],
      ),
    ),);
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}

class _AnimatedNotificationToast extends StatefulWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;

  const _AnimatedNotificationToast({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.onDismiss,
  });

  @override
  State<_AnimatedNotificationToast> createState() => _AnimatedNotificationToastState();
}

class _AnimatedNotificationToastState extends State<_AnimatedNotificationToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: widget.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.desc,
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white30, size: 18),
              onPressed: () {
                _controller.reverse().then((_) {
                  widget.onDismiss();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
