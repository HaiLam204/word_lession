import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/auth_service.dart';
import '../../models/app_models.dart';
import '../study/study_screen.dart';
import '../create/create_flashcard_screen.dart';
import '../library/library_screen.dart';

// --- PHẦN 1: MÀN HÌNH CHÍNH (CONTAINER) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeTabPlaceholder(), 
    const StudyScreen(),
    const LibraryScreen(),
    const Center(child: Text("Cài đặt")),
  ];

  void _onItemTapped(int index) {
    if (index == 3) {
      AuthService().signOut();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
          _buildNavItem(Icons.settings_rounded, "Settings", 3),
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
                backgroundColor: const Color(0xFF3B8C88).withOpacity(0.2),
                child: const Icon(Icons.person, color: Color(0xFF3B8C88)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text("Xin chào", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF131616))),
                  ],
                ),
              ),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                child: const Icon(Icons.notifications_none, color: Colors.grey),
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
                              Text(deck.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                    const SizedBox(width: 12),
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