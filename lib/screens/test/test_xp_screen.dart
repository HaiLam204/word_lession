import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/leaderboard_service.dart';
import '../../services/streak_service.dart';

class TestXPScreen extends StatefulWidget {
  const TestXPScreen({super.key});

  @override
  State<TestXPScreen> createState() => _TestXPScreenState();
}

class _TestXPScreenState extends State<TestXPScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final LeaderboardService _leaderboardService = LeaderboardService();
  final StreakService _streakService = StreakService();
  
  int _currentXP = 0;
  int _totalDecks = 0;
  int _streak = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    if (user == null) return;

    try {
      DataSnapshot snapshot = await _dbRef.child('users/${user!.uid}').get();
      if (snapshot.exists && mounted) {
        Map userData = snapshot.value as Map;
        setState(() {
          _currentXP = userData['xp'] ?? 0;
          _totalDecks = userData['totalDecks'] ?? 0;
          _streak = userData['streak'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Lỗi load stats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addTestXP(int amount) async {
    if (user == null) return;

    try {
      await _leaderboardService.addXP(user!.uid, amount);
      await _loadUserStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Đã thêm $amount XP')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resetXP() async {
    if (user == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset XP'),
        content: const Text('Bạn có chắc muốn reset XP về 0?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbRef.child('users/${user!.uid}/xp').set(0);
        await _loadUserStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Đã reset XP về 0')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _testStreak() async {
    if (user == null) return;

    try {
      await _streakService.updateStreak(user!.uid);
      await _loadUserStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Đã cập nhật streak (giả lập học hôm nay)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resetStreak() async {
    if (user == null) return;

    try {
      await _streakService.resetStreak(user!.uid);
      await _loadUserStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Đã reset streak về 0')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _checkFirebaseRules() async {
    if (user == null) return;

    try {
      // Test read
      DataSnapshot snapshot = await _dbRef.child('users/${user!.uid}').get();
      bool canRead = snapshot.exists;
      
      // Get actual data
      Map? userData;
      if (snapshot.exists) {
        userData = snapshot.value as Map?;
      }

      // Test write
      bool canWrite = false;
      try {
        await _dbRef.child('users/${user!.uid}/xp').set(_currentXP);
        canWrite = true;
      } catch (e) {
        canWrite = false;
      }

      // Test query with orderByChild
      bool canQuery = false;
      try {
        DataSnapshot querySnapshot = await _dbRef
            .child('users')
            .orderByChild('xp')
            .limitToLast(10)
            .get();
        canQuery = querySnapshot.exists;
      } catch (e) {
        print('Query error: $e');
        canQuery = false;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Kiểm tra Firebase'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        canRead ? Icons.check_circle : Icons.error,
                        color: canRead ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text('Read: ${canRead ? "OK" : "FAILED"}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        canWrite ? Icons.check_circle : Icons.error,
                        color: canWrite ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text('Write: ${canWrite ? "OK" : "FAILED"}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        canQuery ? Icons.check_circle : Icons.error,
                        color: canQuery ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text('Query: ${canQuery ? "OK" : "FAILED"}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Dữ liệu Firebase:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (userData != null) ...[
                    Text('XP: ${userData['xp'] ?? "null"}'),
                    Text('TotalDecks: ${userData['totalDecks'] ?? "null"}'),
                    Text('Streak: ${userData['streak'] ?? "null"}'),
                  ] else
                    const Text('Không có dữ liệu', style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  if (!canRead || !canWrite || !canQuery)
                    const Text(
                      '⚠️ Vui lòng kiểm tra Firebase Rules!',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test XP')),
        body: const Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test XP & Leaderboard'),
        backgroundColor: const Color(0xFF3E8F8B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Stats
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E8F8B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3E8F8B)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Thống kê hiện tại',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow('🏆 XP', _currentXP.toString()),
                        _buildStatRow('📚 Tổng Decks', _totalDecks.toString()),
                        _buildStatRow('🔥 Streak', '$_streak ngày'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Test Buttons
                  const Text(
                    'Thêm XP Test',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTestButton('+10 XP', 10),
                      _buildTestButton('+50 XP', 50),
                      _buildTestButton('+100 XP', 100),
                      _buildTestButton('+500 XP', 500),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  const Text(
                    'Hành động',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loadUserStats,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Làm mới dữ liệu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3E8F8B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _checkFirebaseRules,
                      icon: const Icon(Icons.security),
                      label: const Text('Kiểm tra Firebase Rules'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testStreak,
                      icon: const Icon(Icons.local_fire_department),
                      label: const Text('Test Streak (giả lập học hôm nay)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _resetStreak,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Streak về 0'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _resetXP,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Reset XP về 0'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📝 Hướng dẫn test:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text('1. Nhấn "Kiểm tra Firebase Rules" để đảm bảo quyền truy cập'),
                        const Text('2. Nhấn các nút "+XP" để thêm điểm test'),
                        const Text('3. Vào tab Cộng đồng → Bảng xếp hạng để xem kết quả'),
                        const Text('4. Nhấn "Làm mới" nếu số liệu chưa cập nhật'),
                        const SizedBox(height: 8),
                        const Text(
                          '💡 Lưu ý: XP thật sẽ được cộng khi bạn học thẻ trong màn hình Study.',
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(String label, int xp) {
    return ElevatedButton(
      onPressed: () => _addTestXP(xp),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3E8F8B),
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }
}
