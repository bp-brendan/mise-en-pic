import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

/// Real-time stream of the user's available credit count from Firestore.
final userCreditsProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) {
    if (!snap.exists) return 0;
    return (snap.data()?['available_credits'] as num?)?.toInt() ?? 0;
  });
});

/// Whether the user currently has at least one credit.
final hasCreditsProvider = Provider<bool>((ref) {
  return (ref.watch(userCreditsProvider).valueOrNull ?? 0) > 0;
});
