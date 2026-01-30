import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/app_models.dart';
import 'dart:math';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  List<Flashcard> allCards = [];
  List<Flashcard> quizCards = [];
  int currentIndex = 0;
  int score = 0;
  bool isLoading = true;
  
  List<String> currentOptions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final snapshot = await _dbRef.child("cards").orderByChild("ownerId").equalTo(user!.uid).get();
    if (snapshot.exists) {
      Map data = snapshot.value as Map;
      List<Flashcard> temp = [];
      data.forEach((k, v) => temp.add(Flashcard.fromMap(k, v)));
      
      temp.shuffle();
      setState(() {
        allCards = List.from(temp);
        quizCards = temp.take(10).toList();
        isLoading = false;
        if (quizCards.isNotEmpty) _generateOptions();
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void _generateOptions() {
    Flashcard current = quizCards[currentIndex];
    Set<String> options = {current.back}; 
    
    Random random = Random();
    while (options.length < 4 && options.length <= allCards.length) {
      String randomBack = allCards[random.nextInt(allCards.length)].back;
      options.add(randomBack);
    }
    
    setState(() {
      currentOptions = options.toList()..shuffle();
    });
  }

  void _checkAnswer(String selected) {
    bool isCorrect = selected == quizCards[currentIndex].back;
    
    if (isCorrect) score++;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: isCorrect ? Colors.green : Colors.red, size: 50),
        content: Text(isCorrect ? "Chính xác!" : "Sai rồi. Đáp án là:\n${quizCards[currentIndex].back}", textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (currentIndex < quizCards.length - 1) {
                setState(() {
                  currentIndex++;
                  _generateOptions();
                });
              } else {
                _showResult();
              }
            },
            child: const Text("Tiếp tục"),
          )
        ],
      ),
    );
  }

  void _showResult() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      title: const Text("Kết quả Quiz"),
      content: Text("Bạn trả lời đúng $score/${quizCards.length} câu."),
      actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text("Kết thúc"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (quizCards.isEmpty) return Scaffold(appBar: AppBar(), body: const Center(child: Text("Cần ít nhất 4 từ vựng để tạo Quiz!")));

    Flashcard card = quizCards[currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(title: Text("Quiz (${currentIndex + 1}/${quizCards.length})"), backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]),
              child: Column(
                children: [
                  const Text("Nghĩa của từ này là gì?", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Text(card.front, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ...currentOptions.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => _checkAnswer(opt),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFF137FEC)),
                  ),
                  child: Text(opt, style: const TextStyle(fontSize: 16, color: Color(0xFF101922))),
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
}