import 'package:firebase_auth/firebase_auth.dart';

/// Email + password auth. Both phones sign in with the SAME email — that shared
/// account is what pairs them. Different emails are completely isolated from
/// each other (enforced by the Firestore security rules).
class AuthService {
  static Stream<User?> authState() => FirebaseAuth.instance.authStateChanges();

  static User? get currentUser => FirebaseAuth.instance.currentUser;

  static Future<void> signIn(String email, String password) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> register(String email, String password) {
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> signOut() => FirebaseAuth.instance.signOut();
}
