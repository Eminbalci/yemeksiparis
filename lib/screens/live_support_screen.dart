import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/image_upload_service.dart';

class LiveSupportScreen extends StatefulWidget {
  final ChatSession session;

  const LiveSupportScreen({super.key, required this.session});

  @override
  State<LiveSupportScreen> createState() => _LiveSupportScreenState();
}

class _LiveSupportScreenState extends State<LiveSupportScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatSession _session;
  bool _isUploadingImage = false;

  Future<void> _showRestaurantContactSheet() async {
    if (_session.orderId == null || _session.orderId!.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: FutureBuilder<Map<String, dynamic>>(
            future: () async {
              // Get all orders to find order
              final List<OrderModel> orders = await FirebaseService.streamOrders().first;
              final order = orders.firstWhere((o) => o.id == _session.orderId, orElse: () => throw "Sipariş bulunamadı");
              final restaurantId = order.items.first.foodItem.restaurantOwnerId;
              
              final restaurantUser = await FirebaseService.getUserById(restaurantId);
              final customerUser = await FirebaseService.getUserById(order.customerId);

              return {
                'order': order,
                'restaurant': restaurantUser,
                'customer': customerUser,
              };
            }(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator(radius: 14, color: Colors.white));
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Center(
                  child: Text(
                    "Sipariş veya Restoran bilgileri yüklenemedi.",
                    style: GoogleFonts.outfit(color: Colors.white54),
                  ),
                );
              }

              final order = snapshot.data!['order'] as OrderModel;
              final rest = snapshot.data!['restaurant'] as UserModel?;
              final customer = snapshot.data!['customer'] as UserModel?;

              // Dynamic delivery time calculation
              String gelmeSuresi = "Bilinmiyor";
              if (order.isTakeaway) {
                gelmeSuresi = "Gel-Al Sipariş (Müşteri şubeden teslim alacak)";
              } else {
                switch (order.status) {
                  case 'pending':
                    gelmeSuresi = "Hazırlanıyor (Tahmini Varış: 35-40 dk)";
                    break;
                  case 'preparing':
                    gelmeSuresi = "Hazırlanıyor (Tahmini Varış: 25-30 dk)";
                    break;
                  case 'on_the_way':
                    gelmeSuresi = "Yolda (Tahmini Varış: 10-15 dk)";
                    break;
                  case 'delivered':
                    gelmeSuresi = "Teslim Edildi";
                    break;
                  default:
                    gelmeSuresi = "30-40 dakika";
                }
              }

              return DefaultTabController(
                length: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pull indicator
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Sipariş & İletişim Merkezi",
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TabBar(
                      indicatorColor: Colors.amber,
                      labelColor: Colors.amber,
                      unselectedLabelColor: Colors.white38,
                      labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13),
                      tabs: const [
                        Tab(text: "Sipariş Detayları"),
                        Tab(text: "Restoran & İletişim"),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // TAB 1: Sipariş Detayları
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailHeader("SİPARİŞ ÖZETİ"),
                                ...order.items.map((item) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            "${item.quantity}x",
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            item.foodItem.name,
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.87), fontSize: 13),
                                          ),
                                        ),
                                        Text(
                                          "${(item.foodItem.price * item.quantity).toStringAsFixed(0)} TL",
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white60, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Toplam Tutar:", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                                    Text(
                                      "${order.totalAmount.toStringAsFixed(0)} TL",
                                      style: GoogleFonts.outfit(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildDetailHeader("TESLİMAT & SÜRE"),
                                _buildDetailTile(Icons.schedule_rounded, "Tahmini Gelme Süresi", gelmeSuresi),
                                _buildDetailTile(Icons.location_on_rounded, "Müşteri Teslimat Adresi", customer?.address ?? "Adres bulunamadı"),
                                _buildDetailTile(Icons.phone_iphone, "Müşteri İletişim", customer?.phone ?? "Telefon bulunamadı"),
                                const SizedBox(height: 20),
                                _buildDetailHeader("MÜŞTERİ SİPARİŞ NOTU"),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.02),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                                  ),
                                  child: Text(
                                    order.note != null && order.note!.isNotEmpty
                                        ? order.note!
                                        : "Müşteri sipariş notu eklemedi.",
                                    style: GoogleFonts.outfit(
                                      color: order.note != null && order.note!.isNotEmpty ? Colors.white.withValues(alpha: 0.87) : Colors.white24,
                                      fontSize: 13,
                                      fontStyle: order.note != null && order.note!.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // TAB 2: Restoran & İletişim
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (rest != null) ...[
                                  _buildDetailHeader("RESTORAN BİLGİLERİ"),
                                  _buildDetailTile(Icons.storefront_rounded, "Restoran Adı", rest.restaurantName.isNotEmpty ? rest.restaurantName : rest.fullName),
                                  _buildDetailTile(Icons.person_rounded, "Restoran Sahibi / Sorumlu", rest.fullName),
                                  _buildDetailTile(Icons.phone_rounded, "Restoran Telefonu", rest.phone.isNotEmpty ? rest.phone : "Telefon bulunamadı"),
                                  _buildDetailTile(Icons.location_on_rounded, "Restoran Adresi", rest.restaurantAddress.isNotEmpty ? rest.restaurantAddress : "Adres bulunamadı"),
                                  const SizedBox(height: 32),
                                  if (rest.phone.isNotEmpty)
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final Uri telUri = Uri.parse('tel:${rest.phone}');
                                        try {
                                          await launchUrl(telUri);
                                        } catch (_) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("Arama başlatılamadı: ${rest.phone}")),
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.call, color: Colors.black, size: 20),
                                      label: Text(
                                        "Restoranı Telefonla Ara",
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 4,
                                      ),
                                    ),
                                ] else ...[
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32.0),
                                      child: Text(
                                        "Restoran bilgileri bulunamadı.",
                                        style: GoogleFonts.outfit(color: Colors.white38),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDetailHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.amber, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.87), fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    await FirebaseService.sendChatMessage(_session.id, text);
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Lightweight size optimization
      );
      if (image == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final uploadedUrl = await ImageUploadService.uploadImage(image);

      if (uploadedUrl != null) {
        await FirebaseService.sendChatMessage(_session.id, '', imageUrl: uploadedUrl);
        _scrollToBottom();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fotoğraf yüklenirken hata oluştu.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _closeSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Oturumu Kapat', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text('Bu destek oturumunu sonlandırmak istediğinize emin misiniz?',
            style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kapat', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await FirebaseService.closeChatSession(_session.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserUid = FirebaseService.currentUser?.uid;
    final isAgent = FirebaseService.currentUser?.role != 'customer';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.primaryColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: StreamBuilder<ChatSession?>(
          stream: FirebaseService.streamMySession(_session.id),
          builder: (context, snap) {
            final s = snap.data ?? _session;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Canlı Destek', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  s.isWaiting
                      ? 'Yetkili bekleniyor...'
                      : s.isActive
                          ? 'Bağlı: ${isAgent ? s.customerName : (s.assignedAgentName ?? 'Yetkili')}'
                          : 'Oturum Kapatıldı',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: s.isWaiting
                        ? Colors.orange
                        : s.isActive
                            ? Colors.greenAccent
                            : Colors.white38,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          if (isAgent && _session.orderId != null && _session.orderId!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.storefront_rounded, color: Colors.amber),
              tooltip: 'Restoran İletişim Bilgileri',
              onPressed: _showRestaurantContactSheet,
            ),
          if (isAgent)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
              tooltip: 'Oturumu Kapat',
              onPressed: _closeSession,
            ),
        ],
      ),
      body: StreamBuilder<ChatSession?>(
        stream: FirebaseService.streamMySession(_session.id),
        builder: (context, snap) {
          final session = snap.data ?? _session;
          if (session.id.isEmpty) {
            return Center(child: Text('Oturum bulunamadı.', style: GoogleFonts.outfit(color: Colors.white54)));
          }

          // Update local state
          if (session.status != _session.status || session.messages.length != _session.messages.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _session = session);
              _scrollToBottom();
            });
          }

          return Column(
            children: [
              // Status Banner
              if (session.isWaiting)
                _buildWaitingBanner(theme)
              else if (session.isActive && !isAgent && session.assignedAgentName != null)
                _buildConnectedBanner(theme, session.assignedAgentName!),

              // Messages
              Expanded(
                child: session.messages.isEmpty
                    ? _buildEmptyState(theme, session)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: session.messages.length,
                        itemBuilder: (context, index) {
                          final msg = session.messages[index];
                          final isMe = msg.senderId == currentUserUid;
                          return _buildMessageBubble(theme, msg, isMe);
                        },
                      ),
              ),

              // Input bar (only if session is active)
              if (!session.isClosed)
                _buildInputBar(theme, false),

              // Customer rating area for closed live support sessions
              if (session.isClosed && !isAgent) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rate_review_rounded, color: theme.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            session.rating != null ? "Desteği Puanladınız" : "Canlı Desteği Oylayın",
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.rating != null
                            ? "Temsilcimizi değerlendirdiğiniz için çok teşekkür ederiz."
                            : "Görüşleriniz bizim için çok değerlidir. Lütfen temsilcimizi oylayın:",
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (session.rating != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (starIndex) {
                            return Icon(
                              Icons.star_rounded,
                              color: starIndex < session.rating! ? const Color(0xFFFFB020) : Colors.white10,
                              size: 28,
                            );
                          }),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (starIndex) {
                            final currentStar = starIndex + 1;
                            return GestureDetector(
                              onTap: () async {
                                final err = await FirebaseService.rateSupportSession(session.id, currentStar);
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
                                      content: Text("Desteğimizi puanladınız! Harika günler dileriz. ❤️", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                                      backgroundColor: const Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Icon(
                                  Icons.star_outline_rounded,
                                  color: const Color(0xFFFFB020).withValues(alpha: 0.5),
                                  size: 32,
                                ),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildWaitingBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.withValues(alpha: 0.15), Colors.orange.withValues(alpha: 0.05)],
        ),
        border: Border(bottom: BorderSide(color: Colors.orange.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          const CupertinoActivityIndicator(radius: 8, color: Colors.orange),
          const SizedBox(width: 10),
          Text(
            'Canlı desteğe bağlanıyorsunuz, lütfen bekleyin...',
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedBanner(ThemeData theme, String agentName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.greenAccent.withValues(alpha: 0.12), Colors.greenAccent.withValues(alpha: 0.04)],
        ),
        border: Border(bottom: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent_rounded, color: Colors.greenAccent, size: 18),
          const SizedBox(width: 10),
          Text(
            '$agentName sohbete katıldı',
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.greenAccent, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ChatSession session) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              session.isWaiting ? Icons.support_agent_rounded : Icons.chat_bubble_outline_rounded,
              size: 64,
              color: session.isWaiting ? Colors.orange.withValues(alpha: 0.4) : theme.primaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              session.isWaiting
                  ? 'Yetkili sizi bekleme sırasından alacak...'
                  : 'Merhaba! Size nasıl yardımcı olabiliriz?',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ThemeData theme, ChatMessage msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text(
                    msg.senderName,
                    style: GoogleFonts.outfit(fontSize: 11, color: theme.primaryColor, fontWeight: FontWeight.w600),
                  ),
                ),
              Container(
                padding: msg.imageUrl.isNotEmpty
                    ? const EdgeInsets.all(4) // Clean borderless layout for images
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(colors: [theme.primaryColor, theme.colorScheme.secondary])
                      : null,
                  color: isMe ? null : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                backgroundColor: Colors.black.withValues(alpha: 0.9),
                                insetPadding: const EdgeInsets.all(12),
                                child: Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    InteractiveViewer(
                                      child: Center(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.network(
                                            msg.imageUrl,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.black45,
                                        child: IconButton(
                                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                                          onPressed: () => Navigator.pop(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: msg.id,
                            child: Image.network(
                              msg.imageUrl,
                              width: 200,
                              height: 180,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const SizedBox(
                                  width: 200,
                                  height: 180,
                                  child: Center(
                                    child: CupertinoActivityIndicator(color: Colors.white),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return SizedBox(
                                  width: 200,
                                  height: 180,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.broken_image_rounded, color: Colors.white30, size: 40),
                                      const SizedBox(height: 8),
                                      Text('Fotoğraf yüklenemedi', style: GoogleFonts.outfit(color: Colors.white30, fontSize: 11)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    if (msg.text.isNotEmpty) ...[
                      if (msg.imageUrl.isNotEmpty) const SizedBox(height: 6),
                      Padding(
                        padding: msg.imageUrl.isNotEmpty
                            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                            : EdgeInsets.zero,
                        child: Text(
                          msg.text,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: isMe ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                child: Text(
                  '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.outfit(fontSize: 10, color: Colors.white24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, bool disabled) {
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 10, top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          // Photo Attachment Button
          if (_isUploadingImage)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
              ),
            )
          else
            IconButton(
              icon: Icon(
                Icons.add_photo_alternate_rounded,
                color: disabled ? Colors.white24 : theme.primaryColor,
                size: 26,
              ),
              tooltip: 'Fotoğraf Gönder',
              onPressed: disabled ? null : _pickAndUploadImage,
            ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _msgController,
              enabled: !disabled,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: disabled ? 'Yetkili bağlanmayı bekleyin...' : 'Mesajınızı yazın...',
                hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: disabled ? null : _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: disabled
                    ? null
                    : LinearGradient(colors: [theme.primaryColor, theme.colorScheme.secondary]),
                color: disabled ? Colors.white12 : null,
              ),
              child: Icon(
                Icons.send_rounded,
                color: disabled ? Colors.white24 : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
