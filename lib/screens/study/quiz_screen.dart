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
  bool isFinished = false; 
  
  List<String> currentOptions = [];
  List<Map<String, dynamic>> results = []; 

  final Color primaryColor = const Color(0xFF137FEC);

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
        
        if (allCards.length >= 4) {
          quizCards = temp.take(10).toList(); 
          _generateOptions();
        }
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void _generateOptions() {
    if (quizCards.isEmpty || currentIndex >= quizCards.length) return;

    Flashcard current = quizCards[currentIndex];
    Set<String> options = {current.back}; 
    
    Random random = Random();
    int maxAttempts = 50; 
    int attempts = 0;

    while (options.length < 4 && attempts < maxAttempts) {
      String randomBack = allCards[random.nextInt(allCards.length)].back;
      if (randomBack.trim().isNotEmpty) {
        options.add(randomBack);
      }
      attempts++;
    }
    
    int dummy = 1;
    while (options.length < 4) {
      options.add("Đáp án khác $dummy");
      dummy++;
    }

    setState(() {
      currentOptions = options.toList()..shuffle();
    });
  }

  void _checkAnswer(String selected) {
    bool isCorrect = selected == quizCards[currentIndex].back;
    if (isCorrect) score++;

    results.add({
      'question': quizCards[currentIndex].front,
      'correctAnswer': quizCards[currentIndex].back,
      'userAnswer': selected,
      'isCorrect': isCorrect,
    });

    if (currentIndex < quizCards.length - 1) {
      setState(() {
        currentIndex++;
        _generateOptions();
      });
    } else {
      setState(() {
        isFinished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (allCards.length < 4) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.black)), 
        body: const Center(child: Text("Cần ít nhất 4 từ vựng trong thư viện để tạo bài kiểm tra!", style: TextStyle(fontWeight: FontWeight.bold)))
      );
    }

    if (isFinished) {
      return _buildResultScreen();
    }

    Flashcard card = quizCards[currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(title: Text("Câu ${currentIndex + 1}/${quizCards.length}"), backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (currentIndex + 1) / quizCards.length,
              backgroundColor: Colors.grey.shade200,
              color: primaryColor,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(32),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
              child: Column(
                children: [
                  const Text("Chọn nghĩa đúng của từ:", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
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
                height: 56,
                child: OutlinedButton(
                  onPressed: () => _checkAnswer(opt),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade300, width: 2),
                  ),
                  child: Text(opt, style: const TextStyle(fontSize: 16, color: Color(0xFF101922), fontWeight: FontWeight.w600)),
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    double percentage = score / quizCards.length;
    Color scoreColor = percentage >= 0.8 ? Colors.green : (percentage >= 0.5 ? Colors.orange : Colors.red);
    String message = percentage >= 0.8 ? "Xuất sắc!" : (percentage >= 0.5 ? "Cố lên nhé!" : "Cần ôn tập thêm!");

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(title: const Text("Kết quả kiểm tra"), centerTitle: true, automaticallyImplyLeading: false),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              children: [
                Text(message, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: scoreColor)),
                const SizedBox(height: 8),
                Text("Điểm của bạn: $score/${quizCards.length}", style: const TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(value: percentage, color: scoreColor, backgroundColor: Colors.grey.shade200, minHeight: 12),
                )
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(alignment: Alignment.centerLeft, child: Text("Chi tiết câu hỏi:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final res = results[index];
                bool isCorrect = res['isCorrect'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: isCorrect ? Colors.green : Colors.red, size: 30),
                    title: Text(res['question'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text("Bạn chọn: ${res['userAnswer']}", style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
                        if (!isCorrect)
                          Text("Đáp án đúng: ${res['correctAnswer']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Về trang chủ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          )
        ],
      ),
    );
  }
}