import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../notifications/notifications_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String _searchQuery = "";
  String _filterStatus = "All"; // All, Review, Mastered

  final Color primaryColor = const Color(0xFF286D8A);
  final Color accentGold = const Color(0xFFD4AF37);
  final Color textDark = const Color(0xFF0F172A);
  final Color backgroundColor = const Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilterChips(),
            Expanded(child: _buildWordList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40), // Spacer for alignment
          const Text(
            'Thư viện',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF3E8F8B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_outlined, color: Color(0xFF3E8F8B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.transparent,
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 22),
            hintText: "Tìm kiếm từ vựng...",
            hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        children: [
          _buildChip("Tất cả", "All"),
          const SizedBox(width: 12),
          _buildChip("Cần ôn", "Review"),
          const SizedBox(width: 12),
          _buildChip("Đã thuộc", "Mastered"),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String status) {
    bool isActive = _filterStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActive ? Colors.transparent : Colors.grey.shade200),
          boxShadow: isActive ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null
        ),
        child: Text(
          label,
          style: TextStyle(color: isActive ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildWordList() {
    // QUAN TRỌNG: Lọc theo ownerId để chỉ lấy thẻ của user hiện tại
    return StreamBuilder(
      stream: _dbRef.child("cards").orderByChild("ownerId").equalTo(user!.uid).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Center(child: Text("Chưa có từ vựng nào.", style: TextStyle(color: Colors.grey[400])));
        }

        List<Flashcard> cards = [];
        Map data = snapshot.data!.snapshot.value as Map;
        int now = DateTime.now().millisecondsSinceEpoch;

        data.forEach((key, value) {
          final card = Flashcard.fromMap(key, value);
          
          // Logic tìm kiếm
          bool matchesSearch = card.front.toLowerCase().contains(_searchQuery) || 
                               card.back.toLowerCase().contains(_searchQuery);
          
          // Logic lọc trạng thái
          bool matchesFilter = true;
          if (_filterStatus == "Review") {
            matchesFilter = card.dueDate <= now;
          } else if (_filterStatus == "Mastered") {
            matchesFilter = card.interval > 20; // Giả sử interval > 20 ngày là thuộc
          }

          if (matchesSearch && matchesFilter) {
            cards.add(card);
          }
        });

        // Sắp xếp từ mới nhất
        cards.sort((a, b) => b.dueDate.compareTo(a.dueDate));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            bool isMastered = card.interval > 20;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(card.front, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textDark)),
                      ),
                      if (isMastered)
                        Icon(Icons.stars_rounded, color: accentGold, size: 20)
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(card.back, style: TextStyle(fontSize: 16, color: Colors.grey[800])),
                  if (card.example.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Example: ${card.example}",
                      style: TextStyle(fontSize: 14, color: Colors.grey[500], fontStyle: FontStyle.italic),
                    ),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }
}