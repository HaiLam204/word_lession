import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      DataSnapshot snap = await _dbRef.child('users').get();
      if (snap.exists) {
        Map data = snap.value as Map;
        List<Map<String, dynamic>> users = [];
        data.forEach((key, value) {
          Map u = value as Map;
          users.add({
            'uid': key,
            'displayName': u['displayName'] ?? 'Unknown',
            'email': u['email'] ?? '',
            'xp': u['xp'] ?? 0,
            'streak': u['streak'] ?? 0,
            'createdAt': u['createdAt'] ?? 0,
            'lastStudyDate': u['lastStudyDate'] ?? 0,
            'isAdmin': u['isAdmin'] ?? false,
            'isBanned': u['isBanned'] ?? false,
          });
        });
        users.sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int));
        setState(() {
          _users = users;
          _filtered = users;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filtered = _users.where((u) =>
        u['displayName'].toString().toLowerCase().contains(_searchQuery) ||
        u['email'].toString().toLowerCase().contains(_searchQuery)
      ).toList();
    });
  }

  void _showUserDetail(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _UserDetailSheet(user: user, dbRef: _dbRef, onRefresh: _loadUsers),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('Quản lý người dùng', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF3B8C88)), onPressed: _loadUsers),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _filterUsers,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hoặc email...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('${_filtered.length} người dùng', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) => _buildUserTile(_filtered[i]),
                ),
        ),
      ]),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    bool isBanned = user['isBanned'] == true;
    bool isAdmin = user['isAdmin'] == true;
    String initial = (user['displayName'] as String).isNotEmpty
        ? (user['displayName'] as String)[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _showUserDetail(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isBanned ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isBanned ? Colors.red.shade200 : Colors.transparent),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: isAdmin ? Colors.red : const Color(0xFF3B8C88),
            child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(user['displayName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (isAdmin) ...[const SizedBox(width: 6), const Icon(Icons.admin_panel_settings, size: 14, color: Colors.red)],
              if (isBanned) ...[const SizedBox(width: 6), const Icon(Icons.block, size: 14, color: Colors.red)],
            ]),
            Text(user['email'], style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${user['xp']} XP', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B8C88), fontSize: 13)),
            Text('🔥 ${user['streak']} ngày', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        ]),
      ),
    );
  }
}

class _UserDetailSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final DatabaseReference dbRef;
  final VoidCallback onRefresh;

  const _UserDetailSheet({required this.user, required this.dbRef, required this.onRefresh});

  String _formatDate(int ms) {
    if (ms == 0) return 'Chưa có';
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _toggleBan(BuildContext ctx) async {
    bool isBanned = user['isBanned'] == true;
    bool? confirm = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(isBanned ? 'Mở khóa tài khoản' : 'Khóa tài khoản'),
        content: Text(isBanned
            ? 'Mở khóa tài khoản của ${user['displayName']}?'
            : 'Khóa tài khoản của ${user['displayName']}? User sẽ không thể đăng nhập.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isBanned ? Colors.green : Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: Text(isBanned ? 'Mở khóa' : 'Khóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await dbRef.child('users/${user['uid']}/isBanned').set(!isBanned);
    Navigator.pop(ctx);
    onRefresh();
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(isBanned ? 'Đã mở khóa tài khoản' : 'Đã khóa tài khoản'),
      backgroundColor: isBanned ? Colors.green : Colors.orange,
    ));
  }

  Future<void> _resetXP(BuildContext ctx) async {
    bool? confirm = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Reset XP'),
        content: Text('Reset XP của ${user['displayName']} về 0?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await dbRef.child('users/${user['uid']}/xp').set(0);
    Navigator.pop(ctx);
    onRefresh();
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Đã reset XP'), backgroundColor: Colors.orange));
  }

  Future<void> _resetStreak(BuildContext ctx) async {
    bool? confirm = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Reset Streak'),
        content: Text('Reset streak của ${user['displayName']} về 0?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await dbRef.child('users/${user['uid']}/streak').set(0);
    Navigator.pop(ctx);
    onRefresh();
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Đã reset Streak'), backgroundColor: Colors.orange));
  }

  @override
  Widget build(BuildContext ctx) {
    bool isBanned = user['isBanned'] == true;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Row(children: [
          CircleAvatar(
            radius: 28, backgroundColor: const Color(0xFF3B8C88),
            child: Text((user['displayName'] as String)[0].toUpperCase(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user['displayName'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(user['email'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ])),
        ]),
        const SizedBox(height: 20),
        _infoRow('⚡ XP', '${user['xp']}'),
        _infoRow('🔥 Streak', '${user['streak']} ngày'),
        _infoRow('📅 Học lần cuối', _formatDate(user['lastStudyDate'])),
        _infoRow('🔒 Trạng thái', isBanned ? 'Đã khóa' : 'Hoạt động'),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        const Text('Hành động', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _actionBtn(
            isBanned ? 'Mở khóa' : 'Khóa TK',
            isBanned ? Icons.lock_open : Icons.block,
            isBanned ? Colors.green : Colors.red,
            () => _toggleBan(ctx),
          )),
          const SizedBox(width: 10),
          Expanded(child: _actionBtn('Reset XP', Icons.star_border, Colors.orange, () => _resetXP(ctx))),
          const SizedBox(width: 10),
          Expanded(child: _actionBtn('Reset Streak', Icons.local_fire_department, Colors.deepOrange, () => _resetStreak(ctx))),
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withOpacity(0.3))),
      ),
    );
  }
}
