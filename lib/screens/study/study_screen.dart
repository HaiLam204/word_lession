import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/app_models.dart';
import 'dart:math';

class StudyScreen extends StatefulWidget {
  final String? deckId; // Nếu null -> Học Daily Review (chỉ thẻ đến hạn)

  const StudyScreen({super.key, this.deckId});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> with SingleTickerProviderStateMixin {
  static const Color colorPrimary = Color(0xFF2B5D78);
  static const Color colorBgLight = Color(0xFFF9FAFB);
  static const Color colorSrsAgain = Color(0xFFEF4444);
  static const Color colorSrsHard = Color(0xFFFACC15);
  static const Color colorSrsEasy = Color(0xFF22C55E);

  late AnimationController _controller;
  late Animation<double> _animation;
  AnimationStatus _animationStatus = AnimationStatus.dismissed;
  
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  List<Flashcard> cards = [];
  int currentIndex = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animation = Tween<double>(end: 1.0, begin: 0.0).animate(_controller)
      ..addListener(() { setState(() {}); })
      ..addStatusListener((status) { _animationStatus = status; });
    _loadCards();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    try {
      int now = DateTime.now().millisecondsSinceEpoch;
      final snapshot = await _dbRef.child("cards").orderByChild("ownerId").equalTo(user!.uid).get();

      List<Flashcard> loadedCards = [];
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        data.forEach((key, value) {
          final card = Flashcard.fromMap(key, value);
          
          bool isDue = card.dueDate <= now;
          
          // LOGIC LỌC THẺ MỚI:
          if (widget.deckId == null) {
            // 1. Daily Review: Chỉ lấy thẻ ĐẾN HẠN
            if (isDue) loadedCards.add(card);
          } else {
            // 2. Deck Study: Lấy TẤT CẢ thẻ của deck đó (để học lại được)
            if (card.deckId == widget.deckId) {
              loadedCards.add(card);
            }
          }
        });
      }

      // SẮP XẾP ƯU TIÊN:
      // 1. Thẻ đến hạn (Due) lên trước.
      // 2. Thẻ chưa đến hạn ra sau.
      loadedCards.sort((a, b) {
        bool aDue = a.dueDate <= now;
        bool bDue = b.dueDate <= now;
        
        if (aDue && !bDue) return -1; // a lên trước
        if (!aDue && bDue) return 1;  // b lên trước
        
        // Nếu cùng trạng thái, xếp theo thời gian (cũ nhất lên trước)
        return a.dueDate.compareTo(b.dueDate);
      });

      setState(() {
        cards = loadedCards;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print("Lỗi tải thẻ: $e");
    }
  }

  void _flipCard() {
    if (_animationStatus == AnimationStatus.dismissed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _updateCard(String rating) async {
    if (currentIndex >= cards.length) return;
    Flashcard card = cards[currentIndex];
    int now = DateTime.now().millisecondsSinceEpoch;
    int newInterval = card.interval;
    double newEaseFactor = card.easeFactor;

    // Logic SRS cơ bản
    if (rating == 'again') {
      newInterval = 1;
    } else if (rating == 'hard') {
      newInterval = (card.interval * 1.2).toInt();
      newEaseFactor = (card.easeFactor - 0.2).clamp(1.3, 2.5);
    } else if (rating == 'easy') {
      newInterval = (card.interval * 2.5).toInt();
      if (newInterval == 0) newInterval = 3;
      newEaseFactor = (card.easeFactor + 0.1).clamp(1.3, 2.5);
    }

    int newDueDate = now + (newInterval * 24 * 60 * 60 * 1000);
    
    try {
      await _dbRef.child("cards/${card.id}").update({
        'dueDate': newDueDate,
        'interval': newInterval,
        'easeFactor': newEaseFactor,
        'status': 'review',
      });

      setState(() {
        currentIndex++;
        if (_animationStatus != AnimationStatus.dismissed) _controller.reset();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    // Trường hợp deck rỗng (mới tạo chưa có thẻ)
    if (cards.isEmpty) {
      return Scaffold(
        backgroundColor: colorBgLight,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.black)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sentiment_dissatisfied, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Chưa có thẻ nào!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Hãy thêm thẻ mới vào bộ này nhé.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Quay lại"),
              ),
            ],
          ),
        ),
      );
    }

    // Trường hợp đã học hết danh sách
    if (currentIndex >= cards.length) {
       return Scaffold(
        backgroundColor: colorBgLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration, size: 80, color: Colors.orange),
              const SizedBox(height: 16),
              const Text("Hoàn thành!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                widget.deckId == null ? "Đã xong bài tập hôm nay." : "Đã ôn tập hết bộ thẻ này.", 
                style: const TextStyle(color: Colors.grey)
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Về trang chủ"),
              ),
            ],
          ),
        ),
      );
    }

    Flashcard currentCard = cards[currentIndex];
    bool isBackVisible = _animationStatus == AnimationStatus.completed || _animationStatus == AnimationStatus.forward;

    return Scaffold(
      backgroundColor: colorBgLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: colorPrimary, size: 28)),
                  const Expanded(child: Center(child: Text("SRS LEARNING", style: TextStyle(fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 28),
                ],
              ),
            ),
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (currentIndex + 1) / cards.length,
                  backgroundColor: const Color(0xFFEEEEEE),
                  color: colorPrimary,
                  minHeight: 6,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _flipCard,
                  child: Transform(
                    alignment: FractionalOffset.center,
                    transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(pi * _animation.value),
                    child: Container(
                      width: 320, height: 460,
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
                      ),
                      alignment: Alignment.center,
                      child: _animation.value <= 0.5 
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(currentCard.front, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 40),
                            const Text("CHẠM ĐỂ LẬT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
                          ])
                        : Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(pi),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(currentCard.back, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: colorPrimary)),
                                if (currentCard.example.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(currentCard.example, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
                            ]),
                          ),
                    ),
                  ),
                ),
              ),
            ),
            if (isBackVisible)
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRatingButton("Học Lại", Icons.replay, colorSrsAgain, () => _updateCard('again')),
                    _buildRatingButton("Khó", Icons.help_outline, colorSrsHard, () => _updateCard('hard')),
                    _buildRatingButton("Dễ", Icons.check_circle_outline, colorSrsEasy, () => _updateCard('easy')),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }
}