import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final DatabaseReference dbRef =  FirebaseDatabase.instance.ref();

  Stream<User?> get authStateChanges => auth.authStateChanges();

  Future<void> signIn(String email, String password) async{
    await auth.signInWithEmailAndPassword(email: email, password: password);
  }
  Future<void> signUp(String name, String email, String password) async{
    UserCredential cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
    String uid = cred.user!.uid;
    await dbRef.child("users/$uid").set({
      "id": uid,
      "displayName": name,
      "email": email,
      "dailyGoal": 0,
      "streak": 0,
      "lastStudyDate": 0,
    });
  }
  Future<void> signOut() async{
    await auth.signOut();
  }
}