import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In + Firebase Auth. Both phones sign in with the SAME Google
/// account — that shared account is what pairs them together.
class AuthService {
  // Web client ID (client_type 3) from google-services.json. google_sign_in v7
  // needs this as the serverClientId so it returns an idToken Firebase can verify.
  static const String _webClientId =
      '570979746641-ofn1rm5v8fafmo2mc12ilnu6pop1feom.apps.googleusercontent.com';

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
    _initialized = true;
  }

  static Stream<User?> authState() => FirebaseAuth.instance.authStateChanges();

  static User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Opens the Google account picker (multiple accounts / add-account supported),
  /// then signs into Firebase with the chosen account.
  static Future<void> signInWithGoogle() async {
    await _ensureInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google did not return an ID token.');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // ignore — still sign out of Firebase below
    }
    await FirebaseAuth.instance.signOut();
  }
}
