import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/app_models.dart';
import '../../services/srs_algorithm.dart';
import '../../services/leaderboard_service.dart';
import '../../services/streak_service.dart';
import 'dart:math';

class FlashcardSessionScreen extends StatefulWidget {
  final String? deckId;
  const FlashcardSessionScreen({super.key, this.deckId});

  @override
  State<FlashcardSessionScreen> createState() => _FlashcardSessionScreenState();
}

class _FlashcardSessionScreenState extends State<FlashcardSessionScreen>
    with SingleTickerProviderStateMixin {
  static const Color colorPrimary = Color(0xFF137FEC);
  static const Color colorBgLight = Color(0xFFF6F7F8);
  static const Color colorCorrect = Color(0xFF22C55E);
  static const Color colorWrong = Color(0xFFEF4444);

  // Animation (dùng cho flip card - chỉ khi học thẻ mới)
  late AnimationController _controller;
  late Animation<double> _animation;
  AnimationStatus _animationStatus = AnimationStatus.dismissed;

  final FlutterTts flutterTts = FlutterTts();
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final LeaderboardService _leaderboardService = LeaderboardService();
  final StreakService _streakService = StreakService();

  List<Flashcard> _newCards = [];      // status: new / learning
  List<Flashcard> _reviewCards = [];   // status: review
  int _newIndex = 0;
  int _reviewIndex = 0;
  bool _isLoading = true;
  String _srsIntensity = 'Cân bằng';

  // XP tracking
  int _sessionXP = 0;
  int _xpDelta = 0; // +/- hiển thị tạm thời

  // Quiz state (cho review cards)
  List<String> _quizOptions = [];
  int? _selectedOption;   // index đã chọn
  bool _quizAnswered = false;
  bool _quizCorrect = false;

  // Tất cả back values để tạo wrong answers
  List<String> _allBackValues = [];

  bool get _isReviewMode => _newIndex >= _newCards.length;
  bool get _sessionDone =>
      _newIndex >= _newCards.length && _reviewIndex >= _reviewCards.length;

  Flashcard? get _currentCard {
    if (!_isReviewMode && _newIndex < _newCards.length) return _newCards[_newIndex];
    if (_isReviewMode && _reviewIndex < _reviewCards.length) return _reviewCards[_reviewIndex];
    return null;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller)
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) => _animationStatus = s);
    _initTts();
    _loadUserSettings();
    _loadCards();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text, {String lang = "en-US"}) async {
    if (text.isNotEmpty) {
      await flutterTts.setLanguage(lang);
      await flutterTts.speak(text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadUserSettings() async {
    if (user != null) {
      try {
        DataSnapshot snapshot = await _dbRef.child('users/${user!.uid}/srsIntensity').get();
        if (snapshot.exists && mounted) {
          setState(() => _srsIntensity = snapshot.value as String? ?? 'Cân bằng');
        }
      } catch (_) {}
    }
  }

  Future<void> _loadCards() async {
    try {
      int now = DateTime.now().millisecondsSinceEpoch;
      List<Flashcard> newCards = [];
      List<Flashcard> reviewCards = [];
      List<String> allBacks = [];

      Query query;
      if (widget.deckId != null) {
        query = _dbRef.child("cards").orderByChild("deckId").equalTo(widget.deckId);
      } else {
        query = _dbRef.child("cards").orderByChild("ownerId").equalTo(user!.uid);
      }

      final snapshot = await query.get();
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        data.forEach((key, value) {
          final card = Flashcard.fromMap(key, value);
          allBacks.add(card.back);
          if (widget.deckId != null || card.dueDate <= now) {
            // Khi học theo deck cụ thể: chỉ load cards chưa đến hạn ôn hoặc còn mới
            if (card.status == 'review' && card.dueDate <= now) {
              reviewCards.add(card);
            } else if (card.status != 'review') {
              newCards.add(card);
            }
          }
        });
      }

      // Lấy thêm backs từ tất cả cards của user để có đủ wrong answers
      if (allBacks.length < 4 && user != null) {
        final allSnapshot = await _dbRef.child("cards").orderByChild("ownerId").equalTo(user!.uid).get();
        if (allSnapshot.exists) {
          Map data = allSnapshot.value as Map;
          data.forEach((key, value) {
            String back = (value as Map)['back'] ?? '';
            if (!allBacks.contains(back)) allBacks.add(back);
          });
        }
      }

      setState(() {
        _newCards = newCards;
        _reviewCards = reviewCards;
        _allBackValues = allBacks;
        _isLoading = false;
      });

      // Tạo quiz cho review card đầu tiên
      if (reviewCards.isNotEmpty) _generateQuiz(reviewCards[0]);
    } catch (e) {
      setState(() => _isLoading = false);
      print("Lỗi tải thẻ: $e");
    }
  }

  void _generateQuiz(Flashcard card) {
    List<String> options = [card.back];
    List<String> pool = _allBackValues.where((b) => b != card.back).toList()..shuffle();
    for (String b in pool) {
      if (options.length >= 4) break;
      options.add(b);
    }
    // Nếu không đủ 4, thêm placeholder
    while (options.length < 4) {
      options.add('---');
    }
    options.shuffle();
    setState(() {
      _quizOptions = options;
      _selectedOption = null;
      _quizAnswered = false;
      _quizCorrect = false;
    });
  }

  void _flipCard() {
    if (_animationStatus == AnimationStatus.dismissed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  // Xử lý nút SRS cho thẻ mới (flip card)
  void _handleNewCardRating(String rating) async {
    final card = _currentCard;
    if (card == null || user == null) return;

    SrsResult result = SrsAlgorithm.calculate(card, rating, intensity: _srsIntensity);
    String newStatus = card.status == 'new' ? 'learning' : (result.nextInterval > 1 ? 'review' : 'learning');

    try {
      await _dbRef.child("cards/${card.id}").update({
        'dueDate': result.nextDueDate,
        'interval': result.nextInterval,
        'easeFactor': result.nextEaseFactor,
        'status': newStatus,
        'lastReviewed': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print("Lỗi lưu thẻ: $e");
    }

    setState(() {
      _newIndex++;
      if (_animationStatus != AnimationStatus.dismissed) _controller.reset();
    });

    // Nếu chuyển sang review mode, chuẩn bị quiz
    if (_isReviewMode && _reviewIndex < _reviewCards.length) {
      _generateQuiz(_reviewCards[_reviewIndex]);
    }

    if (_sessionDone) _completeSession();
  }

  // Xử lý chọn đáp án quiz (review card)
  void _handleQuizAnswer(int selectedIndex) async {
    if (_quizAnswered) return;
    final card = _currentCard;
    if (card == null || user == null) return;

    bool correct = _quizOptions[selectedIndex] == card.back;
    setState(() {
      _selectedOption = selectedIndex;
      _quizAnswered = true;
      _quizCorrect = correct;
    });

    // Tính XP
    const int xpCorrect = 5;
    const int xpWrong = 3;

    if (correct) {
      await _leaderboardService.addXP(user!.uid, xpCorrect);
      setState(() {
        _sessionXP += xpCorrect;
        _xpDelta = xpCorrect;
      });
    } else {
      await _leaderboardService.subtractXP(user!.uid, xpWrong);
      setState(() {
        _sessionXP -= xpWrong;
        _xpDelta = -xpWrong;
      });
    }
  }

  // Sau khi xem kết quả quiz, bấm tiếp theo
  void _nextReviewCard(String rating) async {
    final card = _currentCard;
    if (card == null || user == null) return;

    SrsResult result = SrsAlgorithm.calculate(card, rating, intensity: _srsIntensity);
    try {
      await _dbRef.child("cards/${card.id}").update({
        'dueDate': result.nextDueDate,
        'interval': result.nextInterval,
        'easeFactor': result.nextEaseFactor,
        'status': 'review',
        'lastReviewed': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print("Lỗi lưu thẻ: $e");
    }

    setState(() {
      _reviewIndex++;
      _xpDelta = 0;
    });

    if (_reviewIndex < _reviewCards.length) {
      _generateQuiz(_reviewCards[_reviewIndex]);
    }

    if (_sessionDone) _completeSession();
  }

  Future<void> _completeSession() async {
    if (user != null) {
      try {
        // Bonus 50 XP khi hoàn thành session
        await _leaderboardService.addXP(user!.uid, 50);
        setState(() => _sessionXP += 50);
        await _streakService.updateStreak(user!.uid);
      } catch (e) {
        print("Lỗi hoàn thành session: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final totalCards = _newCards.length + _reviewCards.length;

    if (totalCards == 0) {
      return Scaffold(
        backgroundColor: colorBgLight,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.black)),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.style_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              widget.deckId == null ? "Hết bài ôn tập hôm nay!" : "Bộ thẻ này chưa có nội dung.",
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Quay lại")),
          ]),
        ),
      );
    }

    if (_sessionDone) return _buildCompletionScreen(totalCards);

    int currentProgress = _isReviewMode
        ? _newCards.length + _reviewIndex
        : _newIndex;

    return Scaffold(
      backgroundColor: colorBgLight,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(currentProgress, totalCards),
          Expanded(
            child: _isReviewMode ? _buildQuizView() : _buildFlipCardView(),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader(int current, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: colorPrimary, size: 28)),
          Column(children: [
            Text("${current + 1}/$total", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              _isReviewMode ? "Ôn tập" : "Học mới",
              style: TextStyle(fontSize: 11, color: _isReviewMode ? Colors.orange : colorPrimary),
            ),
          ]),
          // XP delta indicator
          AnimatedOpacity(
            opacity: _xpDelta != 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _xpDelta > 0 ? colorCorrect.withOpacity(0.15) : colorWrong.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _xpDelta > 0 ? '+$_xpDelta XP' : '$_xpDelta XP',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _xpDelta > 0 ? colorCorrect : colorWrong,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (current + 1) / total,
            backgroundColor: const Color(0xFFEEEEEE),
            color: _isReviewMode ? Colors.orange : colorPrimary,
            minHeight: 6,
          ),
        ),
      ]),
    );
  }

  // ---- FLIP CARD VIEW (thẻ mới) ----
  Widget _buildFlipCardView() {
    final card = _currentCard!;
    bool isBack = _animationStatus == AnimationStatus.completed || _animationStatus == AnimationStatus.forward;

    return Column(children: [
      Expanded(
        child: Center(
          child: GestureDetector(
            onTap: _flipCard,
            child: Transform(
              alignment: FractionalOffset.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(pi * _animation.value),
              child: Container(
                width: 320, height: 420,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
                ),
                alignment: Alignment.center,
                child: _animation.value <= 0.5
                    ? _buildCardFace(card.front, "TỪ VỰNG", true)
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi),
                        child: _buildCardFace(card.back, "NGHĨA", false, sub: card.example),
                      ),
              ),
            ),
          ),
        ),
      ),
      if (isBack)
        Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildSrsButton("Học Lại", const Color(0xFFEF4444), () => _handleNewCardRating('again')),
            _buildSrsButton("Khó", const Color(0xFFFACC15), () => _handleNewCardRating('hard')),
            _buildSrsButton("Dễ", const Color(0xFF22C55E), () => _handleNewCardRating('easy')),
          ]),
        )
      else
        Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Text("Nhấn vào thẻ để lật", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ),
    ]);
  }

  Widget _buildCardFace(String text, String label, bool isFront, {String? sub}) {
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isFront ? 30 : 24,
              fontWeight: FontWeight.bold,
              color: isFront ? Colors.black : colorPrimary,
            ),
          ),
          if (sub != null && sub.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13)),
            ),
          const SizedBox(height: 36),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
        ]),
      ),
      Positioned(
        top: 12, right: 12,
        child: IconButton(
          icon: Icon(Icons.volume_up_rounded, color: isFront ? Colors.grey : colorPrimary, size: 26),
          onPressed: () => _speak(text, lang: isFront ? "en-US" : "vi-VN"),
        ),
      ),
    ]);
  }

  Widget _buildSrsButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 100, height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ---- QUIZ VIEW (ôn tập) ----
  Widget _buildQuizView() {
    final card = _currentCard!;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        // Question card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16)],
          ),
          child: Column(children: [
            const Text("Nghĩa của từ này là gì?", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            Text(
              card.front,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            if (card.example.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '"${card.example}"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, color: colorPrimary),
              onPressed: () => _speak(card.front),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        const Text("Chọn đáp án đúng:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 12),
        // Options
        ...List.generate(_quizOptions.length, (i) => _buildOption(i, card.back)),
        const SizedBox(height: 20),
        // Sau khi trả lời: hiện kết quả + nút tiếp theo
        if (_quizAnswered) _buildQuizResult(card),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildOption(int index, String correctAnswer) {
    Color bgColor = Colors.white;
    Color borderColor = Colors.grey.shade200;
    Color textColor = Colors.black87;
    Widget? trailingIcon;

    if (_quizAnswered) {
      bool isCorrect = _quizOptions[index] == correctAnswer;
      bool isSelected = _selectedOption == index;

      if (isCorrect) {
        bgColor = colorCorrect.withOpacity(0.1);
        borderColor = colorCorrect;
        textColor = colorCorrect;
        trailingIcon = const Icon(Icons.check_circle, color: colorCorrect, size: 20);
      } else if (isSelected && !isCorrect) {
        bgColor = colorWrong.withOpacity(0.1);
        borderColor = colorWrong;
        textColor = colorWrong;
        trailingIcon = const Icon(Icons.cancel, color: colorWrong, size: 20);
      }
    }

    return GestureDetector(
      onTap: () => _handleQuizAnswer(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              ['A', 'B', 'C', 'D'][index],
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(_quizOptions[index], style: TextStyle(fontSize: 15, color: textColor, fontWeight: FontWeight.w500))),
          if (trailingIcon != null) trailingIcon,
        ]),
      ),
    );
  }

  Widget _buildQuizResult(Flashcard card) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _quizCorrect ? colorCorrect.withOpacity(0.1) : colorWrong.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _quizCorrect ? colorCorrect : colorWrong),
        ),
        child: Row(children: [
          Icon(_quizCorrect ? Icons.check_circle : Icons.cancel, color: _quizCorrect ? colorCorrect : colorWrong),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _quizCorrect ? 'Chính xác! +5 XP' : 'Sai rồi! -3 XP\nĐáp án: ${card.back}',
              style: TextStyle(color: _quizCorrect ? colorCorrect : colorWrong, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => _nextReviewCard(_quizCorrect ? 'easy' : 'again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text("Tiếp theo", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }

  // ---- COMPLETION SCREEN ----
  Widget _buildCompletionScreen(int totalCards) {
    return Scaffold(
      backgroundColor: colorBgLight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.celebration, size: 80, color: Colors.orange),
            const SizedBox(height: 16),
            const Text("Hoàn thành xuất sắc!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Bạn đã học $totalCards thẻ hôm nay.", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16)],
              ),
              child: Column(children: [
                const Text('🎉 XP Kiếm Được', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '+$_sessionXP XP',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF3E8F8B)),
                ),
                const SizedBox(height: 4),
                const Text('Bao gồm +50 XP thưởng hoàn thành', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _statChip('📖 Học mới', '${_newCards.length}'),
                  _statChip('🔄 Ôn tập', '${_reviewCards.length}'),
                ]),
              ]),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Về trang chủ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ]);
  }
}
