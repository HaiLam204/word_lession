import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/app_models.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  final Color primaryColor = const Color(0xFF3B8C88);
  final Color bgLight = const Color(0xFFF2F5F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Thống kê học tập", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF131616))),
              const SizedBox(height: 8),
              const Text("Theo dõi tiến độ của bạn mỗi ngày", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              
              StreamBuilder(
                stream: _dbRef.child("cards").orderByChild("ownerId").equalTo(user!.uid).onValue,
                builder: (context, cardSnapshot) {
                  if (!cardSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                  int totalCards = 0;
                  int masteredCards = 0; 
                  int learningCards = 0; 
                  int newCards = 0;

                  if (cardSnapshot.data!.snapshot.value != null) {
                    Map data = cardSnapshot.data!.snapshot.value as Map;
                    totalCards = data.length;
                    
                    data.forEach((key, value) {
                      final card = Flashcard.fromMap(key, value);
                      if (card.status == 'new') {
                        newCards++;
                      } else {
                        if (card.interval >= 21) {
                          masteredCards++;
                        } else {
                          learningCards++;
                        }
                      }
                    });
                  }
                  int totalLearned = masteredCards + learningCards;
                  double memoryRate = totalLearned == 0 ? 0 : (masteredCards / totalLearned);

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                        child: Column(
                          children: [
                            const Text("Tỷ lệ ghi nhớ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 24),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 150, height: 150,
                                  child: CircularProgressIndicator(
                                    value: memoryRate,
                                    strokeWidth: 15,
                                    backgroundColor: Colors.grey.shade200,
                                    color: primaryColor,
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text("${(memoryRate * 100).toInt()}%", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor)),
                                    const Text("Mastered", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text("Bạn đã nhớ rất kỹ $masteredCards từ trong số $totalLearned từ đã học!", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(child: _buildStatBox("Tổng số thẻ", totalCards.toString(), Icons.style, Colors.blue)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatBox("Đã Master", masteredCards.toString(), Icons.workspace_premium, Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      StreamBuilder(
                        stream: _dbRef.child("users/${user!.uid}/streak").onValue,
                        builder: (context, streakSnapshot) {
                          int streak = 0;
                          if (streakSnapshot.hasData && streakSnapshot.data!.snapshot.value != null) {
                            streak = streakSnapshot.data!.snapshot.value as int;
                          }
                          return _buildStatBox("Streak liên tục", "$streak ngày", Icons.local_fire_department, Colors.red, isFullWidth: true);
                        }
                      )
                    ],
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(String title, String value, IconData icon, Color color, {bool isFullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        mainAxisAlignment: isFullWidth ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: isFullWidth ? 20 : 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }
}