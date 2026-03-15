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
          'totalDecks': 1,
          'isAdmin': false,
        });

        // Welcome notification
        await _dbRef.child('notifications/${user.uid}').push().set({
          'title': 'Chào mừng bạn!',
          'message': 'Chúc mừng bạn đã tham gia ứng dụng học từ vựng. Hãy bắt đầu học ngay!',
          'type': 'system',
          'timestamp': now,
          'isRead': false,
        });

        // Create sample deck
        DatabaseReference newDeckRef = _dbRef.child('decks').push();
        String deckId = newDeckRef.key!;
        await newDeckRef.set({
          'id': deckId,
          'ownerId': user.uid,
          'name': 'Tiếng Anh Giao Tiếp (Mẫu)',
          'description': 'Bộ từ vựng mẫu để bạn làm quen với ứng dụng.',
          'cardCount': 2,
          'isPublic': false,
          'createdAt': now,
        });

        await _dbRef.child('cards').push().set({
          'deckId': deckId,
          'ownerId': user.uid,
          'front': "How's it going?",
          'back': 'Dạo này thế nào? (Cách chào hỏi thân mật)',
          'example': "Hey Mark, long time no see. How's it going?",
          'dueDate': now,
          'interval': 0,
          'easeFactor': 2.5,
          'status': 'new',
        });

        await _dbRef.child('cards').push().set({
          'deckId': deckId,
          'ownerId': user.uid,
          'front': 'I appreciate it',
          'back': 'Tôi rất trân trọng điều đó (Cảm ơn lịch sự)',
          'example': 'Thanks for your help, I really appreciate it.',
          'dueDate': now,
          'interval': 0,
          'easeFactor': 2.5,
          'status': 'new',
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
      "totalDecks": 1,
      "isAdmin": false,
    });

    // Create welcome notifications
    await _dbRef.child("notifications/$uid").push().set({
      "title": "Chào mừng bạn!",
      "message": "Chúc mừng bạn đã tham gia ứng dụng học từ vựng. Hãy bắt đầu học ngay!",
      "type": "system",
      "timestamp": now,
      "isRead": false,
    });

    await _dbRef.child("notifications/$uid").push().set({
      "title": "Đến giờ ôn tập rồi!",
      "message": "Bạn có 2 thẻ mới trong bộ từ vựng mẫu. Hãy bắt đầu học nhé!",
      "type": "study",
      "timestamp": now - 3600000, // 1 hour ago
      "isRead": false,
    });

    DatabaseReference newDeckRef = _dbRef.child("decks").push();
    String deckId = newDeckRef.key!;

    await newDeckRef.set({
      "id": deckId,
      "ownerId": uid,
      "name": "Tiếng Anh Giao Tiếp (Mẫu)",
      "description": "Bộ từ vựng mẫu để bạn làm quen với ứng dụng.",
      "cardCount": 2,
      "isPublic": false,
      "createdAt": now
    });

    await _dbRef.child("cards").push().set({
      "deckId": deckId,
      "front": "How's it going?",
      "back": "Dạo này thế nào? (Cách chào hỏi thân mật)",
      "example": "Hey Mark, long time no see. How's it going?",
      "dueDate": now,
      "interval": 0,
      "easeFactor": 2.5,
      "status": "new"
    });

    await _dbRef.child("cards").push().set({
      "deckId": deckId,
      "front": "I appreciate it",
      "back": "Tôi rất trân trọng điều đó (Cảm ơn lịch sự)",
      "example": "Thanks for your help, I really appreciate it.",
      "dueDate": now,
      "interval": 0,
      "easeFactor": 2.5,
      "status": "new"
    });
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