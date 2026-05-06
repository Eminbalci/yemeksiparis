import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentTab = 0; // 0: Menu, 1: Orders
  String _searchQuery = "";
  String _selectedCategory = "Hepsi";

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double subtotal = _cartTotal;
            final double deliveryFee = subtotal > 200 || subtotal == 0 ? 0 : 30;
            final double total = subtotal + deliveryFee;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                                Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.white24),
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
                                      color: Colors.white.withOpacity(0.05),
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Ara Toplam", style: GoogleFonts.outfit(color: Colors.white60)),
                        Text("${subtotal.toStringAsFixed(0)} TL", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500)),
                      ],
                    ),
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
                      ? color.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: isCompleted || isActive ? color : Colors.white24,
                width: 1.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
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
          : _buildOrdersTab(theme),
      
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
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
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
          ],
        ),
      ),
    );
  }

  // Builder for Menu Tab (Listing all tasty dishes)
  Widget _buildMenuTab(ThemeData theme, String userName) {
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

        // Horizontal Category Pill Widgets
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
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
                      color: isSelected ? theme.primaryColor : Colors.white.withOpacity(0.05),
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
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
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
                                    color: Colors.black.withOpacity(0.65),
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
                                    color: theme.primaryColor.withOpacity(0.85),
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
                                          color: theme.primaryColor.withOpacity(0.12),
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
                border: Border.all(color: Colors.white.withOpacity(0.04)),
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
}
