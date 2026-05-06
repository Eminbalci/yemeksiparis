import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'customer_dashboard.dart';
import 'live_support_screen.dart';

class RestaurantDashboard extends StatefulWidget {
  const RestaurantDashboard({super.key});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  int _currentTab = 0;
  int _managementSubTab = 0;   // 0: Şubeler, 1: İndirim Kodları, 2: Kategoriler
  int _supportQueueSubTab = 0; // 0: Aktif Sohbetler, 1: Geçmiş
  int _adminSuiteSubTab = 0;   // 0: Performans Analizi, 1: Yetki Kontrolleri

  // New Meal Form controllers
  final _addMealFormKey = GlobalKey<FormState>();
  final _mealNameController = TextEditingController();
  final _mealDescController = TextEditingController();
  final _mealPriceController = TextEditingController();
  final _mealImageController = TextEditingController();
  String _selectedCategory = "Çorba";

  final List<String> _categories = [
    "Kebaplar",
    "Dönerler",
    "Burgerler",
    "Pizzalar",
    "Tatlılar",
    "İçecekler"
  ];

  @override
  void dispose() {
    _mealNameController.dispose();
    _mealDescController.dispose();
    _mealPriceController.dispose();
    _mealImageController.dispose();
    super.dispose();
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

  // Show "Yeni Yemek Ekle" panel
  void _showAddMealSheet() {
    // Clear fields
    _mealNameController.clear();
    _mealDescController.clear();
    _mealPriceController.clear();
    _mealImageController.clear();
    _selectedCategory = "Kebaplar";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AnimatedPadding(
              padding: MediaQuery.of(context).viewInsets,
              duration: const Duration(milliseconds: 100),
              curve: Curves.decelerate,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Form(
                  key: _addMealFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                          Icon(Icons.add_moderator_outlined, color: Theme.of(context).primaryColor, size: 26),
                          const SizedBox(width: 10),
                          Text(
                            "Yeni Yemek Ekle",
                            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            // Name
                            TextFormField(
                              controller: _mealNameController,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: "Yemek Adı",
                                prefixIcon: Icon(Icons.fastfood_outlined, size: 18, color: Colors.white54),
                                hintText: "Örn: İskender Kebap",
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Lütfen yemek adını girin.";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Description
                            TextFormField(
                              controller: _mealDescController,
                              maxLines: 2,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: "Yemek Açıklaması",
                                prefixIcon: Icon(Icons.description_outlined, size: 18, color: Colors.white54),
                                hintText: "Örn: Pideler tereyağı ile ıslatılır, taze sos ile...",
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Lütfen açıklamayı doldurun.";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Price
                            TextFormField(
                              controller: _mealPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: "Fiyat (TL)",
                                prefixIcon: Icon(Icons.currency_lira, size: 18, color: Colors.white54),
                                hintText: "Örn: 220",
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Lütfen fiyat girin.";
                                }
                                if (double.tryParse(value) == null) {
                                  return "Lütfen geçerli bir sayı girin.";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            // Category
                            StreamBuilder<List<String>>(
                              stream: FirebaseService.streamCategories(),
                              builder: (context, catSnap) {
                                final List<String> dynCats = catSnap.data ?? ["Çorba", "Ana Yemek", "Tatlı", "İçecek"];
                                if (dynCats.isNotEmpty && !dynCats.contains(_selectedCategory)) {
                                  _selectedCategory = dynCats.first;
                                }
                                return Theme(
                                  data: Theme.of(context).copyWith(canvasColor: Theme.of(context).cardColor),
                                  child: DropdownButtonFormField<String>(
                                    value: dynCats.contains(_selectedCategory) ? _selectedCategory : (dynCats.isNotEmpty ? dynCats.first : null),
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                                    decoration: const InputDecoration(
                                      labelText: "Kategori",
                                      prefixIcon: Icon(Icons.category_outlined, size: 18, color: Colors.white54),
                                    ),
                                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).primaryColor),
                                    items: dynCats.map((String val) {
                                      return DropdownMenuItem<String>(
                                        value: val,
                                        child: Text(val, style: GoogleFonts.outfit(color: Colors.white)),
                                      );
                                    }).toList(),
                                    onChanged: (newVal) {
                                      if (newVal != null) {
                                        setModalState(() {
                                          _selectedCategory = newVal;
                                        });
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 14),

                            // Custom image url (Optional)
                            TextFormField(
                              controller: _mealImageController,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: "Görsel URL'si (İsteğe Bağlı)",
                                prefixIcon: Icon(Icons.image_outlined, size: 18, color: Colors.white54),
                                hintText: "Boş bırakılırsa varsayılan görsel atanır.",
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      ElevatedButton(
                        onPressed: () => _handleAddNewMeal(context),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Menüye Ekle"),
                            SizedBox(width: 8),
                            Icon(Icons.restaurant, size: 18),
                          ],
                        ),
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

  // Handle adding new meal
  Future<void> _handleAddNewMeal(BuildContext modalContext) async {
    if (!_addMealFormKey.currentState!.validate()) return;

    Navigator.of(modalContext).pop(); // Close bottom sheet first

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CupertinoActivityIndicator(radius: 16, color: Colors.white),
      ),
    );

    final name = _mealNameController.text.trim();
    final desc = _mealDescController.text.trim();
    final price = double.parse(_mealPriceController.text.trim());
    final img = _mealImageController.text.trim();

    final FoodItem newMeal = FoodItem(
      id: '',
      name: name,
      description: desc,
      price: price,
      imageUrl: img,
      category: _selectedCategory,
      rating: 4.8,
    );

    final error = await FirebaseService.addFoodItem(newMeal);
    
    if (mounted) Navigator.of(context).pop(); // Dismiss spinner

    if (error != null) {
      _showFeedbackDialog("Menü Hatası", "Yemek eklenirken sorun oluştu: $error", isError: true);
    } else {
      _showFeedbackDialog("Başarılı!", "$name menünüze başarıyla eklendi.", isError: false);
    }
  }

  // Handle deleting a meal
  Future<void> _handleDeleteMeal(FoodItem meal) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Yemeği Sil", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text("${meal.name} yemeğini menünüzden kaldırmak istediğinize emin misiniz?", style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: const Size(80, 40),
            ),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final error = await FirebaseService.deleteFoodItem(meal.id);
      if (error != null) {
        _showFeedbackDialog("Menü Hatası", "Yemek silinemedi: $error", isError: true);
      }
    }
  }

  // Action to advance orders state in timeline
  Future<void> _advanceOrderStatus(OrderModel order) async {
    String nextStatus = 'pending';
    String message = '';

    if (order.status == 'pending') {
      nextStatus = 'preparing';
      message = "Sipariş mutfakta hazırlanmaya başladı!";
    } else if (order.status == 'preparing') {
      nextStatus = 'on_the_way';
      message = "Sipariş kuryeye teslim edildi, yolda!";
    } else if (order.status == 'on_the_way') {
      nextStatus = 'delivered';
      message = "Sipariş müşteriye başarıyla ulaştırıldı!";
    } else {
      return; // Already delivered
    }

    final error = await FirebaseService.updateOrderStatus(order.id, nextStatus);
    if (!mounted) return;
    if (error != null) {
      _showFeedbackDialog("Sipariş Hatası", "Sipariş güncellenemedi: $error", isError: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.black)),
          backgroundColor: Theme.of(context).primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showFeedbackDialog(String title, String content, {required bool isError}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: isError ? Colors.redAccent : Colors.greenAccent,
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isAdmin = FirebaseService.currentUser?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard_customize_rounded, color: theme.primaryColor, size: 24),
            const SizedBox(width: 8),
            Text(
              "Yönetim Paneli",
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant_rounded, color: Colors.white70, size: 22),
            tooltip: "Sipariş Paneli (Yemek Sipariş Et)",
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const CustomerDashboard()),
                (route) => false,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 22),
            tooltip: "Çıkış Yap",
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: FirebaseService.streamOrders(),
        builder: (context, orderSnapshot) {
          return StreamBuilder<List<FoodItem>>(
            stream: FirebaseService.streamFoodItems(),
            builder: (context, foodSnapshot) {
              final orders = orderSnapshot.data ?? [];
              final meals = foodSnapshot.data ?? [];

              // Business Statistics computations
              double totalRevenue = 0;
              int activeOrders = 0;
              for (var o in orders) {
                if (o.status == 'delivered') {
                  totalRevenue += o.totalAmount;
                } else {
                  activeOrders++;
                }
              }

              if (isAdmin) {
                if (_currentTab == 0) {
                  return _buildSupportQueueTab(theme);
                } else if (_currentTab == 1) {
                  return _buildAdminSuiteTab(theme, totalRevenue, activeOrders, meals.length);
                } else {
                  return _buildSupportQueueTab(theme);
                }
              } else {
                if (_currentTab == 0) {
                  return _buildOrdersTab(theme, orders);
                } else if (_currentTab == 1) {
                  return _buildMenuTab(theme, meals);
                } else if (_currentTab == 2) {
                  return _buildManagementTab(theme);
                } else if (_currentTab == 3) {
                  return _buildAnalyticsTab(theme, totalRevenue, activeOrders, meals.length);
                } else {
                  return _buildOrdersTab(theme, orders);
                }
              }
            },
          );
        },
      ),

      // Floating Add Meal Action button shown on Menu Tab
      floatingActionButton: (!isAdmin && _currentTab == 1)
          ? FloatingActionButton(
              onPressed: _showAddMealSheet,
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add, size: 26),
            )
          : null,

      // Restaurant Bottom Navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab >= (isAdmin ? 2 : 4) ? 0 : _currentTab,
          onTap: (index) => setState(() => _currentTab = index),
          backgroundColor: theme.scaffoldBackgroundColor,
          selectedItemColor: theme.primaryColor,
          unselectedItemColor: Colors.white30,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: isAdmin
              ? const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.support_agent_outlined),
                    activeIcon: Icon(Icons.support_agent_rounded),
                    label: "Canlı Destek",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.admin_panel_settings_outlined),
                    activeIcon: Icon(Icons.admin_panel_settings_rounded),
                    label: "Yönetici Paneli",
                  ),
                ]
              : const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.delivery_dining_outlined),
                    activeIcon: Icon(Icons.delivery_dining),
                    label: "Siparişler",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.restaurant_menu_outlined),
                    activeIcon: Icon(Icons.restaurant_menu),
                    label: "Menü Kartı",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.storefront_outlined),
                    activeIcon: Icon(Icons.storefront_rounded),
                    label: "Şube/Kupon",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart_outlined),
                    activeIcon: Icon(Icons.bar_chart_rounded),
                    label: "Gelir",
                  ),
                ],
        ),
      ),
    );
  }

  // Builder for Tab 1: Live Order Tickets Management
  Widget _buildOrdersTab(ThemeData theme, List<OrderModel> allOrders) {
    if (allOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            Text(
              "Gelen herhangi bir sipariş bulunmuyor.",
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: allOrders.length,
      itemBuilder: (context, index) {
        final order = allOrders[index];

        // Format visual styles based on order statuses
        Color statusColor = Colors.amber;
        String statusLabel = 'Yeni Sipariş';
        String btnText = 'Hazırlamaya Başla';
        IconData btnIcon = Icons.outdoor_grill_rounded;

        if (order.status == 'preparing') {
          statusColor = Colors.orange;
          statusLabel = 'Hazırlanıyor';
          btnText = 'Kuryeye Teslim Et';
          btnIcon = Icons.delivery_dining_rounded;
        } else if (order.status == 'on_the_way') {
          statusColor = Colors.blueAccent;
          statusLabel = 'Kuryede / Yolda';
          btnText = 'Teslim Edildi İşaretle';
          btnIcon = Icons.done_all_rounded;
        } else if (order.status == 'delivered') {
          statusColor = const Color(0xFF10B981);
          statusLabel = 'Teslim Edildi';
        }

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
              // Ticket Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Müşteri: ${order.customerName}",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "No: #${order.id.length > 8 ? order.id.substring(order.id.length - 6).toUpperCase() : order.id} • ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}",
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  )
                ],
              ),
              const Divider(color: Colors.white10, height: 24),

              // Ordered food lists details
              ...order.items.map((it) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${it.quantity}x ${it.foodItem.name}",
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        "${(it.foodItem.price * it.quantity).toStringAsFixed(0)} TL",
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }),

              const Divider(color: Colors.white10, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Toplam Kazanç",
                    style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                  ),
                  Text(
                    "${order.totalAmount.toStringAsFixed(0)} TL",
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: theme.primaryColor),
                  ),
                ],
              ),

              // Action progression Button (Locked when order status is Delivered)
              if (order.status != 'delivered') ...[
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => _advanceOrderStatus(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(btnIcon, size: 18, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        btnText,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Builder for Tab 2: Menu items inventory card management
  Widget _buildMenuTab(ThemeData theme, List<FoodItem> meals) {
    if (meals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_rounded, size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            Text(
              "Menünüzde herhangi bir yemek bulunmuyor.",
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80), // extra bottom spacing for FAB
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final meal = meals[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Image.network(
                meal.imageUrl,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  color: Colors.white10,
                  width: 90,
                  height: 90,
                  child: const Icon(Icons.fastfood, color: Colors.white24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meal.description,
                        style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${meal.price.toStringAsFixed(0)} TL",
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: theme.primaryColor),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              meal.category,
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                tooltip: "Yemeği Sil",
                onPressed: () => _handleDeleteMeal(meal),
              ),
              const SizedBox(width: 8),
            ],
          ),
        );
      },
    );
  }

  // Builder for Tab 3: Analytics stats & Canvas chart painter
  Widget _buildAnalyticsTab(ThemeData theme, double totalRevenue, int activeCount, int totalMealsCount) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Mali Rapor & Performans",
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),

          // Business Stat Grid Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  "Toplam Ciro",
                  "${totalRevenue.toStringAsFixed(0)} TL",
                  Icons.monetization_on,
                  Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatCard(
                  theme,
                  "Aktif Sipariş",
                  "$activeCount Adet",
                  Icons.hourglass_top,
                  Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  "Menü Çeşitliliği",
                  "$totalMealsCount Yemek",
                  Icons.menu_book,
                  theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatCard(
                  theme,
                  "Müşteri Memnuniyeti",
                  "4.8 / 5.0",
                  Icons.insights_rounded,
                  Colors.pinkAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Glowing neon Custom-Painter weekly sales charts panel
          Text(
            "Haftalık Satış Grafiği (TL)",
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: RevenueLinePainter(
                      color: theme.primaryColor,
                      glowColor: theme.primaryColor.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildChartDay("Pzt"),
                    _buildChartDay("Sal"),
                    _buildChartDay("Çar"),
                    _buildChartDay("Per"),
                    _buildChartDay("Cum"),
                    _buildChartDay("Cmt"),
                    _buildChartDay("Paz"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, String title, String value, IconData icon, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
              ),
              Icon(icon, color: accentColor, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartDay(String day) {
    return Text(
      day,
      style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500),
    );
  }
  Widget _buildUsersTab(ThemeData theme) {
    return StreamBuilder<List<UserModel>>(
      stream: FirebaseService.streamUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator(radius: 12, color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(child: Text("Hata: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
        }

        final users = snapshot.data ?? [];
        final currentUserUid = FirebaseService.currentUser?.uid;

        // Filter out current user from being updated by themselves to prevent accidental lockouts
        final otherUsers = users.where((u) => u.uid != currentUserUid).toList();

        if (otherUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline_rounded, size: 64, color: Colors.white12),
                const SizedBox(height: 16),
                Text(
                  "Sistemde yetkilendirilecek başka kullanıcı bulunmuyor.",
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: otherUsers.length,
          itemBuilder: (context, index) {
            final user = otherUsers[index];
            final String roleText = user.role == 'admin'
                ? 'Admin'
                : user.role == 'restaurant_owner'
                    ? 'Restoran Sahibi'
                    : 'Müşteri';
            
            final Color roleColor = user.role == 'admin'
                ? const Color(0xFFEF4444)
                : user.role == 'restaurant_owner'
                    ? const Color(0xFF10B981)
                    : Colors.white30;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // User avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: roleColor.withValues(alpha: 0.12),
                    ),
                    child: Center(
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: roleColor == Colors.white30 ? Colors.white : roleColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // User details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            roleText,
                            style: GoogleFonts.outfit(
                              fontSize: 10, 
                              fontWeight: FontWeight.bold, 
                              color: roleColor == Colors.white30 ? Colors.white70 : roleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Role modifier PopupMenu
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: theme.primaryColor),
                    color: theme.cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (String newRole) async {
                      final error = await FirebaseService.updateUserRole(user.uid, newRole);
                      if (context.mounted) {
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Hata: $error", style: GoogleFonts.outfit(color: Colors.white)),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("${user.fullName} yetkisi güncellendi!", style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.black)),
                              backgroundColor: theme.primaryColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'customer',
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, size: 18, color: Colors.white54),
                            const SizedBox(width: 10),
                            Text("Müşteri Yap", style: GoogleFonts.outfit(color: Colors.white70)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'restaurant_owner',
                        child: Row(
                          children: [
                            const Icon(Icons.restaurant_menu, size: 18, color: Color(0xFF10B981)),
                            const SizedBox(width: 10),
                            Text("Restoran Sahibi Yap", style: GoogleFonts.outfit(color: Colors.white70)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'admin',
                        child: Row(
                          children: [
                            const Icon(Icons.admin_panel_settings, size: 18, color: Color(0xFFEF4444)),
                            const SizedBox(width: 10),
                            Text("Yönetici (Admin) Yap", style: GoogleFonts.outfit(color: Colors.white70)),
                          ],
                        ),
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

  // ─────────────────────────────────────────
  // BRANCH & PROMOTION & CATEGORIES MANAGEMENT PANEL
  // ─────────────────────────────────────────
  Widget _buildManagementTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Custom neon sliding segmented subtabs
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildSubTabButton("Şubeler", 0),
                _buildSubTabButton("Kuponlar", 1),
                _buildSubTabButton("Kategoriler", 2),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _managementSubTab,
            children: [
              _buildBranchesSubTab(theme),
              _buildDiscountsSubTab(theme),
              _buildCategoriesSubTab(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabButton(String title, int index) {
    final theme = Theme.of(context);
    final isSelected = _managementSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _managementSubTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isSelected ? Colors.black : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }

  // SubTab 0: Branches Management
  Widget _buildBranchesSubTab(ThemeData theme) {
    final user = FirebaseService.currentUser;
    if (user == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Şubelerimiz",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: _showAddBranchSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                label: Text("Şube Ekle", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<RestaurantBranch>>(
            stream: FirebaseService.streamBranches(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator(color: Colors.white));
              }
              final branches = snapshot.data ?? [];
              if (branches.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront_outlined, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        "Henüz eklenmiş bir şube bulunmuyor.",
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: branches.length,
                itemBuilder: (context, idx) {
                  final b = branches[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.location_on_rounded, color: theme.primaryColor, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.name,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                b.address,
                                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white60),
                              ),
                              if (b.phone.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 10, color: Colors.white38),
                                    const SizedBox(width: 4),
                                    Text(
                                      b.phone,
                                      style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38),
                                    ),
                                  ],
                                )
                              ]
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () => _handleDeleteBranch(b),
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

  void _showAddBranchSheet() {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AnimatedPadding(
              padding: MediaQuery.of(context).viewInsets,
              duration: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.add_location_alt_rounded, color: theme.primaryColor, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              "Yeni Şube Ekle",
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        TextFormField(
                          controller: nameCtrl,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: "Şube Adı",
                            prefixIcon: Icon(Icons.storefront, size: 18, color: Colors.white54),
                            hintText: "Örn: Kadıköy Şubesi",
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? "Şube adı boş olamaz" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addrCtrl,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: "Şube Adresi",
                            prefixIcon: Icon(Icons.map_outlined, size: 18, color: Colors.white54),
                            hintText: "Örn: Caferağa Mah. Moda Cad. No:12",
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? "Şube adresi boş olamaz" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: "İrtibat Telefonu",
                            prefixIcon: Icon(Icons.phone_outlined, size: 18, color: Colors.white54),
                            hintText: "Örn: 02163456789",
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final user = FirebaseService.currentUser;
                            if (user == null) return;

                            final newBranch = RestaurantBranch(
                              id: '',
                              name: nameCtrl.text.trim(),
                              address: addrCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              isActive: true,
                            );

                            final err = await FirebaseService.saveBranch(user.uid, newBranch);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              if (err != null) {
                                _showFeedbackDialog("Hata", "Şube eklenemedi: $err", isError: true);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Şube başarıyla eklendi!", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                                    backgroundColor: theme.primaryColor,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text("Şubeyi Kaydet"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleDeleteBranch(RestaurantBranch b) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Şubeyi Sil", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text("${b.name} şubesini silmek istediğinize emin misiniz?", style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final user = FirebaseService.currentUser;
      if (user != null) {
        final err = await FirebaseService.deleteBranch(user.uid, b.id);
        if (err != null && mounted) {
          _showFeedbackDialog("Hata", "Şube silinemedi: $err", isError: true);
        }
      }
    }
  }

  // SubTab 1: Coupons Management
  Widget _buildDiscountsSubTab(ThemeData theme) {
    final user = FirebaseService.currentUser;
    if (user == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "İndirim Kuponları",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: _showAddDiscountSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.qr_code_rounded, size: 16),
                label: Text("Kupon Oluştur", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<DiscountCode>>(
            stream: FirebaseService.streamDiscountCodes(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator(color: Colors.white));
              }
              final codes = snapshot.data ?? [];
              if (codes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.confirmation_number_outlined, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        "Henüz eklenmiş indirim kuponu bulunmuyor.",
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: codes.length,
                itemBuilder: (context, idx) {
                  final c = codes[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            c.typeLabel,
                            style: GoogleFonts.outfit(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    c.code,
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white, letterSpacing: 1),
                                  ),
                                  const SizedBox(width: 8),
                                  if (c.stackable)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Birleşebilir",
                                        style: GoogleFonts.outfit(fontSize: 8, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orangeAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Tekil",
                                        style: GoogleFonts.outfit(fontSize: 8, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                c.minimumOrderAmount > 0
                                    ? "Alt Sınır: ${c.minimumOrderAmount.toStringAsFixed(0)} TL • Şube: ${c.branchName}"
                                    : "Alt Sınır Yok • Şube: ${c.branchName}",
                                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () => _handleDeleteDiscount(c),
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

  void _showAddDiscountSheet() {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final minAmountCtrl = TextEditingController(text: '0');
    
    DiscountType selectedType = DiscountType.percentage;
    bool isStackable = false;
    RestaurantBranch? selectedBranch;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AnimatedPadding(
              padding: MediaQuery.of(context).viewInsets,
              duration: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.add_card_rounded, color: theme.primaryColor, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              "Yeni İndirim Kodu Oluştur",
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        
                        TextFormField(
                          controller: codeCtrl,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: "Kupon Kodu",
                            prefixIcon: Icon(Icons.qr_code, size: 18, color: Colors.white54),
                            hintText: "Örn: KEBAP20",
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? "Kupon kodu boş olamaz" : null,
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: Text("Yüzdelik (%)", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: selectedType == DiscountType.percentage ? Colors.black : Colors.white70)),
                                selected: selectedType == DiscountType.percentage,
                                selectedColor: theme.primaryColor,
                                onSelected: (val) {
                                  if (val) setModalState(() => selectedType = DiscountType.percentage);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ChoiceChip(
                                label: Text("Sabit (TL)", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: selectedType == DiscountType.flatAmount ? Colors.black : Colors.white70)),
                                selected: selectedType == DiscountType.flatAmount,
                                selectedColor: theme.primaryColor,
                                onSelected: (val) {
                                  if (val) setModalState(() => selectedType = DiscountType.flatAmount);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: valueCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: selectedType == DiscountType.percentage ? "İndirim Yüzdesi (%)" : "İndirim Tutarı (TL)",
                            prefixIcon: const Icon(Icons.percent_rounded, size: 18, color: Colors.white54),
                            hintText: selectedType == DiscountType.percentage ? "Örn: 15" : "Örn: 50",
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Tutar/Yüzde boş olamaz";
                            final numVal = double.tryParse(v);
                            if (numVal == null || numVal <= 0) return "Geçerli bir değer girin";
                            if (selectedType == DiscountType.percentage && numVal > 100) return "Yüzde 100'den büyük olamaz";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: minAmountCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: "Minimum Sipariş Tutarı (Alt Sınır - TL)",
                            prefixIcon: Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.white54),
                            hintText: "Örn: 100 (Bu tutarın altındaki sepetlere uygulanmaz)",
                          ),
                          validator: (v) {
                            if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                              return "Lütfen geçerli bir tutar girin";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        StreamBuilder<List<RestaurantBranch>>(
                          stream: FirebaseService.streamBranches(FirebaseService.currentUser?.uid ?? ''),
                          builder: (context, branchSnap) {
                            final branches = branchSnap.data ?? [];
                            return Theme(
                              data: theme.copyWith(canvasColor: theme.cardColor),
                              child: DropdownButtonFormField<RestaurantBranch?>(
                                value: selectedBranch,
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  labelText: "Geçerli Olacağı Şube",
                                  prefixIcon: Icon(Icons.location_city_rounded, size: 18, color: Colors.white54),
                                ),
                                items: [
                                  DropdownMenuItem<RestaurantBranch?>(
                                    value: null,
                                    child: Text("Tüm Şubeler", style: GoogleFonts.outfit(color: Colors.white)),
                                  ),
                                  ...branches.map((b) => DropdownMenuItem<RestaurantBranch?>(
                                        value: b,
                                        child: Text(b.name, style: GoogleFonts.outfit(color: Colors.white)),
                                      )),
                                ],
                                onChanged: (val) {
                                  setModalState(() => selectedBranch = val);
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text("Diğer Kuponlarla Birleşsin", style: GoogleFonts.outfit(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text("Bu kupon başka kuponlarla aynı siparişte kullanılabilir mi?", style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38)),
                          value: isStackable,
                          activeColor: theme.primaryColor,
                          onChanged: (val) => setModalState(() => isStackable = val),
                        ),

                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final user = FirebaseService.currentUser;
                            if (user == null) return;

                            final newCode = DiscountCode(
                              id: '',
                              code: codeCtrl.text.trim().toUpperCase(),
                              type: selectedType,
                              value: double.parse(valueCtrl.text.trim()),
                              restaurantOwnerId: user.uid,
                              branchId: selectedBranch?.id,
                              branchName: selectedBranch?.name ?? 'Tüm Şubeler',
                              minimumOrderAmount: double.parse(minAmountCtrl.text.trim()),
                              stackable: isStackable,
                              isActive: true,
                            );

                            final err = await FirebaseService.saveDiscountCode(newCode);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              if (err != null) {
                                _showFeedbackDialog("Hata", "Kupon oluşturulamadı: $err", isError: true);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Kupon başarıyla oluşturuldu!", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                                    backgroundColor: theme.primaryColor,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text("Kuponu Yayınla"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleDeleteDiscount(DiscountCode c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Kuponu Sil", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text("${c.code} kodlu kuponu silmek istediğinize emin misiniz?", style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final err = await FirebaseService.deleteDiscountCode(c.id);
      if (err != null && mounted) {
        _showFeedbackDialog("Hata", "Kupon silinemedi: $err", isError: true);
      }
    }
  }

  // SubTab 2: Categories Management
  Widget _buildCategoriesSubTab(ThemeData theme) {
    final categoryCtrl = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Yemek Kategorileri",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: categoryCtrl,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: "Yeni Kategori Adı",
                        prefixIcon: Icon(Icons.category, size: 18, color: Colors.white54),
                        hintText: "Örn: Dönerler",
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final name = categoryCtrl.text.trim();
                      if (name.isEmpty) return;
                      final err = await FirebaseService.addCategory(name);
                      if (err != null) {
                        _showFeedbackDialog("Hata", "Kategori eklenemedi: $err", isError: true);
                      } else {
                        categoryCtrl.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Kategori başarıyla eklendi!", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                            backgroundColor: theme.primaryColor,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("Ekle", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<String>>(
            stream: FirebaseService.streamCategories(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator(color: Colors.white));
              }
              final cats = snapshot.data ?? ["Çorba", "Ana Yemek", "Tatlı", "İçecek"];
              if (cats.isEmpty) {
                return Center(
                  child: Text(
                    "Henüz eklenmiş bir kategori bulunmuyor.",
                    style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: cats.length,
                itemBuilder: (context, idx) {
                  final cat = cats[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.label_important_outline_rounded, color: theme.primaryColor, size: 18),
                            const SizedBox(width: 12),
                            Text(
                              cat,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: theme.cardColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text("Kategoriyi Sil", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                                content: Text("$cat kategorisini silmek istediğinize emin misiniz?", style: GoogleFonts.outfit(color: Colors.white70)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Vazgeç")),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                    child: const Text("Sil"),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final err = await FirebaseService.deleteCategory(cat);
                              if (err != null && mounted) {
                                _showFeedbackDialog("Hata", "Kategori silinemedi: $err", isError: true);
                              }
                            }
                          },
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

  // ─────────────────────────────────────────
  // LIVE CHAT SUPPORT QUEUE TICKET DESK
  // ─────────────────────────────────────────
  Widget _buildSupportQueueTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _supportQueueSubTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _supportQueueSubTab == 0 ? theme.primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Bekleyen Destekler",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _supportQueueSubTab == 0 ? Colors.black : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _supportQueueSubTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _supportQueueSubTab == 1 ? theme.primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Geçmiş Görüşmeler",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _supportQueueSubTab == 1 ? Colors.black : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<List<ChatSession>>(
            stream: FirebaseService.streamChatSessions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator(color: Colors.white));
              }
              final allSessions = snapshot.data ?? [];
              final filtered = allSessions.where((s) {
                if (_supportQueueSubTab == 0) {
                  return s.status == 'waiting' || s.status == 'active';
                } else {
                  return s.status == 'closed';
                }
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.support_agent_rounded, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        _supportQueueSubTab == 0
                            ? "Bekleyen destek çağrısı bulunmuyor."
                            : "Geçmiş herhangi bir görüşme bulunmuyor.",
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: filtered.length,
                itemBuilder: (context, idx) {
                  final s = filtered[idx];
                  final isCurrentAgentClaimant = s.assignedAgentId == FirebaseService.currentUser?.uid;
                  
                  Color glowColor = Colors.orangeAccent;
                  String statusText = "Müşteri Bekliyor...";
                  if (s.status == 'active') {
                    glowColor = Colors.greenAccent;
                    statusText = "Destek Sürüyor • Yetkili: ${s.assignedAgentName}";
                  } else if (s.status == 'closed') {
                    glowColor = Colors.grey;
                    statusText = "Görüşme Tamamlandı";
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: glowColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              statusText,
                              style: GoogleFonts.outfit(color: glowColor, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            const Spacer(),
                            Text(
                              "${s.createdAt.hour.toString().padLeft(2, '0')}:${s.createdAt.minute.toString().padLeft(2, '0')}",
                              style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.customerName,
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (s.lastMessage.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            s.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white60),
                          ),
                        ],
                        if (s.status != 'closed') ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () async {
                              if (s.status == 'waiting') {
                                final err = await FirebaseService.claimChatSession(s.id);
                                if (err != null) {
                                  _showFeedbackDialog("Bağlantı Hatası", "Görüşme başka yetkili tarafından alındı.", isError: true);
                                } else {
                                  if (context.mounted) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => LiveSupportScreen(session: s)),
                                    );
                                  }
                                }
                              } else if (s.status == 'active') {
                                if (isCurrentAgentClaimant) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => LiveSupportScreen(session: s)),
                                  );
                                } else {
                                  _showFeedbackDialog("Erişim Reddedildi", "Bu destek görüşmesini başka bir yetkili devraldı.", isError: true);
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: s.status == 'waiting'
                                  ? theme.primaryColor
                                  : (isCurrentAgentClaimant ? Colors.greenAccent : Colors.grey.withValues(alpha: 0.2)),
                              foregroundColor: s.status == 'waiting' ? Colors.black : Colors.white,
                              minimumSize: const Size(double.infinity, 42),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              s.status == 'waiting'
                                  ? "Görüşmeyi Başlat"
                                  : (isCurrentAgentClaimant ? "Görüşmeye Geri Dön" : "Başka Yetkili İlgileniyor"),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: s.status == 'waiting' ? Colors.black : Colors.white),
                            ),
                          ),
                        ],
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

  // ─────────────────────────────────────────
  // ADMIN CONSOLE SUITE FOR POWER USERS
  // ─────────────────────────────────────────
  Widget _buildAdminSuiteTab(ThemeData theme, double totalRevenue, int activeOrders, int mealsCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _adminSuiteSubTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _adminSuiteSubTab == 0 ? theme.primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Mali Rapor & Analiz",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _adminSuiteSubTab == 0 ? Colors.black : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _adminSuiteSubTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _adminSuiteSubTab == 1 ? theme.primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Kullanıcı Yetkileri",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _adminSuiteSubTab == 1 ? Colors.black : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: IndexedStack(
            index: _adminSuiteSubTab,
            children: [
              _buildAnalyticsTab(theme, totalRevenue, activeOrders, mealsCount),
              _buildUsersTab(theme),
            ],
          ),
        ),
      ],
    );
  }
}

// Canvas Painter drawing a gorgeous, cubic-spline analytics chart with neon drop shadow
class RevenueLinePainter extends CustomPainter {
  final Color color;
  final Color glowColor;

  RevenueLinePainter({required this.color, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw horizontal background grids
    for (int i = 1; i <= 4; i++) {
      double y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Weekly mock coordinate ratios
    final List<double> values = [0.25, 0.40, 0.35, 0.65, 0.50, 0.85, 0.70];
    final List<Offset> points = [];

    final double stepX = size.width / (values.length - 1);
    for (int i = 0; i < values.length; i++) {
      double x = i * stepX;
      double y = size.height * (1.0 - values[i]);
      points.add(Offset(x, y));
    }

    // Draw splines path
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    // Draw glowing under-shadow gradient
    final shadowPath = Path.from(path);
    shadowPath.lineTo(size.width, size.height);
    shadowPath.lineTo(0, size.height);
    shadowPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [glowColor.withValues(alpha: 0.4), glowColor.withValues(alpha: 0.01)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(shadowPath, fillPaint);

    // Draw the main spline line
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Draw glowing circles on nodes
    final dotPaint = Paint()..color = color;
    final outerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var pt in points) {
      canvas.drawCircle(pt, 5, dotPaint);
      canvas.drawCircle(pt, 5, outerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
