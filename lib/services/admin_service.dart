import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminService {
  static final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Check if current user is admin
  static Future<bool> isAdmin() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      DataSnapshot snapshot = await _dbRef.child('users/${user.uid}/isAdmin').get();
      if (snapshot.exists) {
        return snapshot.value == true;
      }
    } catch (e) {
      print('Lỗi kiểm tra admin: $e');
    }
    return false;
  }

  // Set user as admin (only callable by existing admin or first setup)
  static Future<void> setAdmin(String userId, bool isAdmin) async {
    try {
      await _dbRef.child('users/$userId/isAdmin').set(isAdmin);
      print('✅ Đã ${isAdmin ? "cấp" : "thu hồi"} quyền admin cho $userId');
    } catch (e) {
      print('❌ Lỗi set admin: $e');
      rethrow;
    }
  }

  // Get current user UID (for first-time admin setup)
  static String? getCurrentUID() {
    return FirebaseAuth.instance.currentUser?.uid;
  }
}
