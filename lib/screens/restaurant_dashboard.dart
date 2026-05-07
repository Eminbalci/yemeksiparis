import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/location_api_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'customer_dashboard.dart';
import 'live_support_screen.dart';

class RestaurantDashboard extends StatefulWidget {
  final int initialTab;
  const RestaurantDashboard({super.key, this.initialTab = 0});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  late int _currentTab;
  int _managementSubTab = 0;   // 0: Şubeler, 1: İndirim Kodları, 2: Kategoriler
  int _supportQueueSubTab = 0; // 0: Aktif Sohbetler, 1: Geçmiş
  int _adminSuiteSubTab = 0;   // 0: Performans Analizi, 1: Yetki Kontrolleri

  // New Meal Form controllers
  final _addMealFormKey = GlobalKey<FormState>();
  final _mealNameController = TextEditingController();
  final _mealDescController = TextEditingController();
  final _mealPriceController = TextEditingController();
  final _mealImageController = TextEditingController();
  final _mealStockController = TextEditingController();
  String _selectedCategory = "Çorba";
  String _userSearchQuery = "";

  // Profile controllers
  late final TextEditingController _profileNameCtrl;
  late final TextEditingController _profileRestNameCtrl;
  late final TextEditingController _profileRestAddressCtrl;
  late final TextEditingController _profilePhoneCtrl;
  late final TextEditingController _profileMinOrderCtrl;
  late final TextEditingController _profileLogoCtrl;
  late final TextEditingController _profileDescCtrl;
  late final TextEditingController _profileMaxDistanceCtrl;

  // Support notifications stream subscription
  StreamSubscription<List<ChatSession>>? _chatSessionsSubscription;
  final Set<String> _notifiedSessionIds = {};

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    final user = FirebaseService.currentUser;
    _profileNameCtrl = TextEditingController(text: user?.fullName ?? "");
    _profileRestNameCtrl = TextEditingController(text: user?.restaurantName ?? "");
    _profileRestAddressCtrl = TextEditingController(text: user?.restaurantAddress ?? "");
    _profilePhoneCtrl = TextEditingController(text: user?.phone ?? "");
    _profileMinOrderCtrl = TextEditingController(text: user?.minOrderAmount.toStringAsFixed(0) ?? "0");
    _profileLogoCtrl = TextEditingController(text: user?.restaurantLogo ?? "");
    _profileDescCtrl = TextEditingController(text: user?.restaurantDescription ?? "");
    _profileMaxDistanceCtrl = TextEditingController(text: user?.maxDeliveryDistance.toStringAsFixed(1) ?? "5.0");

    // Live support session stream for notifications - restricted to support and support_manager roles (excludes admins)
    if (user != null && (user.role == 'support' || user.role == 'support_manager')) {
      _chatSessionsSubscription = FirebaseService.streamChatSessions().listen((sessions) {
        for (var s in sessions) {
          if (s.isWaiting && (s.assignedAgentId == null || s.assignedAgentId!.isEmpty)) {
            if (!_notifiedSessionIds.contains(s.id)) {
              _notifiedSessionIds.add(s.id);
              _showSupportNotification(s);
              
              // Trigger system background native notification!
              NotificationService.showLocalNotification(
                id: s.id.hashCode,
                title: "Yeni Canlı Destek Talebi! 💬",
                body: "${s.customerName} yardım bekliyor. Hemen yanıtlayın.",
                payload: 'support',
              ).catchError((e) => debugPrint('Local notification error: $e'));
            }
          }
        }
      });
    }
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {});
    }
  }

  void _showSupportNotification(ChatSession session) {
    if (!mounted) return;
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: _AnimatedSupportNotificationToast(
              title: "Yeni Canlı Destek Talebi! 💬",
              desc: "${session.customerName} yardım bekliyor. Hemen yanıtlayın.",
              icon: Icons.chat_bubble_outline_rounded,
              color: const Color(0xFF10B981),
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
    _chatSessionsSubscription?.cancel();
    _mealNameController.dispose();
    _mealDescController.dispose();
    _mealPriceController.dispose();
    _mealImageController.dispose();
    _mealStockController.dispose();
    _profileNameCtrl.dispose();
    _profileRestNameCtrl.dispose();
    _profileRestAddressCtrl.dispose();
    _profilePhoneCtrl.dispose();
    _profileMinOrderCtrl.dispose();
    _profileLogoCtrl.dispose();
    _profileDescCtrl.dispose();
    _profileMaxDistanceCtrl.dispose();
    super.dispose();
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

  // Show "Yeni Yemek Ekle" panel
  void _showMealSheet([FoodItem? editMeal]) {
    bool isAvailable = editMeal != null ? editMeal.stock > 0 : true;
    if (editMeal != null) {
      _mealNameController.text = editMeal.name;
      _mealDescController.text = editMeal.description;
      _mealPriceController.text = editMeal.price.toStringAsFixed(0);
      _mealImageController.text = editMeal.imageUrl;
      _mealStockController.text = editMeal.stock.toString();
      _selectedCategory = editMeal.category;
    } else {
      _mealNameController.clear();
      _mealDescController.clear();
      _mealPriceController.clear();
      _mealImageController.clear();
      _mealStockController.text = "99";
      _selectedCategory = "Kebaplar";
    }

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
                height: MediaQuery.of(context).size.height * 0.8,
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
                          Icon(
                            editMeal != null ? Icons.edit_note_rounded : Icons.add_moderator_outlined, 
                            color: Theme.of(context).primaryColor, 
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            editMeal != null ? "Yemeği Düzenle" : "Yeni Yemek Ekle",
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

                            // Stock Level (Stok Var / Yok)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                        color: isAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Stok Durumu",
                                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        isAvailable ? "Stok Var" : "Stok Yok",
                                        style: GoogleFonts.outfit(
                                          color: isAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      CupertinoSwitch(
                                        value: isAvailable,
                                        activeTrackColor: const Color(0xFF10B981),
                                        inactiveTrackColor: Colors.white10,
                                        onChanged: (val) {
                                          setModalState(() {
                                            isAvailable = val;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
                                    initialValue: dynCats.contains(_selectedCategory) ? _selectedCategory : (dynCats.isNotEmpty ? dynCats.first : null),
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
                        onPressed: () {
                          if (editMeal != null) {
                            _handleEditMeal(context, editMeal, isAvailable);
                          } else {
                            _handleAddNewMeal(context, isAvailable);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(editMeal != null ? "Değişiklikleri Kaydet" : "Menüye Ekle"),
                            const SizedBox(width: 8),
                            Icon(editMeal != null ? Icons.save_rounded : Icons.restaurant, size: 18),
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
  Future<void> _handleAddNewMeal(BuildContext modalContext, bool isAvailable) async {
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
    final stock = isAvailable ? 99 : 0;

    final FoodItem newMeal = FoodItem(
      id: '',
      name: name,
      description: desc,
      price: price,
      imageUrl: img,
      category: _selectedCategory,
      rating: 4.8,
      stock: stock,
      restaurantOwnerId: FirebaseService.currentUser?.uid ?? '',
    );

    final error = await FirebaseService.addFoodItem(newMeal);
    
    if (mounted) Navigator.of(context).pop(); // Dismiss spinner

    if (error != null) {
      _showFeedbackDialog("Menü Hatası", "Yemek eklenirken sorun oluştu: $error", isError: true);
    } else {
      _showFeedbackDialog("Başarılı!", "$name menünüze başarıyla eklendi.", isError: false);
    }
  }

  // Handle editing meal
  Future<void> _handleEditMeal(BuildContext modalContext, FoodItem oldMeal, bool isAvailable) async {
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
    final stock = isAvailable ? 99 : 0;

    final FoodItem updatedMeal = FoodItem(
      id: oldMeal.id,
      name: name,
      description: desc,
      price: price,
      imageUrl: img,
      category: _selectedCategory,
      rating: oldMeal.rating,
      stock: stock,
      restaurantOwnerId: oldMeal.restaurantOwnerId,
    );

    final error = await FirebaseService.updateFoodItem(updatedMeal);
    
    if (mounted) Navigator.of(context).pop(); // Dismiss spinner

    if (error != null) {
      _showFeedbackDialog("Menü Hatası", "Yemek güncellenirken sorun oluştu: $error", isError: true);
    } else {
      _showFeedbackDialog("Başarılı!", "$name başarıyla güncellendi.", isError: false);
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

  Future<void> _pickLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _profileLogoCtrl.text = image.path;
        });
        if (!mounted) return;
        final primaryCol = Theme.of(context).primaryColor;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Restoran logosu seçildi!", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
            backgroundColor: primaryCol,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showFeedbackDialog("Görsel Seçim Hatası", e.toString(), isError: true);
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
      message = order.isTakeaway
          ? "Sipariş hazırlandı, müşteri teslim alabilir!"
          : "Sipariş kuryeye teslim edildi, yolda!";
    } else if (order.status == 'on_the_way') {
      nextStatus = 'delivered';
      message = order.isTakeaway
          ? "Sipariş müşteriye elden teslim edildi!"
          : "Sipariş müşteriye başarıyla ulaştırıldı!";
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
    if (FirebaseService.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CupertinoActivityIndicator(radius: 12, color: Colors.white),
        ),
      );
    }
    final theme = Theme.of(context);
    final bool isAdmin = FirebaseService.currentUser?.role == 'admin';
    final bool isSupport = FirebaseService.currentUser?.role == 'support';
    final bool isSupportManager = FirebaseService.currentUser?.role == 'support_manager';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard_customize_rounded, color: theme.primaryColor, size: 24),
            const SizedBox(width: 8),
            Text(
              isSupport
                  ? "Destek Yetkilisi Paneli"
                  : (isSupportManager
                      ? "Destek Yöneticisi Paneli"
                      : (isAdmin ? "Yönetim Paneli" : "Restoran Paneli")),
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
          if (!isAdmin && !isSupport && !isSupportManager)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_rounded, color: Colors.amber, size: 22),
                  tooltip: "Sepete Git",
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const CustomerDashboard(showCart: true)),
                      (route) => false,
                    );
                  },
                ),
                if (CartManager.itemCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        "${CartManager.itemCount}",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
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
              if (orderSnapshot.connectionState == ConnectionState.waiting ||
                  foodSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator(radius: 12, color: Colors.white));
              }

              final orders = orderSnapshot.data ?? [];
              final meals = foodSnapshot.data ?? [];

              // Calculate metrics on the fly!
              double platformRevenue = 0.0;
              double restaurantRevenue = 0.0;
              for (var o in orders) {
                if (o.status == 'delivered') {
                  platformRevenue += o.totalAmount * 0.20; // 20% platform commission fee
                  restaurantRevenue += o.totalAmount * 0.80; // 80% restaurant owner revenue
                }
              }

              final int activeOrders = orders.where((o) => o.status != 'delivered').length;

              final isPendingApproval = !isAdmin && !isSupport && !isSupportManager && FirebaseService.currentUser?.status == 'pending_approval';

              Widget mainContent;
              if (isSupport) {
                mainContent = _buildSupportQueueTab(theme);
              } else if (isAdmin || isSupportManager) {
                if (_currentTab == 0) {
                  mainContent = _buildSupportQueueTab(theme);
                } else if (_currentTab == 1) {
                  mainContent = _buildAdminSuiteTab(theme, platformRevenue, activeOrders, meals.length, orders);
                } else {
                  mainContent = _buildSupportQueueTab(theme);
                }
              } else {
                if (_currentTab == 0) {
                  mainContent = _buildOrdersTab(theme, orders);
                } else if (_currentTab == 1) {
                  mainContent = _buildMenuTab(theme, meals);
                } else if (_currentTab == 2) {
                  mainContent = _buildManagementTab(theme);
                } else if (_currentTab == 3) {
                  mainContent = _buildAnalyticsTab(theme, restaurantRevenue, activeOrders, meals.length, orders);
                } else {
                  mainContent = _buildOrdersTab(theme, orders);
                }
              }

              if (isPendingApproval) {
                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                        ),
                        border: const Border(
                          bottom: BorderSide(color: Color(0xFFFBBF24), width: 1.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Restoranınız Onay Aşamasında!",
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Menünüzü hazırlayabilirsiniz, ancak onaylanana kadar restoranınız müşterilere listelenmeyecektir.",
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: mainContent),
                  ],
                );
              }

              return mainContent;
            },
          );
        },
      ),

      // Floating Add Meal Action button shown on Menu Tab
      floatingActionButton: (!isAdmin && !isSupport && _currentTab == 1)
          ? FloatingActionButton(
              onPressed: () => _showMealSheet(),
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add, size: 26),
            )
          : null,

      bottomNavigationBar: isSupport
          ? null
          : Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentTab >= ((isAdmin || isSupportManager) ? 2 : 4) ? 0 : _currentTab,
                onTap: (index) => setState(() => _currentTab = index),
                backgroundColor: theme.scaffoldBackgroundColor,
                selectedItemColor: theme.primaryColor,
                unselectedItemColor: Colors.white30,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedLabelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11),
                type: BottomNavigationBarType.fixed,
                items: (isAdmin || isSupportManager)
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

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: theme.primaryColor,
      backgroundColor: theme.cardColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
          btnText = order.isTakeaway ? 'Hazırlandı Olarak İşaretle' : 'Kuryeye Teslim Et';
          btnIcon = order.isTakeaway ? Icons.shopping_bag_rounded : Icons.delivery_dining_rounded;
        } else if (order.status == 'on_the_way') {
          statusColor = Colors.blueAccent;
          statusLabel = order.isTakeaway ? 'Hazırlandı / Bekliyor' : 'Kuryede / Yolda';
          btnText = order.isTakeaway ? 'Elden Teslim Edildi' : 'Teslim Edildi İşaretle';
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Müşteri: ${order.customerName}",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "No: #${order.id.length > 8 ? order.id.substring(order.id.length - 6).toUpperCase() : order.id} • ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}",
                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
              ] else ...[
                // Display rating on restaurant panel if rated
                if (order.rating != null) ...[
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Müşteri Puanı:",
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Row(
                        children: List.generate(5, (starIndex) {
                          return Icon(
                            Icons.star_rounded,
                            color: starIndex < order.rating! ? const Color(0xFFFFB020) : Colors.white10,
                            size: 20,
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        );
      },
    ),
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: meal.stock > 0 ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFFEF4444).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  meal.stock > 0 ? "Stok: ${meal.stock}" : "Tükendi",
                                  style: GoogleFonts.outfit(
                                    fontSize: 9, 
                                    fontWeight: FontWeight.bold, 
                                    color: meal.stock > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: theme.primaryColor, size: 21),
                tooltip: "Yemeği Düzenle",
                onPressed: () => _showMealSheet(meal),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 21),
                tooltip: "Yemeği Sil",
                onPressed: () => _handleDeleteMeal(meal),
              ),
              const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab(ThemeData theme, double totalRevenue, int activeCount, int totalMealsCount, List<OrderModel> orders) {
    final bool isAdmin = FirebaseService.currentUser?.role == 'admin';
    final double factor = isAdmin ? 0.20 : 0.80;

    // Calculate actual delivered orders earnings for each day of the week (Monday to Sunday)
    final List<double> dailyEarnings = List.filled(7, 0.0);
    for (var o in orders) {
      if (o.status == 'delivered') {
        final int weekday = o.createdAt.weekday; // 1: Monday, 7: Sunday
        dailyEarnings[weekday - 1] += o.totalAmount * factor;
      }
    }

    // Find the max earning to scale ratios realistically between 0.15 and 0.85
    double maxEarning = 0.0;
    for (var val in dailyEarnings) {
      if (val > maxEarning) maxEarning = val;
    }

    final List<double> ratios = List.filled(7, 0.0);
    for (int i = 0; i < 7; i++) {
      if (maxEarning > 0) {
        ratios[i] = 0.15 + (dailyEarnings[i] / maxEarning) * 0.70;
      } else {
        ratios[i] = 0.15; // default flat bottom baseline if no data
      }
    }

    // Calculate actual average satisfaction rating of rated orders
    double averageSatisfaction = 5.0; // Default if no ratings exist yet
    int ratedCount = 0;
    double ratingSum = 0.0;
    for (var o in orders) {
      if (o.rating != null) {
        ratingSum += o.rating!;
        ratedCount++;
      }
    }
    if (ratedCount > 0) {
      averageSatisfaction = ratingSum / ratedCount;
    }

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
                  "${averageSatisfaction.toStringAsFixed(1)} / 5.0",
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
                      ratios: ratios,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildChartDay("Pzt", dailyEarnings[0]),
                    _buildChartDay("Sal", dailyEarnings[1]),
                    _buildChartDay("Çar", dailyEarnings[2]),
                    _buildChartDay("Per", dailyEarnings[3]),
                    _buildChartDay("Cum", dailyEarnings[4]),
                    _buildChartDay("Cmt", dailyEarnings[5]),
                    _buildChartDay("Paz", dailyEarnings[6]),
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

  Widget _buildChartDay(String day, double earning) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          day,
          style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          earning > 0 ? "${earning.toStringAsFixed(0)} TL" : "0 TL",
          style: GoogleFonts.outfit(
            fontSize: 9,
            color: earning > 0 ? const Color(0xFFFF9F43) : Colors.white24,
            fontWeight: earning > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
  void _showEditUserSheet(UserModel user) {
    final theme = Theme.of(context);
    final nameCtrl = TextEditingController(text: user.fullName);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone);
    final addressCtrl = TextEditingController(text: user.address);
    final restNameCtrl = TextEditingController(text: user.restaurantName);
    final restAddressCtrl = TextEditingController(text: user.restaurantAddress);
    final minOrderCtrl = TextEditingController(text: user.minOrderAmount.toStringAsFixed(0));
    String selectedRole = user.role;
    String selectedStatus = user.status.isNotEmpty ? user.status : 'active';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bool isRestOwner = selectedRole == 'restaurant_owner';
            return Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
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
                        Icon(Icons.manage_accounts_rounded, color: theme.primaryColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          "Kullanıcı Profilini Düzenle",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: nameCtrl,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: "Ad Soyad",
                        prefixIcon: Icon(Icons.person, size: 18, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: emailCtrl,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: "E-posta",
                        prefixIcon: Icon(Icons.email, size: 18, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: phoneCtrl,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: "Telefon Numarası",
                        prefixIcon: Icon(Icons.phone, size: 18, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: addressCtrl,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: "Teslimat Adresi",
                        prefixIcon: Icon(Icons.location_on, size: 18, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedRole,
                            isExpanded: true,
                            dropdownColor: theme.cardColor,
                            decoration: const InputDecoration(
                              labelText: "Rol",
                              prefixIcon: Icon(Icons.shield, size: 16, color: Colors.white54),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem(value: 'customer', child: Text('Müşteri', style: TextStyle(color: Colors.white, fontSize: 12))),
                              const DropdownMenuItem(value: 'support', child: Text('Canlı Destek', style: TextStyle(color: Colors.white, fontSize: 12))),
                              const DropdownMenuItem(value: 'support_manager', child: Text('Destek Yöneticisi', style: TextStyle(color: Colors.white, fontSize: 12))),
                              if (FirebaseService.currentUser?.role == 'admin') ...[
                                const DropdownMenuItem(value: 'restaurant_owner', child: Text('Restoran', style: TextStyle(color: Colors.white, fontSize: 12))),
                                const DropdownMenuItem(value: 'admin', child: Text('Admin', style: TextStyle(color: Colors.white, fontSize: 12))),
                              ] else ...[
                                if (selectedRole == 'restaurant_owner')
                                  const DropdownMenuItem(value: 'restaurant_owner', enabled: false, child: Text('Restoran (Yetkiniz Yok)', style: TextStyle(color: Colors.white38, fontSize: 12))),
                                if (selectedRole == 'admin')
                                  const DropdownMenuItem(value: 'admin', enabled: false, child: Text('Admin (Yetkiniz Yok)', style: TextStyle(color: Colors.white38, fontSize: 12))),
                              ]
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() => selectedRole = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedStatus,
                            isExpanded: true,
                            dropdownColor: theme.cardColor,
                            decoration: const InputDecoration(
                              labelText: "Durum",
                              prefixIcon: Icon(Icons.info_outline, size: 16, color: Colors.white54),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'active', child: Text('Aktif', style: TextStyle(color: Colors.white, fontSize: 12))),
                              DropdownMenuItem(value: 'suspended', child: Text('Askıda', style: TextStyle(color: Colors.white, fontSize: 12))),
                              DropdownMenuItem(value: 'pending_approval', child: Text('Onay Bekle', style: TextStyle(color: Colors.white, fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() => selectedStatus = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    if (selectedRole == 'support') ...[
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Canlı Destek Puanları & Performans",
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF3B82F6)),
                          ),
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                        ],
                      ),
                      const SizedBox(height: 14),
                      StreamBuilder<List<ChatSession>>(
                        stream: FirebaseService.streamChatSessions(),
                        builder: (context, chatSnap) {
                          final chats = chatSnap.data ?? [];
                          final agentChats = chats.where((c) => c.assignedAgentId == user.uid && c.status == 'closed' && c.rating != null).toList();

                          if (agentChats.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                "Henüz puanlanmış destek oturumu bulunmuyor.",
                                style: GoogleFonts.outfit(color: Colors.white30, fontSize: 12, fontStyle: FontStyle.italic),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: agentChats.map((c) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          c.customerName,
                                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        Row(
                                          children: List.generate(5, (starIdx) {
                                            return Icon(
                                              Icons.star_rounded,
                                              color: starIdx < (c.rating ?? 0) ? Colors.amber : Colors.white10,
                                              size: 14,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                    if (c.lastMessage.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        "Son Mesaj: \"${c.lastMessage}\"",
                                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],

                    if (isRestOwner) ...[
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),
                      Text(
                        "Restoran Bilgileri",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: theme.primaryColor),
                      ),
                      const SizedBox(height: 14),

                      // Interactive Approval & Status Admin Panel
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selectedStatus == 'active'
                              ? const Color(0xFF10B981).withValues(alpha: 0.05)
                              : selectedStatus == 'pending_approval'
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.05)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selectedStatus == 'active'
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : selectedStatus == 'pending_approval'
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  selectedStatus == 'active'
                                      ? Icons.check_circle_rounded
                                      : selectedStatus == 'pending_approval'
                                          ? Icons.hourglass_empty_rounded
                                          : Icons.cancel_rounded,
                                  color: selectedStatus == 'active'
                                      ? const Color(0xFF10B981)
                                      : selectedStatus == 'pending_approval'
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFEF4444),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  selectedStatus == 'active'
                                      ? "Restoran Durumu: AKTİF"
                                      : selectedStatus == 'pending_approval'
                                          ? "Restoran Durumu: ONAY BEKLİYOR"
                                          : "Restoran Durumu: ASKIYA ALINDI",
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: selectedStatus == 'active'
                                        ? const Color(0xFF10B981)
                                        : selectedStatus == 'pending_approval'
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (selectedStatus == 'pending_approval') ...[
                              Text(
                                "Bu restoran henüz sistemde onaylanmamış. Müşteriler tarafından görüntülenmesi ve sipariş alabilmesi için onaylayın.",
                                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setSheetState(() {
                                          selectedStatus = 'active';
                                        });
                                      },
                                      icon: const Icon(Icons.check, size: 14, color: Colors.black),
                                      label: Text(
                                        "Onayla & Aktifleştir",
                                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setSheetState(() {
                                          selectedStatus = 'suspended';
                                        });
                                      },
                                      icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                      label: Text(
                                        "Başvuruyu Reddet",
                                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.redAccent),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (selectedStatus == 'active') ...[
                              Text(
                                "Restoran yayında ve sipariş alıyor. Geçici veya kalıcı olarak kapatmak istiyorsanız askıya alabilirsiniz.",
                                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setSheetState(() {
                                    selectedStatus = 'suspended';
                                  });
                                },
                                icon: const Icon(Icons.block_rounded, size: 14, color: Colors.white),
                                label: Text(
                                  "Restoranı Askıya Al (Durdur)",
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ] else ...[
                              Text(
                                "Restoran askıda ve aktif değil. Tekrar yayına almak ve sipariş akışını başlatmak için aktifleştirin.",
                                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setSheetState(() {
                                    selectedStatus = 'active';
                                  });
                                },
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.black),
                                label: Text(
                                  "Askıdan Kaldır (Aktifleştir)",
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: restNameCtrl,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: "Restoran Marka Adı",
                          prefixIcon: Icon(Icons.storefront, size: 18, color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: restAddressCtrl,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: "Restoran Merkez Adresi",
                          prefixIcon: Icon(Icons.map, size: 18, color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: minOrderCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: "Minimum Sipariş Tutarı (TL)",
                          prefixIcon: Icon(Icons.monetization_on_outlined, size: 18, color: Colors.white54),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: () async {
                        final error = await FirebaseService.updateUserProfile(
                          uid: user.uid,
                          fullName: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          address: addressCtrl.text.trim(),
                          role: selectedRole,
                          status: selectedStatus,
                          restaurantName: isRestOwner ? restNameCtrl.text.trim() : '',
                          restaurantAddress: isRestOwner ? restAddressCtrl.text.trim() : '',
                          minOrderAmount: isRestOwner ? (double.tryParse(minOrderCtrl.text.trim()) ?? 0.0) : 0.0,
                        );

                        if (context.mounted) {
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Hata: $error", style: GoogleFonts.outfit(color: Colors.white)), backgroundColor: Colors.redAccent),
                            );
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("${nameCtrl.text.trim()} başarıyla güncellendi!", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                                backgroundColor: theme.primaryColor,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text("Güncellemeleri Kaydet", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

        // Filter out current user to prevent accidental self-lockouts, and apply role visibility filters
        final otherUsers = users.where((u) {
          if (u.uid == currentUserUid) return false;
          // Support Manager can only see and manage customers, support agents, and other support managers
          if (FirebaseService.currentUser?.role == 'support_manager') {
            return u.role == 'customer' || u.role == 'support' || u.role == 'support_manager';
          }
          return true;
        }).toList();

        // Apply Search Filter
        final filteredUsers = otherUsers.where((u) {
          final query = _userSearchQuery.toLowerCase().trim();
          if (query.isEmpty) return true;
          return u.fullName.toLowerCase().contains(query) ||
              u.email.toLowerCase().contains(query) ||
              u.phone.toLowerCase().contains(query) ||
              u.role.toLowerCase().contains(query);
        }).toList();

        return Column(
          children: [
            // User Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: TextField(
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  onChanged: (val) {
                    setState(() {
                      _userSearchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Kullanıcı adı, e-posta veya telefon ara...",
                    hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                    suffixIcon: _userSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                            onPressed: () {
                              setState(() {
                                _userSearchQuery = "";
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 54, color: Colors.white12),
                          const SizedBox(height: 12),
                          Text(
                            _userSearchQuery.isEmpty
                                ? "Sistemde yetkilendirilecek başka kullanıcı bulunmuyor."
                                : "Aramanızla eşleşen kullanıcı bulunamadı.",
                            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : StreamBuilder<List<ChatSession>>(
                      stream: FirebaseService.streamChatSessions(),
                      builder: (context, chatSnap) {
                        final chats = chatSnap.data ?? [];
                        
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final String roleText = user.role == 'admin'
                                ? 'Admin'
                                : user.role == 'support_manager'
                                    ? 'Destek Yöneticisi'
                                    : user.role == 'restaurant_owner'
                                        ? 'Restoran Sahibi'
                                        : user.role == 'support'
                                            ? 'Canlı Destek'
                                            : 'Müşteri';
                            
                            final Color roleColor = user.role == 'admin'
                                ? const Color(0xFFEF4444)
                                : user.role == 'support_manager'
                                    ? const Color(0xFFA855F7) // Purple for support manager
                                    : user.role == 'restaurant_owner'
                                        ? const Color(0xFF10B981)
                                        : user.role == 'support'
                                            ? const Color(0xFF3B82F6) // Blue for support
                                            : Colors.white30;

                            int closedTickets = 0;
                            double averageRating = 0.0;
                            if (user.role == 'support') {
                              final agentChats = chats.where((c) => c.assignedAgentId == user.uid && c.status == 'closed').toList();
                              closedTickets = agentChats.length;
                              int ratingSum = 0;
                              int ratedCount = 0;
                              for (var c in agentChats) {
                                if (c.rating != null) {
                                  ratingSum += c.rating!;
                                  ratedCount++;
                                }
                              }
                              if (ratedCount > 0) {
                                averageRating = ratingSum / ratedCount;
                              }
                            }

                            return GestureDetector(
                              onTap: () => _showEditUserSheet(user),
                              child: Container(
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
                                          Row(
                                            children: [
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
                                          if (user.role == 'support')
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    averageRating > 0 ? averageRating.toStringAsFixed(1) : "Puan Yok",
                                                    style: GoogleFonts.outfit(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "$closedTickets Çözüldü",
                                                    style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
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
                                      itemBuilder: (BuildContext context) {
                                        final isCurrentUserAdmin = FirebaseService.currentUser?.role == 'admin';
                                        return <PopupMenuEntry<String>>[
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
                                            value: 'support',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.headset_mic_rounded, size: 18, color: Color(0xFF3B82F6)),
                                                const SizedBox(width: 10),
                                                Text("Canlı Destek Personeli Yap", style: GoogleFonts.outfit(color: Colors.white70)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'support_manager',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.manage_accounts_rounded, size: 18, color: Color(0xFFA855F7)),
                                                const SizedBox(width: 10),
                                                Text("Destek Yöneticisi Yap", style: GoogleFonts.outfit(color: Colors.white70)),
                                              ],
                                            ),
                                          ),
                                          if (isCurrentUserAdmin) ...[
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
                                        ];
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
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
                _buildSubTabButton("Profil", 2),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _managementSubTab >= 3 ? 0 : _managementSubTab,
            children: [
              _buildBranchesSubTab(theme),
              _buildDiscountsSubTab(theme),
              _buildRestProfileSubTab(theme),
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showInviteBranchManagerSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFF3B82F6),
                        side: BorderSide(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        minimumSize: const Size(0, 40),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                      label: Text("Yetkili Davet Et", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddBranchSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                        foregroundColor: theme.primaryColor,
                        side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        minimumSize: const Size(0, 40),
                      ),
                      icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                      label: Text("Şube Ekle", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          StreamBuilder<List<RestaurantBranch>>(
            stream: FirebaseService.streamBranches(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CupertinoActivityIndicator(color: Colors.white),
                ));
              }
              final branches = snapshot.data ?? [];
              if (branches.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
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
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
        ],
      ),
    );
  }

  void _showInviteBranchManagerSheet() {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    bool isLoading = false;

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
                            const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF3B82F6), size: 24),
                            const SizedBox(width: 8),
                            Text(
                              "Şube Yetkilisi Davet Et",
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Normal bir müşteriyi, restoranınız için şube yetkilisi (ortak yönetici) olarak atayabilirsiniz. Davet ettiğiniz kişi profilinden daveti onayladığında şube paneline erişebilecektir.",
                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Müşteri E-Posta Adresi",
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: TextFormField(
                            controller: emailCtrl,
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: "Örn: musteri@yemek.com",
                              hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              prefixIcon: const Icon(Icons.email_outlined, color: Colors.white38, size: 18),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return "E-posta boş bırakılamaz.";
                              if (!val.contains("@")) return "Geçerli bir e-posta girin.";
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    setModalState(() => isLoading = true);
                                    final error = await FirebaseService.sendBranchInvitation(emailCtrl.text);
                                    setModalState(() => isLoading = false);

                                    if (context.mounted) {
                                      if (error != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(error, style: GoogleFonts.outfit(color: Colors.white)),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      } else {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Şube yetkilisi daveti başarıyla gönderildi!",
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black),
                                            ),
                                            backgroundColor: theme.primaryColor,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            margin: const EdgeInsets.all(16),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  "Davet Gönder",
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
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
                          readOnly: true,
                          onTap: () {
                            _showAddressSelectorSheet(
                              "Şube Adresi Seç",
                              addrCtrl.text,
                              (combinedAddress) {
                                setModalState(() {
                                  addrCtrl.text = combinedAddress;
                                });
                              },
                            );
                          },
                          decoration: const InputDecoration(
                            labelText: "Şube Adresi (Seçmek için Dokunun)",
                            prefixIcon: Icon(Icons.map_outlined, size: 18, color: Colors.white54),
                            hintText: "Adres seçmek için dokunun...",
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

  void _showAddressSelectorSheet(String title, String initialValue, Function(String combinedAddress) onSelected) {
    final theme = Theme.of(context);
    final addressDetailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Parse out initial address details
    if (initialValue.isNotEmpty) {
      final parts = initialValue.split(', ');
      if (parts.length >= 2) {
        addressDetailController.text = parts[1];
      } else {
        addressDetailController.text = initialValue;
      }
    }

    String selectedCountry = "Türkiye";
    List<Province> provincesList = [];
    Province? selectedProvince;
    District? selectedDistrict;
    List<Neighborhood> neighborhoodsList = [];
    Neighborhood? selectedNeighborhood;

    bool isLoadingProvinces = true;
    bool isLoadingNeighborhoods = false;
    bool initialLoadDone = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (!initialLoadDone) {
              initialLoadDone = true;
              LocationApiService.getProvinces().then((loadedProvinces) async {
                provincesList = loadedProvinces;
                isLoadingProvinces = false;

                if (initialValue.isNotEmpty) {
                  final text = initialValue.toLowerCase();

                  // 1. Match Province
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
                height: MediaQuery.of(context).size.height * 0.70,
                decoration: BoxDecoration(
                  color: theme.cardColor,
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
                          Icon(Icons.add_location_alt_rounded, color: theme.primaryColor, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 20),
                      Expanded(
                        child: ListView(
                          children: [
                            // --- Country Field ---
                            DropdownButtonFormField<String>(
                              initialValue: selectedCountry,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                              dropdownColor: theme.cardColor,
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

                            // --- Province Field ---
                            DropdownButtonFormField<Province>(
                              initialValue: selectedProvince,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                              dropdownColor: theme.cardColor,
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
                              dropdownColor: theme.cardColor,
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
                              dropdownColor: theme.cardColor,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final combinedAddress = "${selectedNeighborhood!.name} Mh., ${addressDetailController.text.trim()}, ${selectedDistrict!.name} / ${selectedProvince!.name}, $selectedCountry";
                          onSelected(combinedAddress);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text("Adresi Onayla"),
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
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
                    minimumSize: const Size(0, 40),
                  ),
                  icon: const Icon(Icons.qr_code_rounded, size: 16),
                  label: Text("Kupon Oluştur", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          StreamBuilder<List<DiscountCode>>(
            stream: FirebaseService.streamDiscountCodes(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CupertinoActivityIndicator(color: Colors.white),
                ));
              }
              final codes = snapshot.data ?? [];
              if (codes.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
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
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
        ],
      ),
    );
  }

  Widget _buildRestProfileSubTab(ThemeData theme) {
    final user = FirebaseService.currentUser;
    if (user == null) return const SizedBox();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storefront_rounded, color: theme.primaryColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      "Restoran Profil Bilgileri",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Restaurant Brand Name
                TextFormField(
                  controller: _profileRestNameCtrl,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: "Restoran Adı (Marka)",
                    prefixIcon: Icon(Icons.storefront, size: 18, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 14),

                // Restaurant Logo URL / Path with Pick Button
                TextFormField(
                  controller: _profileLogoCtrl,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: "Restoran Logo (Resim URL / Dosya Yolu)",
                    prefixIcon: const Icon(Icons.image_outlined, size: 18, color: Colors.white54),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add_photo_alternate_rounded, color: theme.primaryColor, size: 20),
                      onPressed: _pickLogo,
                      tooltip: "Fotoğraf Seç",
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Restaurant Description
                TextFormField(
                  controller: _profileDescCtrl,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Restoran Açıklaması",
                    prefixIcon: Icon(Icons.description_outlined, size: 18, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 14),

                // Restaurant Address
                TextFormField(
                  controller: _profileRestAddressCtrl,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  readOnly: true,
                  onTap: () {
                    _showAddressSelectorSheet(
                      "Merkez Adresi Seç",
                      _profileRestAddressCtrl.text,
                      (combinedAddress) {
                        setState(() {
                          _profileRestAddressCtrl.text = combinedAddress;
                        });
                      },
                    );
                  },
                  decoration: const InputDecoration(
                    labelText: "Fiziksel Merkez Adresi (Seçmek için Dokunun)",
                    prefixIcon: Icon(Icons.map_outlined, size: 18, color: Colors.white54),
                    hintText: "Adres seçmek için dokunun...",
                  ),
                ),
                const SizedBox(height: 14),

                // Phone
                TextFormField(
                  controller: _profilePhoneCtrl,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: "İrtibat Telefon Numarası",
                    prefixIcon: Icon(Icons.phone_outlined, size: 18, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 14),

                // Owner Name
                TextFormField(
                  controller: _profileNameCtrl,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: "Firma Yetkilisi Adı Soyadı",
                    prefixIcon: Icon(Icons.person_outline, size: 18, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 14),

                // Minimum Order Amount
                TextFormField(
                  controller: _profileMinOrderCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: "Minimum Sipariş Tutarı (TL)",
                    prefixIcon: Icon(Icons.monetization_on_outlined, size: 18, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 14),

                // Maximum Delivery Distance
                TextFormField(
                  controller: _profileMaxDistanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: "Maksimum Sipariş Uzaklığı (KM)",
                    prefixIcon: Icon(Icons.alt_route_rounded, size: 18, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                ElevatedButton(
                  onPressed: () async {
                    final error = await FirebaseService.updateUserProfile(
                      uid: user.uid,
                      fullName: _profileNameCtrl.text.trim(),
                      phone: _profilePhoneCtrl.text.trim(),
                      restaurantName: _profileRestNameCtrl.text.trim(),
                      restaurantAddress: _profileRestAddressCtrl.text.trim(),
                      minOrderAmount: double.tryParse(_profileMinOrderCtrl.text.trim()) ?? 0.0,
                      restaurantLogo: _profileLogoCtrl.text.trim(),
                      restaurantDescription: _profileDescCtrl.text.trim(),
                      maxDeliveryDistance: double.tryParse(_profileMaxDistanceCtrl.text.trim()) ?? 5.0,
                    );

                    if (!mounted) return;
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
                          content: Text("Restoran bilgileri başarıyla güncellendi!", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                          backgroundColor: theme.primaryColor,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Değişiklikleri Kaydet", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
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
                                initialValue: selectedBranch,
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
                          activeThumbColor: theme.primaryColor,
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
                        if (!mounted) return;
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

  // SubTab 3: Restaurants List (Yetkili Panelinden Restoranları Görme)
  Widget _buildRestaurantsSubTab(ThemeData theme) {
    return StreamBuilder<List<UserModel>>(
      stream: FirebaseService.streamUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator(color: Colors.white));
        }

        final allUsers = snapshot.data ?? [];
        final restaurants = allUsers.where((u) => u.role == 'restaurant_owner').toList();

        if (restaurants.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.storefront_rounded, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                Text(
                  "Kayıtlı restoran bulunmamaktadır.",
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: restaurants.length,
          itemBuilder: (context, index) {
            final rest = restaurants[index];
            final isPending = rest.status == 'pending_approval';
            final displayName = rest.restaurantName.isNotEmpty ? rest.restaurantName : "İsimsiz Restoran";
            final displayAddress = rest.restaurantAddress.isNotEmpty ? rest.restaurantAddress : "Adres Belirtilmemiş";

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [theme.primaryColor.withValues(alpha: 0.15), theme.colorScheme.secondary.withValues(alpha: 0.05)],
                      ),
                      border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Icon(Icons.storefront_rounded, color: theme.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, color: Colors.white38, size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "${rest.fullName} (${rest.email})",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: Colors.white38, size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                displayAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPending 
                              ? const Color(0xFFFBBF24).withValues(alpha: 0.1) 
                              : const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isPending 
                                ? const Color(0xFFFBBF24).withValues(alpha: 0.2) 
                                : const Color(0xFF10B981).withValues(alpha: 0.2)
                          ),
                        ),
                        child: Text(
                          isPending ? "Onay Bekliyor" : "Aktif",
                          style: GoogleFonts.outfit(
                            color: isPending ? const Color(0xFFFBBF24) : const Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final newStatus = isPending ? 'active' : 'pending_approval';
                              final error = await FirebaseService.updateUserProfile(
                                uid: rest.uid,
                                status: newStatus,
                              );
                              if (error != null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Hata oluştu: $error")),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isPending 
                                            ? "$displayName restoranı başarıyla onaylandı!" 
                                            : "$displayName restoranı askıya alındı!",
                                      ),
                                      backgroundColor: isPending ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPending ? const Color(0xFF10B981) : const Color(0xFFEF4444).withValues(alpha: 0.8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(76, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              isPending ? "Onayla" : "Askıya Al",
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                            tooltip: "Restoranı Sil",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: theme.cardColor,
                                  title: Text("Restoranı Sil", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                                  content: Text("$displayName restoranını ve tüm menüsünü silmek istediğinize emin misiniz?", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: Text("İptal", style: GoogleFonts.outfit(color: Colors.white54)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                      child: Text("Sil", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final error = await FirebaseService.deleteRestaurant(rest.uid);
                                if (error != null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Hata: $error")),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("$displayName başarıyla silindi.")),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ],
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
  // LIVE CHAT SUPPORT QUEUE TICKET DESK
  // ─────────────────────────────────────────
  Widget _buildSupportQueueTab(ThemeData theme) {
    final bool isAdmin = FirebaseService.currentUser?.role == 'admin' || FirebaseService.currentUser?.role == 'support_manager';
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

                  return GestureDetector(
                    onTap: s.status == 'closed'
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => LiveSupportScreen(session: s)),
                            );
                          }
                        : null,
                    child: Container(
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
                              if (isAdmin && s.status == 'closed') ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: "Görüşmeyi Sil",
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: const Color(0xFF1E1E2C),
                                        title: Text("Görüşmeyi Sil", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                                        content: Text("Bu destek görüşmesini kalıcı olarak silmek istediğinize emin misiniz?", style: GoogleFonts.outfit(color: Colors.white70)),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: Text("İptal", style: GoogleFonts.outfit(color: Colors.white38)),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: Text("Sil", style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await FirebaseService.deleteChatSession(s.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Destek görüşmesi başarıyla silindi.", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                            backgroundColor: Colors.greenAccent,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
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
                                  if (isCurrentAgentClaimant || isAdmin) {
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
                                    : (isCurrentAgentClaimant
                                        ? Colors.greenAccent
                                        : (isAdmin ? const Color(0xFF3B82F6) : Colors.grey.withValues(alpha: 0.2))),
                                foregroundColor: s.status == 'waiting' ? Colors.black : Colors.white,
                                minimumSize: const Size(double.infinity, 42),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                s.status == 'waiting'
                                    ? "Görüşmeyi Başlat"
                                    : (isCurrentAgentClaimant
                                        ? "Görüşmeye Geri Dön"
                                        : (isAdmin ? "Görüşmeyi İncele / Katıl" : "Başka Yetkili İlgileniyor")),
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: s.status == 'waiting' ? Colors.black : Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
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
  Widget _buildAdminSuiteTab(ThemeData theme, double totalRevenue, int activeOrders, int mealsCount, List<OrderModel> orders) {
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
                        "Mali Rapor",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
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
                        "Kullanıcılar",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: _adminSuiteSubTab == 1 ? Colors.black : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _adminSuiteSubTab = 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _adminSuiteSubTab == 2 ? theme.primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Kategoriler",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: _adminSuiteSubTab == 2 ? Colors.black : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _adminSuiteSubTab = 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _adminSuiteSubTab == 3 ? theme.primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Restoranlar",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: _adminSuiteSubTab == 3 ? Colors.black : Colors.white60,
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
            index: _adminSuiteSubTab >= 4 ? 0 : _adminSuiteSubTab,
            children: [
              _buildAnalyticsTab(theme, totalRevenue, activeOrders, mealsCount, orders),
              _buildUsersTab(theme),
              _buildCategoriesSubTab(theme),
              _buildRestaurantsSubTab(theme),
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
  final List<double> ratios;

  RevenueLinePainter({
    required this.color,
    required this.glowColor,
    required this.ratios,
  });

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

    // Weekly live coordinate ratios
    final List<double> values = ratios;
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

class _AnimatedSupportNotificationToast extends StatefulWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;

  const _AnimatedSupportNotificationToast({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.onDismiss,
  });

  @override
  State<_AnimatedSupportNotificationToast> createState() => _AnimatedSupportNotificationToastState();
}

class _AnimatedSupportNotificationToastState extends State<_AnimatedSupportNotificationToast> with SingleTickerProviderStateMixin {
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

    // Auto-dismiss after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
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
