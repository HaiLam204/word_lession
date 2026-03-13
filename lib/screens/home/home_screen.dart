import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/deck_service.dart';
import '../../services/leaderboard_service.dart';
import '../../models/app_models.dart';
import '../study/study_screen.dart';
import '../create/create_flashcard_screen.dart';
import '../library/library_screen.dart';
import '../community/community_screen.dart';
import '../settings/settings_screen.dart';
import '../notifications/notifications_screen.dart';

// --- PHẦN 1: MÀN HÌNH CHÍNH (CONTAINER) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _notificationsCreated = false;

  final List<Widget> _screens = [
    const HomeTabPlaceholder(), 
    const StudyScreen(),
    const LibraryScreen(),
    const CommunityScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _createSampleNotifications();
  }

  Future<void> _createSampleNotifications() async {
    if (_notificationsCreated) return;
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if notifications already exist
      DatabaseReference notifRef = FirebaseDatabase.instance.ref('notifications/${user.uid}');
      DataSnapshot snapshot = await notifRef.get();
      
      if (!snapshot.exists) {
        // Create sample notifications
        NotificationService notificationService = NotificationService();
        
        await notificationService.createNotification(
          userId: user.uid,
          title: 'Chào mừng bạn!',
          message: 'Chúc mừng bạn đã tham gia ứng dụng học từ vựng. Hãy bắt đầu học ngay!',
          type: 'system',
        );
        
        await notificationService.createStudyReminder(user.uid, 2);
        
        await notificationService.createNotification(
          userId: user.uid,
          title: 'Cập nhật hệ thống',
          message: 'Phiên bản mới 2.4.1 đã sẵn sàng với nhiều cải tiến về hiệu năng SRS.',
          type: 'system',
        );
        
        setState(() {
          _notificationsCreated = true;
        });
        
        print('✅ Đã tạo thông báo mẫu thành công');
      }
    } catch (e) {
      print('❌ Lỗi tạo thông báo: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _switchToStudyTab() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget currentBody;
    if (_selectedIndex == 0) {
      currentBody = HomeTab(onSwitchToStudy: _switchToStudyTab);
    } else {
      currentBody = _screens[_selectedIndex];
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      body: currentBody, 
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_rounded, "Home", 0),
          _buildNavItem(Icons.auto_stories_rounded, "Study", 1),
          _buildNavItem(Icons.menu_book_rounded, "Library", 2),
          _buildNavItem(Icons.people_rounded, "Community", 3),
          _buildNavItem(Icons.settings_rounded, "Settings", 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: isActive
                ? BoxDecoration(color: const Color(0xFF3B8C88).withOpacity(0.1), borderRadius: BorderRadius.circular(12))
                : const BoxDecoration(color: Colors.transparent),
            child: Icon(icon, color: isActive ? const Color(0xFF3B8C88) : Colors.grey.shade400, size: 26),
          ),
          if (isActive) ...[
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF3B8C88))),
          ]
        ],
      ),
    );
  }
}

class HomeTabPlaceholder extends StatelessWidget {
  const HomeTabPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => Container(); 
}

// --- PHẦN 2: NỘI DUNG HOME TAB ---
class HomeTab extends StatefulWidget {
  final VoidCallback? onSwitchToStudy;

  const HomeTab({super.key, this.onSwitchToStudy});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final DeckService _deckService = DeckService();
  final LeaderboardService _leaderboardService = LeaderboardService();

  Future<void> _deleteDeck(String deckId) async {
    try {
      final dbRef = FirebaseDatabase.instance.ref();

      await dbRef.child("decks/$deckId").remove();

      final snapshot = await dbRef.child("cards").orderByChild("deckId").equalTo(deckId).get();
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        for (String cardId in data.keys) {
          await dbRef.child("cards/$cardId").remove();
        }
      }

      // Decrement totalDecks count
      if (user != null) {
        await _leaderboardService.decrementDeckCount(user!.uid);
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa bộ thẻ và các từ vựng bên trong!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi khi xóa: $e"), backgroundColor: Colors.red));
    }
  }

  void _showDeleteDeckConfirm(String deckId, String deckName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cảnh báo xóa", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("Bạn có chắc chắn muốn xóa bộ thẻ '$deckName' không?\n\nToàn bộ từ vựng trong bộ thẻ này sẽ bị xóa vĩnh viễn và không thể khôi phục!"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Hủy", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); 
              _deleteDeck(deckId);    
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text("Xóa vĩnh viễn", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );
  }

  void _showShareDialog(String deckId, String deckName, bool isCurrentlyPublic) {
    if (isCurrentlyPublic) {
      // Unshare dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            "Hủy chia sẻ",
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Bạn có muốn hủy chia sẻ bộ thẻ '$deckName' không?\n\nBộ thẻ sẽ không còn hiển thị trong cộng đồng.",
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _deckService.unshareDeck(deckId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Đã hủy chia sẻ bộ thẻ!"),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Lỗi: $e"), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                "Hủy chia sẻ",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else {
      // Share dialog with description and tags
      _showShareFormDialog(deckId, deckName);
    }
  }

  void _showShareFormDialog(String deckId, String deckName) {
    final TextEditingController descController = TextEditingController();
    List<String> selectedTags = [];
    final List<String> availableTags = [
      'TOEIC',
      'IELTS',
      'Giao tiếp',
      'IT',
      'Business',
      'Du lịch',
      'Học thuật',
      'Tiếng lóng',
      'Phát âm',
      'Ngữ pháp',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(
            "Chia sẻ bộ thẻ",
            style: TextStyle(color: Color(0xFF3B8C88), fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bộ thẻ: $deckName",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text("Mô tả (tùy chọn):", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Mô tả ngắn về bộ thẻ này...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Chọn tags:", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableTags.map((tag) {
                    bool isSelected = selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                        });
                      },
                      selectedColor: const Color(0xFF3B8C88).withOpacity(0.3),
                      checkmarkColor: const Color(0xFF3B8C88),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () {
                descController.dispose();
                Navigator.pop(context);
              },
              child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                String description = descController.text.trim();
                Navigator.pop(context);
                
                try {
                  await _deckService.shareDeck(
                    deckId,
                    description: description.isEmpty ? null : description,
                    tags: selectedTags.isEmpty ? null : selectedTags,
                  );
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Đã chia sẻ bộ thẻ lên cộng đồng!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Lỗi: $e"), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  descController.dispose();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B8C88),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                "Chia sẻ",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to check if deck is copied from community
  bool _isCopiedDeck(Deck deck) {
    return deck.copiedFrom != null && deck.copiedFrom!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildStreakSection(),
              const SizedBox(height: 24),
              _buildDailyReviewCard(),
              const SizedBox(height: 32),
              const Text("Thư viện của bạn", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF131616))),
              const SizedBox(height: 16),
              _buildDeckList(),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF3B8C88),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: const Color(0xFF3B8C88).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: IconButton(
          icon: const Icon(Icons.add, color: Colors.white, size: 30),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateFlashcardScreen())),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder(
      stream: _dbRef.child("users/${user!.uid}").onValue,
      builder: (context, snapshot) {
        String displayName = "User";
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map;
          try { displayName = data['displayName'] ?? "User"; } catch (_) {}
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF3B8C88),
                child: Text(
                  displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Xin chào", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF131616))),
                  ],
                ),
              ),
              
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                },
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    shape: BoxShape.circle, 
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                  ),
                  child: const Icon(Icons.notifications_outlined, color: Color(0xFF3B8C88), size: 20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStreakSection() {
    return StreamBuilder(
      stream: _dbRef.child("users/${user!.uid}/streak").onValue,
      builder: (context, snapshot) {
        int streak = 0;
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          streak = (snapshot.data!.snapshot.value as int);
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0D16B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0D16B).withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Color(0xFFF0D16B)),
                  const SizedBox(width: 8),
                  Text("$streak Ngày Streak!", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8C741D))),
                ],
              ),
              Text(streak == 0 ? "Bắt đầu ngay!" : "Cố lên!", style: const TextStyle(fontSize: 12, color: Color(0xFF8C741D))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyReviewCard() {
    return StreamBuilder(
      stream: _dbRef.child("cards").orderByChild("ownerId").equalTo(user!.uid).onValue,
      builder: (context, snapshot) {
        int dueCount = 0;
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          Map data = snapshot.data!.snapshot.value as Map;
          int now = DateTime.now().millisecondsSinceEpoch;
          data.forEach((k, v) {
            final card = Flashcard.fromMap(k, v);
            if (card.dueDate <= now) dueCount++;
          });
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF3B8C88),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("DAILY REVIEW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
              const SizedBox(height: 8),
              Text("$dueCount từ", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              const Text("Cần ôn tập hôm nay.", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (widget.onSwitchToStudy != null) {
                    widget.onSwitchToStudy!();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF3B8C88)),
                child: const Text("Vào góc học tập", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }

  // --- HÀM BUILD DANH SÁCH DECK ---
  Widget _buildDeckList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. DECK CỦA TÔI
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text("Bộ thẻ của tôi", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
        ),
        StreamBuilder(
          stream: _dbRef.child("decks").orderByChild("ownerId").equalTo(user!.uid).onValue,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Text("Bạn chưa có bộ thẻ nào. Hãy tạo mới!", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              );
            }
            return _buildDeckListFromSnapshot(snapshot);
          },
        ),

        const SizedBox(height: 24),

        // 2. DECK MẶC ĐỊNH
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text("Bộ thẻ mẫu (System)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
        ),
        StreamBuilder(
          stream: _dbRef.child("decks").orderByChild("ownerId").equalTo("admin").onValue,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Padding(padding: EdgeInsets.all(8.0), child: Text("Chưa có thẻ mẫu.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)));
            }
            return _buildDeckListFromSnapshot(snapshot, isSystem: true);
          },
        ),
      ],
    );
  }

  // --- HÀM HELPER ĐỂ HIỂN THỊ LIST DECK + THANH TIẾN ĐỘ ---
  Widget _buildDeckListFromSnapshot(AsyncSnapshot snapshot, {bool isSystem = false}) {
    Map data = snapshot.data!.snapshot.value as Map;
    List<Deck> decks = [];
    data.forEach((key, value) => decks.add(Deck.fromMap(key, value)));
    decks.sort((a, b) => a.name.compareTo(b.name));

    // StreamBuilder thứ 2 để lấy dữ liệu Cards (tính tiến độ)
    return StreamBuilder(
      stream: _dbRef.child("cards").orderByChild("ownerId").equalTo(user!.uid).onValue,
      builder: (context, cardSnapshot) {
        
        // Map lưu tiến độ: DeckID -> {total: 10, learned: 5}
        Map<String, Map<String, int>> deckProgress = {};

        if (cardSnapshot.hasData && cardSnapshot.data!.snapshot.value != null) {
          Map cardsData = cardSnapshot.data!.snapshot.value as Map;
          cardsData.forEach((key, value) {
            final card = Flashcard.fromMap(key, value);
            
            if (!deckProgress.containsKey(card.deckId)) {
              deckProgress[card.deckId] = {"total": 0, "learned": 0};
            }
            
            // Đếm tổng số thẻ trong deck (Dựa trên dữ liệu thực tế)
            deckProgress[card.deckId]!["total"] = (deckProgress[card.deckId]!["total"] ?? 0) + 1;
            
            // ĐẾM THẺ ĐÃ HỌC: Bất kỳ thẻ nào trạng thái khác 'new'
            if (card.status != 'new') {
              deckProgress[card.deckId]!["learned"] = (deckProgress[card.deckId]!["learned"] ?? 0) + 1;
            }
          });
        }

        return Column(
          children: decks.map((deck) {
            // Lấy thông tin tiến độ
            // Ưu tiên số liệu thực tế từ bảng cards, nếu không có thì lấy cardCount từ deck
            int total = deckProgress[deck.id]?["total"] ?? deck.cardCount; 
            int learned = deckProgress[deck.id]?["learned"] ?? 0;
            double progress = total == 0 ? 0.0 : (learned / total);
            
            // Đảm bảo không vượt quá 100% (phòng trường hợp lỗi dữ liệu)
            if (progress > 1.0) progress = 1.0;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => StudyScreen(deckId: deck.id)),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSystem ? Colors.blue.withOpacity(0.3) : Colors.grey.shade100),
                  boxShadow: [if(isSystem) BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: (isSystem ? Colors.blue : const Color(0xFFF0AE9A)).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Icon(isSystem ? Icons.verified : Icons.folder_copy, color: isSystem ? Colors.blue : const Color(0xFFF0AE9A), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  deck.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text("${(progress * 100).toInt()}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3B8C88))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.shade100,
                              color: const Color(0xFF3B8C88),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text("$learned/$total đã học", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    
                    // Share button (only for user's own decks, not system decks, not copied decks)
                    if (!isSystem && !_isCopiedDeck(deck))
                      IconButton(
                        icon: Icon(
                          deck.isPublic ? Icons.public : Icons.public_off,
                          color: deck.isPublic ? const Color(0xFF3B8C88) : Colors.grey,
                        ),
                        onPressed: () => _showShareDialog(deck.id, deck.name, deck.isPublic),
                      ),
                    
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _showDeleteDeckConfirm(deck.id, deck.name),
                    ),
                    
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      }
    );
  }
}