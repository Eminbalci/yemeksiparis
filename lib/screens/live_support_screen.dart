import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

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
          if (!snap.hasData) {
            return const Center(child: CupertinoActivityIndicator(radius: 12, color: Colors.white));
          }
          final session = snap.data!;
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
                _buildInputBar(theme, session.isWaiting && !isAgent),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                child: Text(
                  msg.text,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: isMe ? Colors.white : Colors.white70,
                  ),
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
        left: 16, right: 10, top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
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
