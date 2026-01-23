import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
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
      "streak": 0,
      "lastStudyDate": 0,
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
    await _auth.signOut();
  }
}