import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../models/app_models.dart';
import '../statistics/statistics_screen.dart';
import '../test/test_notification_screen.dart';
import '../test/test_xp_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  AppUser? _currentUser;
  int _dailyGoal = 20;
  String _srsIntensity = 'Cân bằng';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      DataSnapshot snapshot = await _dbRef.child('users/${firebaseUser.uid}').get();
      if (snapshot.exists && mounted) {
        Map userData = snapshot.value as Map;
        setState(() {
          _currentUser = AppUser.fromMap(userData);
          _dailyGoal = _currentUser?.dailyGoal ?? 20;
          _srsIntensity = userData['srsIntensity'] ?? 'Cân bằng';
        });
      }
      
      // Check admin status
      bool adminStatus = await AdminService.isAdmin();
      if (mounted) {
        setState(() {
          _isAdmin = adminStatus;
        });
      }
    }
  }

  Future<void> _updateDailyGoal(int newGoal) async {
    User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      await _dbRef.child('users/${firebaseUser.uid}').update({
        'dailyGoal': newGoal,
      });
      if (mounted) {
        setState(() {
          _dailyGoal = newGoal;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật mục tiêu hàng ngày')),
        );
      }
    }
  }

  Future<void> _updateSRSIntensity(String intensity) async {
    User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      await _dbRef.child('users/${firebaseUser.uid}').update({
        'srsIntensity': intensity,
      });
      if (mounted) {
        setState(() {
          _srsIntensity = intensity;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật cường độ SRS')),
        );
      }
    }
  }

  Future<void> _showDailyGoalDialog() async {
    int tempGoal = _dailyGoal;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mục tiêu hàng ngày'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$tempGoal từ mỗi ngày', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Slider(
                value: tempGoal.toDouble(),
                min: 5,
                max: 100,
                divisions: 19,
                label: '$tempGoal từ',
                onChanged: (value) {
                  setDialogState(() {
                    tempGoal = value.toInt();
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateDailyGoal(tempGoal);
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSRSIntensityDialog() async {
    String? selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cường độ SRS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSRSOption('Dễ', 'Ôn tập ít hơn, khoảng cách dài hơn'),
            _buildSRSOption('Cân bằng', 'Phù hợp với hầu hết người học'),
            _buildSRSOption('Khó', 'Ôn tập nhiều hơn, khoảng cách ngắn hơn'),
          ],
        ),
      ),
    );
    if (selected != null) {
      await _updateSRSIntensity(selected);
    }
  }

  Widget _buildSRSOption(String title, String subtitle) {
    return RadioListTile<String>(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: title,
      groupValue: _srsIntensity,
      onChanged: (value) {
        Navigator.pop(context, value);
      },
    );
  }

  Future<void> _showEditProfileDialog() async {
    final TextEditingController nameController = TextEditingController(
      text: _currentUser?.displayName ?? '',
    );

    try {
      bool? result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chỉnh sửa hồ sơ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.email, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentUser?.email ?? '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Email không thể thay đổi',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                String newName = nameController.text.trim();
                if (newName.isEmpty) {
                  Navigator.pop(context, false);
                  return;
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27CEAF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Lưu'),
            ),
          ],
        ),
      );

      if (result == true) {
        String newName = nameController.text.trim();
        if (newName.isNotEmpty) {
          User? firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser != null) {
            await _dbRef.child('users/${firebaseUser.uid}').update({
              'displayName': newName,
            });
            
            if (mounted) {
              setState(() {
                _currentUser = AppUser(
                  id: _currentUser!.id,
                  displayName: newName,
                  email: _currentUser!.email,
                  streak: _currentUser!.streak,
                  dailyGoal: _currentUser!.dailyGoal,
                );
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã cập nhật hồ sơ')),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tên không được để trống')),
            );
          }
        }
      }
    } finally {
      // Dispose sau khi dialog đã đóng hoàn toàn
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
      });
    }
  }

  Future<void> _showAboutDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Về ứng dụng'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ứng dụng học từ vựng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            Text('Phiên bản: 2.4.1 (Ổn định)'),
            SizedBox(height: 16),
            Text('Ứng dụng giúp bạn học từ vựng hiệu quả với thuật toán SRS (Spaced Repetition System).'),
          ],
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

  Future<void> _handleLogout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Cài đặt',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Profile Info Card
                  Container(
                    padding: const EdgeInsets.all(20),
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
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFF27CEAF),
                          child: Text(
                            _currentUser?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentUser?.displayName ?? 'User',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentUser?.email ?? '',
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _showEditProfileDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27CEAF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text('Chỉnh sửa', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Study Settings
                  _buildSectionHeader('TÙY CHỈNH HỌC TẬP'),
                  _buildSettingsCard([
                    _buildSettingItem(
                      icon: Icons.track_changes,
                      iconColor: const Color(0xFF27CEAF),
                      title: 'Mục tiêu hàng ngày',
                      subtitle: 'Số lượng từ vựng mục tiêu',
                      trailing: '$_dailyGoal từ',
                      onTap: _showDailyGoalDialog,
                    ),
                    const Divider(height: 1),
                    _buildSettingItem(
                      icon: Icons.history_edu,
                      iconColor: Colors.grey,
                      title: 'Cường độ SRS',
                      subtitle: 'Thuật toán lặp lại ngắt quãng',
                      trailing: _srsIntensity,
                      onTap: _showSRSIntensityDialog,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Statistics
                  _buildSectionHeader('TIẾN ĐỘ'),
                  _buildSettingsCard([
                    _buildSimpleItem(
                      icon: Icons.bar_chart,
                      title: 'Thống kê học tập',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const StatisticsScreen()),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Developer Tools - Admin only
                  if (_isAdmin) ...[
                    _buildSectionHeader('CÔNG CỤ PHÁT TRIỂN'),
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Chỉ dành cho Admin',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildSettingsCard([
                      _buildSimpleItem(
                        icon: Icons.bug_report,
                        title: 'Test Thông báo',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TestNotificationScreen()),
                          );
                        },
                      ),
                      _buildSimpleItem(
                        icon: Icons.emoji_events,
                        title: 'Test XP & Leaderboard',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TestXPScreen()),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],

                  // Notifications - removed (UI only)

                  // Appearance - removed (UI only)

                  // Support
                  _buildSectionHeader('HỖ TRỢ'),
                  _buildSettingsCard([
                    _buildSimpleItem(
                      icon: Icons.info_outline,
                      title: 'Về ứng dụng học từ vựng',
                      onTap: _showAboutDialog,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Logout Button
                  ElevatedButton(
                    onPressed: _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
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
      child: Column(children: children),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text(trailing, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF27CEAF),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
