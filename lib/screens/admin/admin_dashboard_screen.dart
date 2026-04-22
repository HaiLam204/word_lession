import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Stats
  int _totalUsers = 0;
  int _activeToday = 0;
  int _activeThisWeek = 0;
  int _totalDecks = 0;
  int _totalCards = 0;
  List<Map<String, dynamic>> _topDecks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadUserStats(),
        _loadDeckCardStats(),
        _loadTopDecks(),
      ]);
    } catch (e) {
      print('Lỗi load stats: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserStats() async {
    DataSnapshot snap = await _dbRef.child('users').get();
    if (!snap.exists) return;

    Map data = snap.value as Map;
    int total = data.length;
    int today = 0;
    int week = 0;

    int now = DateTime.now().millisecondsSinceEpoch;
    int startOfToday = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0).millisecondsSinceEpoch;
    int startOfWeek = now - 7 * 24 * 60 * 60 * 1000;

    data.forEach((key, value) {
      Map user = value as Map;
      int lastStudy = user['lastStudyDate'] ?? 0;
      if (lastStudy >= startOfToday) today++;
      if (lastStudy >= startOfWeek) week++;
    });

    if (mounted) setState(() {
      _totalUsers = total;
      _activeToday = today;
      _activeThisWeek = week;
    });
  }

  Future<void> _loadDeckCardStats() async {
    final deckSnap = await _dbRef.child('decks').get();
    final cardSnap = await _dbRef.child('cards').get();

    if (mounted) setState(() {
      _totalDecks = deckSnap.exists ? (deckSnap.value as Map).length : 0;
      _totalCards = cardSnap.exists ? (cardSnap.value as Map).length : 0;
    });
  }

  Future<void> _loadTopDecks() async {
    DataSnapshot snap = await _dbRef.child('decks').get();
    if (!snap.exists) return;

    Map data = snap.value as Map;
    List<Map<String, dynamic>> decks = [];

    data.forEach((key, value) {
      Map deck = value as Map;
      if (deck['isPublic'] == true) {
        decks.add({
          'id': key,
          'name': deck['name'] ?? 'Untitled',
          'likes': deck['likes'] ?? 0,
          'saves': deck['saves'] ?? 0,
          'cardCount': deck['cardCount'] ?? 0,
        });
      }
    });

    decks.sort((a, b) => ((b['likes'] + b['saves']) as int).compareTo((a['likes'] + a['saves']) as int));

    if (mounted) setState(() {
      _topDecks = decks.take(5).toList();
    });
  }

  void _showBroadcastDialog() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String selectedType = 'system';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.campaign, color: Color(0xFF3B8C88)),
            SizedBox(width: 8),
            Text('Gửi thông báo broadcast'),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Nội dung *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Loại thông báo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('🔔 Hệ thống')),
                  DropdownMenuItem(value: 'update', child: Text('🆕 Cập nhật')),
                  DropdownMenuItem(value: 'maintenance', child: Text('🔧 Bảo trì')),
                  DropdownMenuItem(value: 'event', child: Text('🎉 Sự kiện')),
                ],
                onChanged: (v) => setDialogState(() => selectedType = v!),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B8C88), foregroundColor: Colors.white),
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Gửi tất cả'),
              onPressed: () async {
                String title = titleCtrl.text.trim();
                String msg = msgCtrl.text.trim();
                if (title.isEmpty || msg.isEmpty) return;
                Navigator.pop(ctx);
                await _sendBroadcast(title, msg, selectedType);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendBroadcast(String title, String message, String type) async {
    try {
      DataSnapshot usersSnap = await _dbRef.child('users').get();
      if (!usersSnap.exists) return;

      Map users = usersSnap.value as Map;
      int now = DateTime.now().millisecondsSinceEpoch;
      int count = 0;

      for (String uid in users.keys) {
        await _dbRef.child('notifications/$uid').push().set({
          'title': title,
          'message': message,
          'type': type,
          'timestamp': now,
          'isRead': false,
          'isBroadcast': true,
        });
        count++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Đã gửi thông báo đến $count người dùng'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF3B8C88)),
            onPressed: _loadStats,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // User stats
                  _sectionHeader('👥 Người dùng'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _statCard('Tổng users', '$_totalUsers', Icons.people, Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('Active hôm nay', '$_activeToday', Icons.today, Colors.green)),
                  ]),
                  const SizedBox(height: 12),
                  _statCard('Active 7 ngày qua', '$_activeThisWeek', Icons.date_range, Colors.orange, fullWidth: true),

                  const SizedBox(height: 24),

                  // Content stats
                  _sectionHeader('📚 Nội dung'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _statCard('Tổng bộ thẻ', '$_totalDecks', Icons.folder_copy, Colors.purple)),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('Tổng thẻ từ', '$_totalCards', Icons.style, Colors.teal)),
                  ]),

                  const SizedBox(height: 24),

                  // Top decks
                  _sectionHeader('🏆 Deck nổi bật nhất'),
                  const SizedBox(height: 12),
                  if (_topDecks.isEmpty)
                    const Center(child: Text('Chưa có deck public nào', style: TextStyle(color: Colors.grey)))
                  else
                    ..._topDecks.asMap().entries.map((e) => _topDeckTile(e.key + 1, e.value)),

                  const SizedBox(height: 24),

                  // Broadcast button
                  _sectionHeader('📢 Thông báo hệ thống'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showBroadcastDialog,
                      icon: const Icon(Icons.campaign),
                      label: const Text('Gửi thông báo đến tất cả người dùng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B8C88),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Thông báo sẽ được gửi đến tất cả người dùng đã đăng ký.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ]),
    );
  }

  Widget _topDeckTile(int rank, Map<String, dynamic> deck) {
    final medals = ['🥇', '🥈', '🥉'];
    String medal = rank <= 3 ? medals[rank - 1] : '$rank.';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        Text(medal, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(deck['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
            Text('${deck['cardCount']} thẻ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
        Row(children: [
          const Icon(Icons.favorite, size: 14, color: Colors.red),
          const SizedBox(width: 4),
          Text('${deck['likes']}', style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 10),
          const Icon(Icons.bookmark, size: 14, color: Colors.orange),
          const SizedBox(width: 4),
          Text('${deck['saves']}', style: const TextStyle(fontSize: 13)),
        ]),
      ]),
    );
  }
}
