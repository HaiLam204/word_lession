import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Library", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: textDark)),
                  Row(
                    children: [
                      IconButton(onPressed: (){}, icon: Icon(Icons.tune_rounded, color: Colors.grey[700]), style: IconButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.all(12))),
                      const SizedBox(width: 12),
                      FloatingActionButton.small(onPressed: (){}, backgroundColor: primaryColor, elevation: 2, child: const Icon(Icons.add_rounded, color: Colors.white, size: 24)),
                    ],
                  )
                ],
              ),
            ),
            
            // Search Bar (Đã sửa lỗi shadow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                // Bọc TextField trong Container để tạo bóng
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 22),
                    hintText: "Search terms, tags...",
                    hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    // Đã xóa dòng shadow bị lỗi ở đây
                  ),
                ),
              ),
            ),
            
            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Row(
                children: [
                  _buildChip("All Words", "124", true),
                  const SizedBox(width: 12),
                  _buildChip("To Review", "12", false),
                  const SizedBox(width: 12),
                  _buildChip("Mastered", "84", false),
                ],
              ),
            ),

            // Word List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildWordItem("Ephemeral", "/əˈfem(ə)rəl/ • ADJ", "Lasting for a very short time; fleeting or transitory in nature.", false),
                  const SizedBox(height: 16),
                  _buildWordItem("Melancholy", "/ˈmelənkəlē/ • NOUN", "A feeling of pensive sadness, typically with no obvious cause.", true),
                  const SizedBox(height: 16),
                  _buildWordItem("Sonder", "/ˈsɒndər/ • NOUN", "The profound realization that everyone, including strangers passed in the street, has a life as complex as one's own.", false),
                   const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String count, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? Colors.transparent : Colors.grey.shade200),
        boxShadow: isActive ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0,4))] : null
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withOpacity(0.2) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(count, style: TextStyle(color: isActive ? Colors.white : Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w800)),
          )
        ],
      ),
    );
  }

  Widget _buildWordItem(String word, String pronunciation, String def, bool isMastered) {
    return Container(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(word, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textDark)),
                  const SizedBox(height: 4),
                  Text(pronunciation, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[400], letterSpacing: 0.5)),
                ],
              ),
              if (isMastered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: accentGold.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.stars_rounded, color: accentGold, size: 16),
                      const SizedBox(width: 6),
                      Text("MASTERED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accentGold, letterSpacing: 0.5)),
                    ],
                  ),
                )
            ],
          ),
          const SizedBox(height: 16),
          Text(def, style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}