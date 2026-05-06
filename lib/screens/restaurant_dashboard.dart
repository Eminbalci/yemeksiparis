import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';

class RestaurantDashboard extends StatefulWidget {
  const RestaurantDashboard({super.key});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  int _currentTab = 0; // 0: Orders, 1: Menu, 2: Analytics

  // New Meal Form controllers
  final _addMealFormKey = GlobalKey<FormState>();
  final _mealNameController = TextEditingController();
  final _mealDescController = TextEditingController();
  final _mealPriceController = TextEditingController();
  final _mealImageController = TextEditingController();
  String _selectedCategory = "Kebaplar";

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
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                            Theme(
                              data: Theme.of(context).copyWith(canvasColor: Theme.of(context).cardColor),
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                                decoration: const InputDecoration(
                                  labelText: "Kategori",
                                  prefixIcon: Icon(Icons.category_outlined, size: 18, color: Colors.white54),
                                ),
                                icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).primaryColor),
                                items: _categories.map((String val) {
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

              if (_currentTab == 0) {
                return _buildOrdersTab(theme, orders);
              } else if (_currentTab == 1) {
                return _buildMenuTab(theme, meals);
              } else {
                return _buildAnalyticsTab(theme, totalRevenue, activeOrders, meals.length);
              }
            },
          );
        },
      ),

      // Floating Add Meal Action button shown on Menu Tab
      floatingActionButton: _currentTab == 1
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
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: "Gelir Analizi",
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
            border: Border.all(color: Colors.white.withOpacity(0.04)),
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
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
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
            border: Border.all(color: Colors.white.withOpacity(0.04)),
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
                              color: theme.colorScheme.secondary.withOpacity(0.12),
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
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: RevenueLinePainter(
                      color: theme.primaryColor,
                      glowColor: theme.primaryColor.withOpacity(0.4),
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
        border: Border.all(color: Colors.white.withOpacity(0.04)),
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
}

// Canvas Painter drawing a gorgeous, cubic-spline analytics chart with neon drop shadow
class RevenueLinePainter extends CustomPainter {
  final Color color;
  final Color glowColor;

  RevenueLinePainter({required this.color, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
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
        colors: [glowColor.withOpacity(0.4), glowColor.withOpacity(0.01)],
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
