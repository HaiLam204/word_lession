import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '414162632829-otudo5nlg3g91ujaa8e58oiugskmv1up.apps.googleusercontent.com'
        : null,
    scopes: ['email'], // chỉ lấy email, không dùng People API
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;
      if (user == null) return;

      // Check if user already exists in database
      DataSnapshot snapshot = await _dbRef.child('users/${user.uid}').get();
      if (!snapshot.exists) {
        // New user - create profile
        int now = DateTime.now().millisecondsSinceEpoch;
        await _dbRef.child('users/${user.uid}').set({
          'id': user.uid,
          'displayName': user.displayName ?? 'User',
          'email': user.email ?? '',
          'dailyGoal': 20,
          'srsIntensity': 'Cân bằng',
          'streak': 0,
          'lastStudyDate': 0,
          'xp': 0,
          'totalDecks': 0,
          'isAdmin': false,
        });

        // Welcome notification
        await _dbRef.child('notifications/${user.uid}').push().set({
          'title': 'Chào mừng bạn!',
          'message': 'Chúc mừng bạn đã tham gia ứng dụng học từ vựng. Hãy tạo bộ thẻ đầu tiên và bắt đầu học ngay!',
          'type': 'system',
          'timestamp': now,
          'isRead': false,
        });
      }
    } catch (e) {
      print('❌ Lỗi Google Sign-In: $e');
      rethrow;
    }
  }

  Future<void> signUp(String name, String email, String password) async {
    UserCredential cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    String uid = cred.user!.uid;
    int now = DateTime.now().millisecondsSinceEpoch;

    await _dbRef.child("users/$uid").set({
      "id": uid,
      "displayName": name,
      "email": email,
      "dailyGoal": 20,
      "srsIntensity": "Cân bằng",
      "streak": 0,
      "lastStudyDate": 0,
      "xp": 0,
      "totalDecks": 0,
      "isAdmin": false,
    });

    // Thông báo chào mừng
    await _dbRef.child("notifications/$uid").push().set({
      "title": "Chào mừng bạn!",
      "message": "Chúc mừng bạn đã tham gia ứng dụng học từ vựng. Hãy tạo bộ thẻ đầu tiên và bắt đầu học ngay!",
      "type": "system",
      "timestamp": now,
      "isRead": false,
    });

    // Đăng xuất ngay để user phải đăng nhập lại
    await _auth.signOut();
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Google sign out có thể fail nếu user đăng nhập bằng email/password
    }
    await _auth.signOut();
  }
}