import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminCommunityScreen extends StatefulWidget {
  const AdminCommunityScreen({super.key});

  @override
  State<AdminCommunityScreen> createState() => _AdminCommunityScreenState();
}

class _AdminCommunityScreenState extends State<AdminCommunityScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  late TabController _tabController;

  List<Map<String, dynamic>> _publicDecks = [];
  bool _isLoadingDecks = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPublicDecks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPublicDecks() async {
    setState(() => _isLoadingDecks = true);
    try {
      DataSnapshot snap = await _dbRef.child('decks').get();
      if (snap.exists) {
        Map data = snap.value as Map;
        List<Map<String, dynamic>> decks = [];
        data.forEach((key, value) {
          Map d = value as Map;
          if (d['isPublic'] == true) {
            decks.add({
              'id': key,
              'name': d['name'] ?? 'Untitled',
              'ownerId': d['ownerId'] ?? '',
              'description': d['description'] ?? '',
              'cardCount': d['cardCount'] ?? 0,
              'likes': d['likes'] ?? 0,
              'saves': d['saves'] ?? 0,
              'rating': (d['rating'] ?? 0.0).toDouble(),
              'tags': d['tags'] ?? [],
              'isPinned': d['isPinned'] ?? false,
              'sharedAt': d['sharedAt'] ?? 0,
            });
          }
        });
        decks.sort((a, b) {
          if (a['isPinned'] && !b['isPinned']) return -1;
          if (!a['isPinned'] && b['isPinned']) return 1;
          return (b['sharedAt'] as int).compareTo(a['sharedAt'] as int);
        });
        setState(() => _publicDecks = decks);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isLoadingDecks = false);
  }

  Future<void> _deleteDeck(String deckId, String deckName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa deck vi phạm', style: TextStyle(color: Colors.red)),
        content: Text('Xóa deck "$deckName" khỏi cộng đồng?\nHành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      // Chỉ hủy public, không xóa deck gốc của user
      await _dbRef.child('decks/$deckId').update({'isPublic': false});
      _loadPublicDecks();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gỡ deck khỏi cộng đồng'), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _togglePin(String deckId, bool isPinned) async {
    try {
      await _dbRef.child('decks/$deckId/isPinned').set(!isPinned);
      _loadPublicDecks();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isPinned ? 'Đã bỏ ghim deck' : 'Đã ghim deck lên đầu'),
        backgroundColor: isPinned ? Colors.grey : Colors.green,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
  }

  void _showCommentsDialog(String deckId, String deckName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CommentsSheet(deckId: deckId, deckName: deckName, dbRef: _dbRef),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('Quản lý cộng đồng', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF3B8C88)), onPressed: _loadPublicDecks),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF3B8C88),
          labelColor: const Color(0xFF3B8C88),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Deck công khai'),
            Tab(text: 'Bình luận'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDecksTab(),
          _buildCommentsTab(),
        ],
      ),
    );
  }

  Widget _buildDecksTab() {
    if (_isLoadingDecks) return const Center(child: CircularProgressIndicator());
    if (_publicDecks.isEmpty) return const Center(child: Text('Không có deck công khai nào', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _publicDecks.length,
      itemBuilder: (ctx, i) {
        final deck = _publicDecks[i];
        bool isPinned = deck['isPinned'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isPinned ? Colors.amber.shade300 : Colors.transparent),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (isPinned) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin, size: 16, color: Colors.amber)),
              Expanded(child: Text(deck['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Text('${deck['cardCount']} thẻ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.favorite, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Text('${deck['likes']}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
              const Icon(Icons.bookmark, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              Text('${deck['saves']}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text(deck['rating'].toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
              const Spacer(),
              // Pin button
              IconButton(
                icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: isPinned ? Colors.amber : Colors.grey, size: 20),
                onPressed: () => _togglePin(deck['id'], isPinned),
                tooltip: isPinned ? 'Bỏ ghim' : 'Ghim lên đầu',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              // Comments button
              IconButton(
                icon: const Icon(Icons.comment_outlined, color: Colors.blue, size: 20),
                onPressed: () => _showCommentsDialog(deck['id'], deck['name']),
                tooltip: 'Xem bình luận',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => _deleteDeck(deck['id'], deck['name']),
                tooltip: 'Gỡ khỏi cộng đồng',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildCommentsTab() {
    return StreamBuilder(
      stream: _dbRef.child('deckComments').onValue,
      builder: (ctx, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text('Không có bình luận nào', style: TextStyle(color: Colors.grey)));
        }

        Map allData = snapshot.data!.snapshot.value as Map;
        List<Map<String, dynamic>> allComments = [];

        allData.forEach((deckId, comments) {
          if (comments is Map) {
            comments.forEach((commentId, comment) {
              if (comment is Map) {
                allComments.add({
                  'deckId': deckId,
                  'commentId': commentId,
                  'text': comment['text'] ?? '',
                  'userId': comment['userId'] ?? '',
                  'userName': comment['userName'] ?? 'Unknown',
                  'timestamp': comment['timestamp'] ?? 0,
                });
              }
            });
          }
        });

        allComments.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

        if (allComments.isEmpty) return const Center(child: Text('Không có bình luận nào', style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allComments.length,
          itemBuilder: (ctx, i) {
            final c = allComments[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 18, backgroundColor: const Color(0xFF3B8C88),
                  child: Text((c['userName'] as String).isNotEmpty ? (c['userName'] as String)[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['userName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(c['text'], style: const TextStyle(fontSize: 14)),
                ])),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteComment(c['deckId'], c['commentId']),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteComment(String deckId, String commentId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa bình luận vi phạm', style: TextStyle(color: Colors.red)),
        content: const Text('Xóa bình luận này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _dbRef.child('deckComments/$deckId/$commentId').remove();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bình luận'), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
  }
}

// Bottom sheet xem bình luận của 1 deck cụ thể
class _CommentsSheet extends StatelessWidget {
  final String deckId;
  final String deckName;
  final DatabaseReference dbRef;

  const _CommentsSheet({required this.deckId, required this.deckName, required this.dbRef});

  Future<void> _deleteComment(BuildContext ctx, String commentId) async {
    await dbRef.child('deckComments/$deckId/$commentId').remove();
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Đã xóa bình luận'), backgroundColor: Colors.orange));
  }

  @override
  Widget build(BuildContext ctx) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text('Bình luận: $deckName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder(
            stream: dbRef.child('deckComments/$deckId').onValue,
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data!.snapshot.value == null) {
                return const Center(child: Text('Chưa có bình luận nào', style: TextStyle(color: Colors.grey)));
              }
              Map data = snap.data!.snapshot.value as Map;
              List<MapEntry> comments = data.entries.toList();
              comments.sort((a, b) => ((b.value as Map)['timestamp'] ?? 0).compareTo((a.value as Map)['timestamp'] ?? 0));

              return ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: comments.length,
                itemBuilder: (ctx, i) {
                  Map c = comments[i].value as Map;
                  String commentId = comments[i].key as String;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF3B8C88),
                      child: Text((c['userName'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(c['userName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(c['text'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteComment(ctx, commentId),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
