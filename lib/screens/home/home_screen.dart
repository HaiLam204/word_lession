import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/auth_service.dart';
import '../../models/app_models.dart';
import '../study/study_screen.dart';
import '../create/create_flashcard_screen.dart';
import '../library/library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
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
                  const Text("Your Decks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF131616))),
                  const SizedBox(height: 16),
                  _buildDeckList(),
                ],
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildBottomNav(),
            ),
            Positioned(
              bottom: 100, right: 24,
              child: _buildFloatingActionButton(),
            ),
          ],
        ),
      ),
    );
  }

  // ... (Giữ nguyên _buildHeader, _buildStreakSection, _buildDailyReviewCard)
  Widget _buildHeader() {
    return StreamBuilder(
      stream: _dbRef.child("users/${user!.uid}").onValue,
      builder: (context, snapshot) {
        String displayName = "User";
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map;
          try { displayName = data['displayName'] ?? "User"; } catch (_) {}
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF3B8C88).withOpacity(0.2),
                  child: const Icon(Icons.person, color: Color(0xFF3B8C88)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Welcome back", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const Icon(Icons.notifications_none, color: Colors.grey),
          ],
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
                  Text("$streak Day Streak!", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8C741D))),
                ],
              ),
              Text(streak == 0 ? "Start today!" : "Keep it up!", style: const TextStyle(fontSize: 12, color: Color(0xFF8C741D))),
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
              Text("$dueCount words", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              const Text("Ready to review.", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: dueCount > 0 ? () {
                  // Review chung (không lọc theo deck)
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const StudyScreen()));
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF3B8C88)),
                child: const Text("Start Review Session", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }

  // --- SỬA PHẦN NÀY ---
  Widget _buildDeckList() {
    return StreamBuilder(
      stream: _dbRef.child("decks").orderByChild("ownerId").equalTo(user!.uid).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No decks found.")));
        }

        Map data = snapshot.data!.snapshot.value as Map;
        List<Deck> decks = [];
        data.forEach((key, value) {
          decks.add(Deck.fromMap(key, value));
        });

        return Column(
          children: decks.map((deck) {
            return GestureDetector(
              onTap: () {
                // CHUYỂN SANG HỌC TỪ TRONG DECK NÀY
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudyScreen(deckId: deck.id), // Truyền ID của Deck vào
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: const Color(0xFFF0AE9A).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.folder_copy, color: Color(0xFFF0AE9A), size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(deck.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF131616))),
                          const SizedBox(height: 4),
                          Text("${deck.cardCount} cards total", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: 0, // Tạm thời để 0
                              backgroundColor: Colors.grey.shade100,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B8C88)),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_circle_outline, color: Colors.grey), // Icon biểu thị "học"
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // FAB và BottomNav (Giữ nguyên)
  Widget _buildFloatingActionButton() {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(color: const Color(0xFF3B8C88), shape: BoxShape.circle),
      child: IconButton(
        icon: const Icon(Icons.add, color: Colors.white, size: 30),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateFlashcardScreen()));
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home, "Home", true),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StudyScreen())), // Nút Study ở dưới thì vào học chung
            child: _buildNavItem(Icons.auto_stories, "Study", false),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LibraryScreen())),
            child: _buildNavItem(Icons.menu_book, "Library", false),
          ),
          GestureDetector(
             onTap: () => AuthService().signOut(),
             child: _buildNavItem(Icons.settings, "Settings", false)
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: isActive ? const Color(0xFF3B8C88) : Colors.grey.shade400), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF3B8C88) : Colors.grey.shade400))]);
  }
}