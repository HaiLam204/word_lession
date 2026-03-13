import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/deck_service.dart';
import '../../services/comment_service.dart';
import '../../models/comment_model.dart';

class DeckDetailScreen extends StatefulWidget {
  final Map<String, dynamic> deck;

  const DeckDetailScreen({super.key, required this.deck});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DeckService _deckService = DeckService();
  final CommentService _commentService = CommentService();
  final TextEditingController _commentController = TextEditingController();
  double _userRating = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('vi', timeago.ViMessages());
    _loadUserRating();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRating() async {
    double? rating = await _deckService.getUserRating(widget.deck['id']);
    if (rating != null && mounted) {
      setState(() {
        _userRating = rating;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String deckId = widget.deck['id'] ?? '';
    String deckName = widget.deck['name'] ?? 'Untitled';
    String description = widget.deck['description'] ?? '';
    int cardCount = widget.deck['cardCount'] ?? 0;
    String ownerId = widget.deck['ownerId'] ?? '';
    bool isMyDeck = ownerId == user?.uid;
    double rating = (widget.deck['rating'] ?? 0.0).toDouble();
    int ratingCount = widget.deck['ratingCount'] ?? 0;
    int likes = widget.deck['likes'] ?? 0;
    int saves = widget.deck['saves'] ?? 0;
    List<dynamic> tags = widget.deck['tags'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Chi tiết bộ thẻ'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDeckHeader(deckName, description, cardCount, ownerId, tags),
                  _buildStats(rating, ratingCount, likes, saves),
                  if (!isMyDeck) _buildRatingSection(deckId),
                  _buildCommentsSection(deckId),
                ],
              ),
            ),
          ),
          _buildCommentInput(deckId),
        ],
      ),
    );
  }

  Widget _buildDeckHeader(String name, String description, int cardCount, String ownerId, List tags) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: const TextStyle(fontSize: 15, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              const Icon(Icons.library_books, size: 18, color: Color(0xFF666666)),
              const SizedBox(width: 6),
              Text('$cardCount thẻ', style: const TextStyle(color: Color(0xFF666666))),
              const SizedBox(width: 12),
              const Text('|', style: TextStyle(color: Color(0xFF666666))),
              const SizedBox(width: 12),
              FutureBuilder<Map<String, dynamic>?>(
                future: _deckService.getDeckOwnerInfo(ownerId),
                builder: (context, snapshot) {
                  String ownerName = snapshot.data?['displayName'] ?? 'Unknown';
                  return Text(
                    ownerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3E8F8B),
                    ),
                  );
                },
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF3E8F8B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3E8F8B),
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(double rating, int ratingCount, int likes, int saves) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.star, rating > 0 ? rating.toStringAsFixed(1) : '0.0', '$ratingCount đánh giá', const Color(0xFFF0D16B)),
          _buildStatItem(Icons.favorite, likes.toString(), 'lượt thích', Colors.red),
          _buildStatItem(Icons.bookmark, saves.toString(), 'lưu', const Color(0xFF3E8F8B)),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
        ),
      ],
    );
  }

  Widget _buildRatingSection(String deckId) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đánh giá của bạn',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () async {
                  double newRating = (index + 1).toDouble();
                  setState(() {
                    _userRating = newRating;
                  });
                  try {
                    await _deckService.rateDeck(deckId, newRating);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã đánh giá!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: Icon(
                  index < _userRating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFF0D16B),
                  size: 32,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(String deckId) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bình luận',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<DeckComment>>(
            stream: _commentService.getComments(deckId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'Chưa có bình luận nào',
                      style: TextStyle(color: Color(0xFF999999)),
                    ),
                  ),
                );
              }

              return Column(
                children: snapshot.data!.map((comment) => _buildCommentItem(deckId, comment)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(String deckId, DeckComment comment) {
    bool isMyComment = comment.userId == user?.uid;
    String timeAgo = timeago.format(
      DateTime.fromMillisecondsSinceEpoch(comment.timestamp),
      locale: 'vi',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF3E8F8B),
                child: Text(
                  comment.userName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (comment.rating != null) ...[
                          const SizedBox(width: 8),
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < comment.rating! ? Icons.star : Icons.star_border,
                                color: const Color(0xFFF0D16B),
                                size: 14,
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      timeAgo,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                    ),
                  ],
                ),
              ),
              if (isMyComment)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _deleteComment(deckId, comment.id),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.content,
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FutureBuilder<bool>(
                future: _commentService.hasLikedComment(comment.id),
                builder: (context, snapshot) {
                  bool hasLiked = snapshot.data ?? false;
                  return TextButton.icon(
                    onPressed: () => _toggleCommentLike(deckId, comment.id),
                    icon: Icon(
                      hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      size: 16,
                      color: hasLiked ? const Color(0xFF3E8F8B) : const Color(0xFF666666),
                    ),
                    label: Text(
                      comment.likes.toString(),
                      style: TextStyle(
                        color: hasLiked ? const Color(0xFF3E8F8B) : const Color(0xFF666666),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(String deckId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Viết bình luận...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSubmitting ? null : () => _submitComment(deckId),
            icon: const Icon(Icons.send, color: Color(0xFF3E8F8B)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitComment(String deckId) async {
    String content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _commentService.addComment(deckId, content, rating: _userRating > 0 ? _userRating : null);
      _commentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm bình luận!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _toggleCommentLike(String deckId, String commentId) async {
    try {
      await _commentService.likeComment(deckId, commentId);
      setState(() {}); // Refresh UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteComment(String deckId, String commentId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bình luận'),
        content: const Text('Bạn có chắc muốn xóa bình luận này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _commentService.deleteComment(deckId, commentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa bình luận!')),
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
  }
}
