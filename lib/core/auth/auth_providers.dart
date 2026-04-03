import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of auth state changes (sign-in, sign-out).
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// The current user's UID, or null if not signed in.
final userIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

/// Signs in anonymously if no user is currently authenticated.
/// Call once during app startup, after Firebase.initializeApp().
Future<void> ensureAnonymousAuth() async {
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
}
