import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../notifications/notifications_screen.dart';
import '../../services/deck_service.dart';
import '../../services/leaderboard_service.dart';
import 'deck_detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final DeckService _deckService = DeckService();
  final LeaderboardService _leaderboardService = LeaderboardService();
  late TabController _tabController;
  int _selectedTab = 0;
  int _leaderboardType = 0; // 0: XP, 1: Decks, 2: Streak

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExploreTab(),
                  _buildLeaderboardTab(),
                  _buildForumTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tính năng đang phát triển')),
          );
        },
        backgroundColor: const Color(0xFF3E8F8B),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40), // Spacer for alignment
          const Text(
            'Cộng đồng',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF3E8F8B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_outlined, color: Color(0xFF3E8F8B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF3E8F8B),
        indicatorWeight: 3,
        labelColor: const Color(0xFF3E8F8B),
        unselectedLabelColor: const Color(0xFF666666),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: 'Khám phá'),
          Tab(text: 'Bảng xếp hạng'),
          Tab(text: 'Diễn đàn'),
        ],
      ),
    );
  }

  Widget _buildExploreTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _deckService.getPublicDecks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Chưa có bộ từ vựng nào',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hãy là người đầu tiên chia sẻ!',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        List<Map<String, dynamic>> publicDecks = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Bộ từ vựng phổ biến',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Khám phá các bộ thẻ được chia sẻ từ cộng đồng học tập',
              style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 24),
            ...publicDecks.map((deck) => _buildRealDeckCard(deck)),
            const SizedBox(height: 100),
          ],
        );
      },
    );
  }

  Widget _buildRealDeckCard(Map<String, dynamic> deck) {
    String deckId = deck['id'] ?? '';
    String deckName = deck['name'] ?? 'Untitled';
    String description = deck['description'] ?? '';
    int cardCount = deck['cardCount'] ?? 0;
    String ownerId = deck['ownerId'] ?? '';
    bool isMyDeck = ownerId == user?.uid;
    double rating = (deck['rating'] ?? 0.0).toDouble();
    int likes = deck['likes'] ?? 0;
    int saves = deck['saves'] ?? 0;
    List<dynamic> tags = deck['tags'] ?? [];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeckDetailScreen(deck: deck),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3E8F8B).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF3E8F8B).withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Stack(
                children: [
                  if (isMyDeck)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CỦA TÔI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deckName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  
                  // Tags
                  if (tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.take(3).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E8F8B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3E8F8B),
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Stats row
                  Row(
                    children: [
                      const Icon(Icons.library_books, size: 16, color: Color(0xFF666666)),
                      const SizedBox(width: 4),
                      Text(
                        '$cardCount thẻ',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                      ),
                      const SizedBox(width: 8),
                      const Text('|', style: TextStyle(color: Color(0xFF666666))),
                      const SizedBox(width: 8),
                      FutureBuilder<Map<String, dynamic>?>(
                        future: _deckService.getDeckOwnerInfo(ownerId),
                        builder: (context, ownerSnapshot) {
                          String ownerName = ownerSnapshot.data?['displayName'] ?? 'Unknown';
                          return Text(
                            ownerName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3E8F8B),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Rating, likes, saves
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Color(0xFFF0D16B)),
                      const SizedBox(width: 4),
                      Text(
                        rating > 0 ? rating.toStringAsFixed(1) : '0.0',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.favorite, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        likes.toString(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.bookmark, size: 16, color: Color(0xFF3E8F8B)),
                      const SizedBox(width: 4),
                      Text(
                        saves.toString(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  
                  if (!isMyDeck) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _copyDeck(deckId, deckName),
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Lấy về'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3E8F8B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FutureBuilder<bool>(
                          future: _deckService.hasLikedDeck(deckId),
                          builder: (context, snapshot) {
                            bool hasLiked = snapshot.data ?? false;
                            return IconButton(
                              onPressed: () => _toggleLike(deckId),
                              icon: Icon(
                                hasLiked ? Icons.favorite : Icons.favorite_border,
                                color: Colors.red,
                              ),
                            );
                          },
                        ),
                        FutureBuilder<bool>(
                          future: _deckService.hasSavedDeck(deckId),
                          builder: (context, snapshot) {
                            bool hasSaved = snapshot.data ?? false;
                            return IconButton(
                              onPressed: () => _toggleSave(deckId),
                              icon: Icon(
                                hasSaved ? Icons.bookmark : Icons.bookmark_border,
                                color: const Color(0xFF3E8F8B),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyDeck(String deckId, String deckName) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _deckService.copyDeckToLibrary(deckId);

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã lấy "$deckName" về thư viện của bạn!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleLike(String deckId) async {
    try {
      await _deckService.likeDeck(deckId);
      setState(() {}); // Refresh UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleSave(String deckId) async {
    try {
      await _deckService.saveDeck(deckId);
      setState(() {}); // Refresh UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildDeckCard(String title, String cardCount, String author, String tag, Color tagColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3E8F8B).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng đang phát triển')),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: tagColor.withOpacity(0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E8F8B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.library_books, size: 18, color: Color(0xFF666666)),
                        const SizedBox(width: 4),
                        Text(
                          cardCount,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Color(0xFF666666))),
                        const SizedBox(width: 8),
                        Text(
                          author,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3E8F8B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedForum() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF3E8F8B).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3E8F8B).withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Thảo luận nổi bật',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E8F8B),
                ),
              ),
              TextButton(
                onPressed: () {
                  _tabController.animateTo(2);
                },
                child: const Row(
                  children: [
                    Text('Xem tất cả', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFF0D16B),
                      child: const Text('LC', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linh Chi',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '2 giờ trước',
                          style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mọi người ơi, có tips nào nhớ nhanh các phrasal verbs khó nhằn không ạ? Em học mãi mà cứ quên...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite_border, size: 18, color: Color(0xFF666666)),
                        const SizedBox(width: 4),
                        const Text('24', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF666666)),
                        const SizedBox(width: 4),
                        const Text('15', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildLeaderboardTypeButton('🏆 XP', 0),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLeaderboardTypeButton('📚 Bộ thẻ', 1),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLeaderboardTypeButton('🔥 Streak', 2),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getLeaderboardData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có dữ liệu',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              List<Map<String, dynamic>> leaderboard = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: leaderboard.length,
                itemBuilder: (context, index) {
                  return _buildLeaderboardItem(leaderboard[index], index + 1);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTypeButton(String label, int type) {
    bool isSelected = _leaderboardType == type;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _leaderboardType = type;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF3E8F8B) : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getLeaderboardData() {
    switch (_leaderboardType) {
      case 0:
        return _leaderboardService.getTopUsersByXP();
      case 1:
        return _leaderboardService.getTopUsersByDecks();
      case 2:
        return _leaderboardService.getTopUsersByStreak();
      default:
        return Future.value([]);
    }
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> userData, int rank) {
    String userId = userData['id'] ?? '';
    String displayName = userData['displayName'] ?? 'User';
    bool isCurrentUser = userId == user?.uid;
    
    int value = 0;
    String valueLabel = '';
    
    switch (_leaderboardType) {
      case 0:
        value = userData['xp'] ?? 0;
        valueLabel = '$value XP';
        break;
      case 1:
        value = userData['totalDecks'] ?? 0;
        valueLabel = '$value bộ thẻ';
        break;
      case 2:
        value = userData['streak'] ?? 0;
        valueLabel = '$value ngày';
        break;
    }

    Color rankColor = Colors.grey;
    IconData rankIcon = Icons.emoji_events;
    
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = Icons.emoji_events;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser ? const Color(0xFF3E8F8B).withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? const Color(0xFF3E8F8B) : Colors.grey.shade200,
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow: [
          if (rank <= 3)
            BoxShadow(
              color: rankColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rank <= 3 ? rankColor.withOpacity(0.2) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: rank <= 3
                  ? Icon(rankIcon, color: rankColor, size: 24)
                  : Text(
                      '$rank',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF666666),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF3E8F8B),
            child: Text(
              displayName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Name and value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser ? const Color(0xFF3E8F8B) : const Color(0xFF333333),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E8F8B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'BẠN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  valueLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          
          // Medal for top 3
          if (rank <= 3)
            Text(
              rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
              style: const TextStyle(fontSize: 32),
            ),
        ],
      ),
    );
  }

  Widget _buildForumTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Diễn đàn',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tính năng đang phát triển',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
