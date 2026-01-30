import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/app_models.dart';
import 'flashcard_session_screen.dart';
import 'new_word_screen.dart';
import 'quiz_screen.dart';

class StudyScreen extends StatefulWidget {
  final String? deckId;

  const StudyScreen({super.key, this.deckId});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  final Color primaryColor = const Color(0xFF137FEC);
  final Color bgLight = const Color(0xFFF6F7F8);
  final Color textDark = const Color(0xFF101922);

  @override
  void initState() {
    super.initState();
    if (widget.deckId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => FlashcardSessionScreen(deckId: widget.deckId)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deckId != null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        child: StreamBuilder(
          stream: _dbRef.child("cards").orderByChild("ownerId").equalTo(user!.uid).onValue,
          builder: (context, snapshot) {
            int dueCount = 0;
            int newCount = 0;
            int learnedCount = 0;

            if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
              Map data = snapshot.data!.snapshot.value as Map;
              int now = DateTime.now().millisecondsSinceEpoch;
              data.forEach((k, v) {
                final card = Flashcard.fromMap(k, v);
                if (card.status == 'new') newCount++;
                else learnedCount++;
                
                if (card.dueDate <= now && card.status != 'new') dueCount++;
              });
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(), 
                  _buildDailyReviewCard(dueCount),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text("Chế độ học tập", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  _buildLearningModesGrid(dueCount, newCount),
                  _buildDailyGoalTracker(learnedCount),
                ],
              ),
            );
          }
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Expanded( 
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF3B8C88).withOpacity(0.2),
                      child: Icon(Icons.person, color:Color(0xFF3B8C88)),
                    ),
                    const SizedBox(width: 12), 
                    Flexible( 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          const Text(
                            "Góc Học Tập", 
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)
                          ),
                          Text(
                            displayName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF101922)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_none, color: Colors.grey),
                  onPressed: () {},
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyReviewCard(int dueCount) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(16)), gradient: LinearGradient(colors: [Color(0xFF137FEC), Color(0xFF00D4FF)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: const Center(child: Icon(Icons.history_edu, color: Colors.white54, size: 60)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Từ cần ôn hôm nay: $dueCount", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Duy trì chuỗi học tập!", style: TextStyle(color: Colors.grey)),
                    ElevatedButton(
                      onPressed: dueCount > 0 ? () { Navigator.push(context, MaterialPageRoute(builder: (context) => const FlashcardSessionScreen())); } : null,
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text("Bắt đầu ôn tập"),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLearningModesGrid(int dueCount, int newCount) {
    final modes = [
      {"icon": Icons.update, "color": Colors.blue, "title": "Ôn tập định kỳ", "sub": "$dueCount từ đến hạn", "action": () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FlashcardSessionScreen()))},
      {"icon": Icons.add_box, "color": Colors.green, "title": "Học từ mới", "sub": "$newCount từ chưa học", "action": () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NewWordScreen()))},
      {"icon": Icons.quiz, "color": Colors.orange, "title": "Kiểm tra nhanh", "sub": "Quiz trắc nghiệm", "action": () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizScreen()))},
      {"icon": Icons.keyboard_voice, "color": Colors.purple, "title": "Nghe & Viết", "sub": "Đang phát triển...", "action": () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tính năng đang phát triển!"))); }},
    ];
    return GridView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.1, crossAxisSpacing: 16, mainAxisSpacing: 16), itemCount: modes.length, itemBuilder: (context, index) { final item = modes[index]; return GestureDetector(onTap: item['action'] as VoidCallback, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (item['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 30)), const Spacer(), Text(item['title'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)), Text(item['sub'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey))]))); });
  }

  Widget _buildDailyGoalTracker(int learnedCount) {
    int goal = 20; double progress = (learnedCount % goal) / goal;
    return Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: primaryColor.withOpacity(0.2))), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Tiến độ tổng quan", style: TextStyle(fontWeight: FontWeight.bold, color: textDark)), Text("$learnedCount từ đã học", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))]), const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white, color: primaryColor, minHeight: 10)), const SizedBox(height: 8), const Text("Hãy tiếp tục phát huy nhé!", style: TextStyle(fontSize: 12, color: Colors.grey))]));
  }
}