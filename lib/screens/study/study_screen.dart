import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/app_models.dart';
import 'dart:math'; // Import để dùng hiệu ứng xoay

class StudyScreen extends StatefulWidget {
  final String? deckId; // Thêm tham số deckId (có thể null nếu học Daily Review)

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

  // Controller cho hiệu ứng lật
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
    // Khởi tạo animation
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
      final snapshot = await _dbRef
          .child("cards")
          .orderByChild("ownerId")
          .equalTo(user!.uid)
          .get();

      List<Flashcard> loadedCards = [];
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        data.forEach((key, value) {
          final card = Flashcard.fromMap(key, value);
          
          // LOGIC LỌC THẺ:
          // 1. Phải đến hạn (dueDate <= now)
          // 2. Nếu có widget.deckId thì phải đúng deck đó
          bool isDue = card.dueDate <= now;
          bool isCorrectDeck = widget.deckId == null || card.deckId == widget.deckId;

          if (isDue && isCorrectDeck) {
            loadedCards.add(card);
          }
        });
      }

      setState(() {
        cards = loadedCards;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print("Lỗi tải card: $e");
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
        // Reset animation về mặt trước cho thẻ tiếp theo
        if (_animationStatus != AnimationStatus.dismissed) {
           _controller.reset();
        }
      });
    } catch (e) {
      _showMessage("Lỗi cập nhật: $e");
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: colorBgLight,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (cards.isEmpty) {
      return Scaffold(
        backgroundColor: colorBgLight,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.black)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text("Bạn đã hoàn thành!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Không còn thẻ nào cần học trong bộ này.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: colorPrimary, foregroundColor: Colors.white),
                child: const Text("Quay lại"),
              ),
            ],
          ),
        ),
      );
    }

    // Nếu đã học hết trong session hiện tại
    if (currentIndex >= cards.length) {
       return Scaffold(
        backgroundColor: colorBgLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration, size: 80, color: Colors.orange),
              const SizedBox(height: 16),
              const Text("Tuyệt vời!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text("Đã ôn tập xong.", style: TextStyle(color: Colors.grey)),
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
    // Xác định mặt sau có đang hiện không
    bool isBackVisible = _animationStatus == AnimationStatus.completed || _animationStatus == AnimationStatus.forward;

    return Scaffold(
      backgroundColor: colorBgLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildProgressBar(),
            Expanded(
              child: Center(
                child: _buildFlashcardStack(currentCard),
              ),
            ),
            // Chỉ hiện nút đánh giá khi đã lật ra sau
            AnimatedOpacity(
              opacity: isBackVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildFooterControls(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: colorPrimary, size: 28),
          ),
          Column(
            children: [
              Text(
                "Đang học: ${currentIndex + 1}/${cards.length}",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const Text(
                "SRS LEARNING",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(width: 28), // Placeholder để cân giữa
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    double progress = cards.isNotEmpty ? (currentIndex + 1) / cards.length : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFFEEEEEE),
          color: colorPrimary,
          minHeight: 6,
        ),
      ),
    );
  }

  Widget _buildFlashcardStack(Flashcard card) {
    return GestureDetector(
      onTap: _flipCard,
      child: Transform(
        alignment: FractionalOffset.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(pi * _animation.value),
        child: Container(
          width: 320,
          height: 460,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 15)),
            ],
          ),
          alignment: Alignment.center,
          // Nếu xoay quá 90 độ (0.5) thì hiện mặt sau
          child: _animation.value <= 0.5
              ? _buildFrontSide(card.front)
              : _buildBackSide(card.back, card.example),
        ),
      ),
    );
  }

  Widget _buildFrontSide(String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 40),
        const Text(
          "CHẠM ĐỂ LẬT",
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBackSide(String back, String example) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi), // Xoay ngược lại text để đọc được
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            back,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2B5D78)),
          ),
          if (example.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: Text(
                example,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildFooterControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildRatingButton("Học Lại", Icons.replay, colorSrsAgain, () => _updateCard('again')),
          _buildRatingButton("Khó", Icons.help_outline, colorSrsHard, () => _updateCard('hard')),
          _buildRatingButton("Dễ", Icons.check_circle_outline, colorSrsEasy, () => _updateCard('easy')),
        ],
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