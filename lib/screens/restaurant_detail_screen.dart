import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final UserModel restaurant;
  final Map<String, OrderItem> cart;
  final Function(FoodItem) onAdd;
  final Function(String, int) onUpdateQuantity;
  final VoidCallback onShowCart;
  final int cartItemCount;
  final double cartTotal;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurant,
    required this.cart,
    required this.onAdd,
    required this.onUpdateQuantity,
    required this.onShowCart,
    required this.cartItemCount,
    required this.cartTotal,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  String _searchQuery = "";
  String _selectedCategory = "Hepsi";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rest = widget.restaurant;

    // Dynamically calculate actual current cart totals from the reference Map
    int localItemCount = 0;
    double localTotal = 0.0;
    widget.cart.forEach((_, item) {
      localItemCount += item.quantity;
      localTotal += item.foodItem.price * item.quantity;
    });

    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder<List<FoodItem>>(
            stream: FirebaseService.streamFoodItems(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CupertinoActivityIndicator(radius: 14, color: Colors.white),
                );
              }

              final allItems = snapshot.data ?? [];
              // Filter food items owned by this restaurant
              final restItems = allItems.where((item) => item.restaurantOwnerId == rest.uid).toList();

              // Extract unique categories available in this restaurant
              final categories = ["Hepsi", ...restItems.map((e) => e.category).toSet()];

              // Apply Search & Category filters
              final filteredItems = restItems.where((item) {
                final matchQuery = item.name.toLowerCase().contains(_searchQuery) ||
                                   item.description.toLowerCase().contains(_searchQuery);
                final matchCat = _selectedCategory == "Hepsi" || item.category == _selectedCategory;
                return matchQuery && matchCat;
              }).toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Premium Sliver Header with Cover Image
                  SliverAppBar(
                    expandedHeight: 220,
                    pinned: true,
                    stretch: true,
                    backgroundColor: const Color(0xFF111827),
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 18),
                                onPressed: widget.onShowCart,
                              ),
                              if (localItemCount > 0)
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 14,
                                      minHeight: 14,
                                    ),
                                    child: Text(
                                      "$localItemCount",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      stretchModes: const [
                        StretchMode.zoomBackground,
                        StretchMode.blurBackground,
                      ],
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Beautiful abstract header image
                          Image.network(
                            "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1000&auto=format&fit=crop&q=60",
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black45,
                                  Color(0xFF111827),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Restaurant Meta Info Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  rest.restaurantName.isNotEmpty ? rest.restaurantName : rest.fullName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  "AÇIK",
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            rest.restaurantAddress.isNotEmpty ? rest.restaurantAddress : "Adres bilgisi yok",
                            style: GoogleFonts.outfit(fontSize: 13, color: Colors.white54),
                          ),
                          const SizedBox(height: 16),
                          
                          // Badges Row
                          Row(
                            children: [
                              _buildMetaBadge(
                                Icons.delivery_dining_rounded,
                                theme.primaryColor,
                                "Min. Sipariş",
                                "${rest.minOrderAmount.toStringAsFixed(0)} TL",
                              ),
                              const SizedBox(width: 12),
                              _buildMetaBadge(
                                Icons.location_on,
                                const Color(0xFF3B82F6),
                                "Maks. Mesafe",
                                "${rest.maxDeliveryDistance.toStringAsFixed(0)} km",
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Search dishes
                          CupertinoSearchTextField(
                            backgroundColor: theme.cardColor,
                            placeholder: "Restoran menüsünde ara...",
                            placeholderStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.toLowerCase();
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Categories Pills
                          if (categories.length > 1)
                            SizedBox(
                              height: 38,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: categories.length,
                                itemBuilder: (context, idx) {
                                  final cat = categories[idx];
                                  final isSel = _selectedCategory == cat;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ChoiceChip(
                                      label: Text(
                                        cat,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isSel ? Colors.white : Colors.white60,
                                        ),
                                      ),
                                      selected: isSel,
                                      selectedColor: theme.primaryColor,
                                      backgroundColor: theme.cardColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(
                                          color: isSel ? theme.primaryColor : Colors.white.withValues(alpha: 0.05),
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
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Menu Grid List
                  if (filteredItems.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.no_meals_rounded, size: 48, color: Colors.white24),
                            const SizedBox(height: 12),
                            Text(
                              "Menüde aradığınız kriterde yemek bulunamadı.",
                              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.66,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, idx) {
                            final meal = filteredItems[idx];
                            final cartItem = widget.cart[meal.id];
                            final hasInCart = cartItem != null;

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
                                  // Meal Image
                                  Expanded(
                                    flex: 11,
                                    child: FirebaseService.buildFoodImage(
                                      meal.imageUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  ),

                                  // Meal Meta Details
                                  Expanded(
                                    flex: 10,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            meal.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            meal.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              color: Colors.white38,
                                            ),
                                          ),
                                          const Spacer(),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "${meal.price.toStringAsFixed(0)} TL",
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  color: theme.primaryColor,
                                                ),
                                              ),

                                              // Premium Ekle/Miktar Selector
                                              if (hasInCart)
                                                Container(
                                                  height: 30,
                                                  decoration: BoxDecoration(
                                                    color: theme.primaryColor,
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      IconButton(
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(minWidth: 24),
                                                        icon: const Icon(Icons.remove, size: 14, color: Colors.white),
                                                        onPressed: () {
                                                          widget.onUpdateQuantity(meal.id, -1);
                                                          setState(() {});
                                                        },
                                                      ),
                                                      Text(
                                                        "${cartItem.quantity}",
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(minWidth: 24),
                                                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                                                        onPressed: () {
                                                          widget.onUpdateQuantity(meal.id, 1);
                                                          setState(() {});
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: theme.primaryColor.withValues(alpha: 0.12),
                                                    foregroundColor: theme.primaryColor,
                                                    elevation: 0,
                                                    minimumSize: const Size(60, 30),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(20),
                                                      side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.2)),
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    widget.onAdd(meal);
                                                    setState(() {});
                                                  },
                                                  child: Text(
                                                    "Ekle",
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
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
                            );
                          },
                          childCount: filteredItems.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // Floating bottom Cart preview bar (only if cart has items belonging to this restaurant!)
          if (localItemCount > 0 && widget.cart.values.first.foodItem.restaurantOwnerId == rest.uid)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: InkWell(
                onTap: widget.onShowCart,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.primaryColor, theme.colorScheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "$localItemCount",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Sepeti Görüntüle",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${localTotal.toStringAsFixed(0)} TL",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetaBadge(IconData icon, Color color, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
