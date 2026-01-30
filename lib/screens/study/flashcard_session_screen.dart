import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_tts/flutter_tts.dart'; // 1. Import thư viện
import '../../models/app_models.dart';
import '../../services/srs_algorithm.dart'; 
import 'dart:math';

class FlashcardSessionScreen extends StatefulWidget {
  final String? deckId; 

  const FlashcardSessionScreen({super.key, this.deckId});

  @override
  State<FlashcardSessionScreen> createState() => _FlashcardSessionScreenState();
}

class _FlashcardSessionScreenState extends State<FlashcardSessionScreen> with SingleTickerProviderStateMixin {
  // Màu sắc
  static const Color colorPrimary = Color(0xFF137FEC);
  static const Color colorBgLight = Color(0xFFF6F7F8);
  static const Color colorSrsAgain = Color(0xFFEF4444);
  static const Color colorSrsHard = Color(0xFFFACC15);
  static const Color colorSrsEasy = Color(0xFF22C55E);

  // Animation
  late AnimationController _controller;
  late Animation<double> _animation;
  AnimationStatus _animationStatus = AnimationStatus.dismissed;
  
  // TTS (Text to Speech)
  final FlutterTts flutterTts = FlutterTts(); // 2. Khởi tạo TTS

  // Firebase
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  List<Flashcard> cards = [];
  int currentIndex = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Cấu hình Animation
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animation = Tween<double>(end: 1.0, begin: 0.0).animate(_controller)
      ..addListener(() { setState(() {}); })
      ..addStatusListener((status) { _animationStatus = status; });
    
    // Cấu hình TTS
    _initTts();

    _loadCards();
  }

  // 3. Hàm cài đặt TTS
  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US"); // Mặc định tiếng Anh
    await flutterTts.setSpeechRate(0.5);   // Tốc độ đọc vừa phải (0.0 đến 1.0)
    await flutterTts.setVolume(1.0);       // Âm lượng lớn nhất
    await flutterTts.setPitch(1.0);        // Cao độ bình thường
    
    // (Tuỳ chọn) Cấu hình riêng cho iOS để nghe loa ngoài
    await flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers
        ],
        IosTextToSpeechAudioMode.defaultMode
    );
  }

  // 4. Hàm đọc
  Future<void> _speak(String text, {String lang = "en-US"}) async {
    if (text.isNotEmpty) {
      await flutterTts.setLanguage(lang);
      await flutterTts.speak(text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    flutterTts.stop(); // Dừng đọc khi thoát màn hình
    super.dispose();
  }

  Future<void> _loadCards() async {
    // ... (Giữ nguyên logic tải thẻ của bạn) ...
    try {
      int now = DateTime.now().millisecondsSinceEpoch;
      List<Flashcard> loadedCards = [];

      if (widget.deckId != null) {
        final snapshot = await _dbRef.child("cards").orderByChild("deckId").equalTo(widget.deckId).get();
        if (snapshot.exists) {
          Map data = snapshot.value as Map;
          data.forEach((key, value) {
            loadedCards.add(Flashcard.fromMap(key, value));
          });
        }
      } else {
        final snapshot = await _dbRef.child("cards").orderByChild("ownerId").equalTo(user!.uid).get();
        if (snapshot.exists) {
          Map data = snapshot.value as Map;
          data.forEach((key, value) {
            final card = Flashcard.fromMap(key, value);
            if (card.dueDate <= now) {
              loadedCards.add(card);
            }
          });
        }
      }

      loadedCards.sort((a, b) {
        bool aDue = a.dueDate <= now;
        bool bDue = b.dueDate <= now;
        if (aDue && !bDue) return -1; 
        if (!aDue && bDue) return 1;  
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
    // ... (Giữ nguyên logic SRS của bạn) ...
    if (currentIndex >= cards.length) return;
    Flashcard card = cards[currentIndex];
    
    if (card.id.isNotEmpty && user != null) { 
       SrsResult result = SrsAlgorithm.calculate(card, rating);

       String newStatus = card.status;
       if (card.status == 'new') {
         newStatus = 'learning';
       } else if (result.nextInterval > 1) {
         newStatus = 'review';
       }

       try {
         await _dbRef.child("cards/${card.id}").update({
           'dueDate': result.nextDueDate,
           'interval': result.nextInterval,
           'easeFactor': result.nextEaseFactor,
           'status': newStatus,
           'lastReviewed': DateTime.now().millisecondsSinceEpoch
         });
       } catch (e) {
         print("Lỗi lưu: $e");
       }
    }

    setState(() {
      currentIndex++;
      if (_animationStatus != AnimationStatus.dismissed) _controller.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    if (cards.isEmpty) {
      return Scaffold(
        backgroundColor: colorBgLight,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.black)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.style_outlined, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                widget.deckId == null ? "Hết bài ôn tập hôm nay!" : "Bộ thẻ này chưa có nội dung.", 
                style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Quay lại")),
            ],
          ),
        ),
      );
    }

    if (currentIndex >= cards.length) {
       return Scaffold(
        backgroundColor: colorBgLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration, size: 80, color: Colors.orange),
              const SizedBox(height: 16),
              const Text("Hoàn thành xuất sắc!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Bạn đã ôn tập hết các thẻ trong danh sách.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Về trang chủ")),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: colorPrimary, size: 28)),
                  Text("${currentIndex + 1}/${cards.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 28),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: (currentIndex + 1) / cards.length, backgroundColor: const Color(0xFFEEEEEE), color: colorPrimary, minHeight: 6)),
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
                      // Xoá padding ở đây để Stack full size
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
                      alignment: Alignment.center,
                      child: _animation.value <= 0.5 
                        // --- MẶT TRƯỚC (CÂU HỎI) ---
                        ? _buildCardSide(
                            text: currentCard.front, 
                            label: "CÂU HỎI", 
                            isFront: true
                          )
                        // --- MẶT SAU (ĐÁP ÁN) ---
                        : Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(pi),
                            child: _buildCardSide(
                              text: currentCard.back, 
                              label: "ĐÁP ÁN", 
                              subText: currentCard.example,
                              isFront: false
                            ),
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
                    _buildButton("Học Lại", colorSrsAgain, () => _updateCard('again')),
                    _buildButton("Khó", colorSrsHard, () => _updateCard('hard')),
                    _buildButton("Dễ", colorSrsEasy, () => _updateCard('easy')),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }

  // Widget hiển thị nội dung thẻ + Nút loa
  Widget _buildCardSide({required String text, required String label, String? subText, required bool isFront}) {
    return Stack(
      children: [
        // Nội dung chính
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text, 
                textAlign: TextAlign.center, 
                style: TextStyle(
                  fontSize: isFront ? 32 : 26, 
                  fontWeight: FontWeight.bold,
                  color: isFront ? Colors.black : colorPrimary
                )
              ),
              if (subText != null && subText.isNotEmpty) 
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(subText, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                ),
              const SizedBox(height: 40),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
            ],
          ),
        ),
        
        // Nút Loa ở góc phải trên
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            icon: Icon(Icons.volume_up_rounded, color: isFront ? Colors.grey : colorPrimary, size: 28),
            onPressed: () {
              // Nếu là mặt trước (thường là Tiếng Anh) -> en-US
              // Nếu là mặt sau (thường là Tiếng Việt) -> vi-VN
              _speak(text, lang: isFront ? "en-US" : "vi-VN");
            },
          ),
        )
      ],
    );
  }

  Widget _buildButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 100, height: 50,
      child: ElevatedButton(
        onPressed: onTap, 
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: EdgeInsets.zero),
        child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
      ),
    );
  }
}