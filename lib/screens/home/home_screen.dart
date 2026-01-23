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
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomNav(),
            ),
            Positioned(
              bottom: 100,
              right: 24,
              child: _buildFloatingActionButton(),
            ),
          ],
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
          try {
             displayName = data['displayName'] ?? "User";
          } catch (e) {
             displayName = "User";
          }
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
                    const Text(
                      "Welcome back",
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      displayName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF131616)),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.grey),
                onPressed: () {},
              ),
            )
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
                  Text(
                    "$streak Day Streak!",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8C741D)),
                  ),
                ],
              ),
              Text(
                streak == 0 ? "Start today!" : "Keep it up!",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF8C741D)),
              ),
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
          
          data.forEach((key, value) {
            final card = Flashcard.fromMap(key, value);
            if (card.dueDate <= now) {
              dueCount++;
            }
          });
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF3B8C88),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: const Color(0xFF3B8C88).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("DAILY REVIEW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.7), letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text("$dueCount words", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              const Text("Ready to review.", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: dueCount > 0 ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StudyScreen()),
                  );
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF3B8C88),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                  disabledBackgroundColor: Colors.white.withOpacity(0.5),
                  disabledForegroundColor: const Color(0xFF3B8C88).withOpacity(0.5),
                ),
                child: const Text("Start Review Session", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeckList() {
    return StreamBuilder(
      stream: _dbRef.child("decks").orderByChild("ownerId").equalTo(user!.uid).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text("No decks found. Create one!", style: TextStyle(color: Colors.grey)),
          );
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
                // Click vào deck để tạo từ mới
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateFlashcardScreen(
                      selectedDeckId: deck.id,
                      selectedDeckName: deck.name,
                    ),
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
                      width: 64, 
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0AE9A).withOpacity(0.15), 
                        borderRadius: BorderRadius.circular(12)
                      ),
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
                              value: deck.cardCount > 0 ? 0.3 : 0,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B8C88)),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      width: 56, 
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF3B8C88),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: const Color(0xFF3B8C88).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.add, color: Colors.white, size: 30),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateFlashcardScreen()),
          );
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
          _buildNavItem(Icons.auto_stories, "Study", false),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LibraryScreen()),
              );
            },
            child: _buildNavItem(Icons.menu_book, "Library", false),
          ),
          _buildNavItem(Icons.bar_chart, "Stats", false),
          GestureDetector(
             onTap: () {
               AuthService().signOut();
             },
             child: _buildNavItem(Icons.settings, "Settings", false)
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isActive ? const Color(0xFF3B8C88) : Colors.grey.shade400),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF3B8C88) : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}