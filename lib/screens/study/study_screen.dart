import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/app_models.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  static const Color colorPrimary = Color(0xFF2B5D78);
  static const Color colorBgLight = Color(0xFFF9FAFB);
  static const Color colorSrsAgain = Color(0xFFEF4444);
  static const Color colorSrsHard = Color(0xFFFACC15);
  static const Color colorSrsEasy = Color(0xFF22C55E);

  bool isFlipped = false;
  
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  List<Flashcard> cards = [];
  int currentIndex = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
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
          if (card.dueDate <= now) {
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
    setState(() {
      isFlipped = !isFlipped;
    });
  }

  void _updateCard(String rating) async {
    if (currentIndex >= cards.length) return;

    Flashcard card = cards[currentIndex];
    int now = DateTime.now().millisecondsSinceEpoch;

    // Cập nhật dueDate theo rating (Simple SRS)
    int newInterval = card.interval;
    double newEaseFactor = card.easeFactor;

    if (rating == 'again') {
      newInterval = 1; // Lặp lại ngày hôm sau
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

      // Chuyển sang card tiếp theo
      setState(() {
        isFlipped = false;
        currentIndex++;
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Không có từ để học hôm nay", style: TextStyle(fontSize: 18, color: Colors.grey)),
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

    Flashcard currentCard = cards[currentIndex];

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
            _buildFooterControls(),
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
                "${currentIndex + 1} Study Session",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              Text(
                "VOCABULARY BOOST",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1.2),
              ),
            ],
          ),
          const Icon(Icons.settings, color: Colors.grey, size: 24),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    double progress = cards.isNotEmpty ? (currentIndex + 1) / cards.length : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("CURRENT PROGRESS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorPrimary)),
              Text("${currentIndex + 1} / ${cards.length} Cards", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFEEEEEE),
              color: colorPrimary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcardStack(Flashcard card) {
    return SizedBox(
      width: 320,
      height: 480,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -20, 
            left: -20, 
            child: Container(
              width: 150, 
              height: 150, 
              decoration: BoxDecoration(
                color: colorPrimary.withOpacity(0.05), 
                shape: BoxShape.circle
              )
            )
          ),
          
          Positioned(
            bottom: 0,
            child: Transform.scale(
              scale: 0.9,
              child: Container(
                width: 320, 
                height: 480,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4), 
                  borderRadius: BorderRadius.circular(24)
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            child: Transform.scale(
              scale: 0.95,
              child: Container(
                width: 320, 
                height: 480,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6), 
                  borderRadius: BorderRadius.circular(24)
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            child: GestureDetector(
              onTap: _flipCard,
              child: Container(
                width: 320, 
                height: 460,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 15)),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 4, 
                      width: double.infinity, 
                      decoration: BoxDecoration(
                        color: colorPrimary.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(2)
                      )
                    ),
                    
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorPrimary.withOpacity(0.05), 
                          shape: BoxShape.circle
                        ),
                        child: const Icon(Icons.volume_up, color: colorPrimary, size: 24),
                      ),
                    ),

                    Column(
                      children: [
                        Text(
                          card.front, 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF111827))
                        ),
                        const SizedBox(height: 8),
                        Text(
                          card.example.isNotEmpty ? card.example : "Pronunciation", 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey, fontWeight: FontWeight.w300)
                        ),
                        
                        if (isFlipped) ...[
                          const SizedBox(height: 32),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          const SizedBox(height: 32),
                          Text(
                            card.back,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF374151)),
                          ),
                        ]
                      ],
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.touch_app, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          "TAP TO FLIP", 
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        children: [
          const Text(
            "HOW WELL DID YOU KNOW THIS?", 
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRatingButton("Again", Icons.history, colorSrsAgain, () => _updateCard('again')),
              _buildRatingButton("Hard", Icons.bolt, colorSrsHard, () => _updateCard('hard')),
              _buildRatingButton("Easy", Icons.sentiment_satisfied_alt, colorSrsEasy, () => _updateCard('easy')),
            ],
          ),
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
            width: 64, 
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }
}