import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/app_models.dart';
import 'dart:math';

class NewWordScreen extends StatefulWidget {
  const NewWordScreen({super.key});

  @override
  State<NewWordScreen> createState() => _NewWordScreenState();
}

class _NewWordScreenState extends State<NewWordScreen> with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  List<Flashcard> newCards = [];
  int currentIndex = 0;
  bool isLoading = true;
  bool isFlipped = false;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _animation = Tween<double>(end: 1.0, begin: 0.0).animate(_controller)
      ..addListener(() { setState(() {}); });
    _loadNewCards();
  }

  Future<void> _loadNewCards() async {
    final snapshot = await _dbRef.child("cards").orderByChild("ownerId").equalTo(user!.uid).get();
    if (snapshot.exists) {
      Map data = snapshot.value as Map;
      List<Flashcard> temp = [];
      data.forEach((k, v) {
        final card = Flashcard.fromMap(k, v);
        if (card.status == 'new') temp.add(card);
      });
      setState(() {
        newCards = temp;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void _markAsLearned() async {
    Flashcard card = newCards[currentIndex];
    int now = DateTime.now().millisecondsSinceEpoch;
    await _dbRef.child("cards/${card.id}").update({
      "status": "learning",
      "dueDate": now + 86400000, 
      "interval": 1,
    });

    if (currentIndex < newCards.length - 1) {
      setState(() {
        currentIndex++;
        isFlipped = false;
        _controller.reset();
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      title: const Text("Tuyệt vời!"),
      content: const Text("Bạn đã học hết các từ mới."),
      actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text("Về trang chủ"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (newCards.isEmpty) return Scaffold(appBar: AppBar(), body: const Center(child: Text("Không có từ mới nào!")));

    Flashcard card = newCards[currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(title: Text("Học từ mới (${currentIndex + 1}/${newCards.length})"), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isFlipped) _controller.reverse(); else _controller.forward();
                isFlipped = !isFlipped;
              },
              child: Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(pi * _animation.value),
                  child: Container(
                    width: 320, height: 400,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                    alignment: Alignment.center,
                    child: _animation.value <= 0.5 
                      ? Text(card.front, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(pi),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(card.back, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF137FEC)), textAlign: TextAlign.center),
                              const SizedBox(height: 20),
                              Text(card.example, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(30),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _markAsLearned,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Đã nhớ từ này", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}