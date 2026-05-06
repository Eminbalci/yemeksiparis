import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'restaurant_dashboard.dart';
import 'live_support_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentTab = 0; // 0: Menu, 1: Orders
  String _searchQuery = "";
  String _selectedCategory = "Hepsi";

  TextEditingController? _phoneController;
  TextEditingController? _addressController;

  @override
  void dispose() {
    _phoneController?.dispose();
    _addressController?.dispose();
    super.dispose();
  }

  // Shopping Cart state
  final Map<String, OrderItem> _cart = {};

  final List<String> _categories = [
    "Hepsi",
    "Kebaplar",
    "Dönerler",
    "Burgerler",
    "Pizzalar",
    "Tatlılar",
    "İçecekler"
  ];

  double get _cartTotal {
    double total = 0;
    _cart.forEach((_, item) {
      total += item.foodItem.price * item.quantity;
    });
    return total;
  }

  int get _cartItemCount {
    int count = 0;
    _cart.forEach((_, item) {
      count += item.quantity;
    });
    return count;
  }

  void _addToCart(FoodItem item) {
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double subtotal = _cartTotal;
            double discountAmount = 0.0;
            if (appliedDiscount != null) {
              discountAmount = appliedDiscount!.calculateDiscount(subtotal);
            }
            final double finalSubtotal = (subtotal - discountAmount) < 0 ? 0 : (subtotal - discountAmount);
            final double deliveryFee = finalSubtotal > 200 || finalSubtotal == 0 ? 0 : 30;
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
                  const SizedBox(height: 12),

                  // Cart Items List
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
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _cart.length,
                            separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                            itemBuilder: (context, index) {
                              final item = _cart.values.elementAt(index);
                              return Row(
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
                              );
                            },
                          ),
                  ),

                  // Checkout Summary & Action Buttons
                  if (_cart.isNotEmpty) ...[
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 8),

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
                    const SizedBox(height: 12),

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
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Toplam Tutar", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(
                          "${total.toStringAsFixed(0)} TL",
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Theme.of(context).primaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop(); // Close bottom sheet
                        _placeCustomerOrder(total);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Siparişi Onayla"),
                          SizedBox(width: 8),
                          Icon(Icons.payment, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
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
  Future<void> _placeCustomerOrder(double totalAmount) async {
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
                            "Yakın konumda",
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

        // Main Food List Grid
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
              
              // Filter food items based on Search query & Category chip selected
              final filteredItems = allItems.where((item) {
                final matchQuery = item.name.toLowerCase().contains(_searchQuery) ||
                                   item.description.toLowerCase().contains(_searchQuery) ||
                                   item.category.toLowerCase().contains(_searchQuery);
                final matchCategory = _selectedCategory == "Hepsi" || item.category == _selectedCategory;
                return matchQuery && matchCategory;
              }).toList();

              if (filteredItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 54, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        "Aradığınız kriterlere uygun yemek bulunamadı.",
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 80), // bottom spacing for FAB
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final meal = filteredItems[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Food Image with Rating chip overlays
                        Expanded(
                          flex: 11,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                meal.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  color: Colors.white10,
                                  child: const Icon(Icons.fastfood_rounded, size: 40, color: Colors.white24),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 12),
                                      const SizedBox(width: 3),
                                      Text(
                                        "${meal.rating}",
                                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    meal.category,
                                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),

                        // Food Title & Description
                        Expanded(
                          flex: 10,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal.name,
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Text(
                                    meal.description,
                                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${meal.price.toStringAsFixed(0)} TL",
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: theme.primaryColor),
                                    ),
                                    GestureDetector(
                                      onTap: () => _addToCart(meal),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.add, size: 18, color: theme.primaryColor),
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
                  );
                },
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

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Show Address Editor Sheet (for Add or Edit)
  void _showAddressEditorSheet(DeliveryAddress? existingAddress) {
    final titleController = TextEditingController(text: existingAddress?.title ?? "");
    final addressController = TextEditingController(text: existingAddress?.fullAddress ?? "");
    final phoneController = TextEditingController(text: existingAddress?.phone ?? "");
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            height: 380,
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
                      Icon(Icons.location_on_rounded, color: Theme.of(context).primaryColor, size: 24),
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
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? "Başlık gerekli" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressController,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: "Açık Adres (Mahalle, Sokak, No, İlçe/İl)",
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? "Adres gerekli" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: "İrtibat Telefonu",
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? "Telefon gerekli" : null,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final user = FirebaseService.currentUser;
                      if (user == null) return;

                      final addr = DeliveryAddress(
                        id: existingAddress?.id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
                        title: titleController.text.trim(),
                        fullAddress: addressController.text.trim(),
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

    final bool canManage = user.role == 'admin' || user.role == 'restaurant_owner';
    final String roleLabel = user.role == 'admin' 
        ? 'Sistem Yöneticisi (Admin)' 
        : user.role == 'restaurant_owner' 
            ? 'Restoran Sahibi' 
            : 'Müşteri';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  "İletişim & Varsayılan Teslimat",
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: "Genel Teslimat Adresi",
                    prefixIcon: Icon(Icons.home_work_outlined, size: 16),
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
                      address: _addressController!.text.trim(),
                    );
                    if (mounted) Navigator.pop(context); // close loader
                    if (mounted) {
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Profil bilgileri başarıyla güncellendi!", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
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
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: Colors.white30, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          addr.title,
                                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
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
                                    const SizedBox(height: 4),
                                    Text(
                                      addr.fullAddress,
                                      style: GoogleFonts.outfit(fontSize: 11, color: Colors.white54),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      addr.phone,
                                      style: GoogleFonts.outfit(fontSize: 10, color: Colors.white30),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                      "Yönetim Paneline Geç",
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
    );
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
