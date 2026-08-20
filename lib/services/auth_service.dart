import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Login/password auth. Firebase Auth requires an email, so a synthetic
  // email is derived from the login: "mylogin@geomesenger.local".
  static const Set<String> allowedLogins = {'poco', '14ultra'};

  static bool isAllowed(String login) {
    final cleaned =
        login.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '');
    return allowedLogins.contains(cleaned);
  }

  Future<AppUser> signInWithLogin(String login, String password) async {
    if (!isAllowed(login)) {
      throw FirebaseAuthException(
        code: 'account-not-allowed',
        message: 'This login is not allowed yet',
      );
    }
    final email = normalizeLogin(login);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _createOrGetUser(cred.user!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        final cred = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return _createOrGetUser(cred.user!);
      }
      rethrow;
    }
  }

  static String normalizeLogin(String login) {
    final cleaned =
        login.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '');
    return '${cleaned.isEmpty ? 'user' : cleaned}@geomesenger.local';
  }

  Future<AppUser> _createOrGetUser(User firebaseUser) async {
    final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
    if (doc.exists) {
      final existing = AppUser.fromMap(doc.data()!);
      if (existing.name.isEmpty) {
        final displayName = firebaseUser.displayName ??
            firebaseUser.email?.split('@').first ??
            firebaseUser.phoneNumber ??
            'User';
        await _firestore.collection('users').doc(firebaseUser.uid).update({'name': displayName});
        return AppUser(
          id: existing.id,
          name: displayName,
          phone: existing.phone,
          pushToken: existing.pushToken,
        );
      }
      return existing;
    }
    final displayName = firebaseUser.displayName ??
        firebaseUser.email?.split('@').first ??
        firebaseUser.phoneNumber ??
        'User';
    final appUser = AppUser(
      id: firebaseUser.uid,
      name: displayName,
      phone: firebaseUser.phoneNumber ?? firebaseUser.email ?? '',
    );
    await _firestore.collection('users').doc(appUser.id).set(appUser.toMap());
    return appUser;
  }

  Future<void> updateProfile(String name) async {
    if (_auth.currentUser == null) return;
    await _firestore.collection('users').doc(_auth.currentUser!.uid).update({'name': name});
  }

  Future<void> savePushToken(String token) async {
    if (_auth.currentUser == null) return;
    await _firestore.collection('users').doc(_auth.currentUser!.uid).update({'pushToken': token});
  }

  Future<void> signOut() async => await _auth.signOut();
}