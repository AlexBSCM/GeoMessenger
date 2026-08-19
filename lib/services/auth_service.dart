import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Fast login for local dev — any email, any password
  Future<AppUser?> signInWithEmail(String email, String password) async {
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
      return null;
    }
  }

  // Phone auth (works with emulator: any phone + any 6-digit code)
  Future<void> sendPhoneCode(String phoneNumber) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (e) {},
      codeSent: (vid, _) => _verificationId = vid,
      codeAutoRetrievalTimeout: (vid) => _verificationId = vid,
    );
  }

  Future<AppUser?> verifyPhoneCode(String smsCode) async {
    if (_verificationId == null) return null;
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return _createOrGetUser(userCredential.user!);
    } catch (e) {
      return null;
    }
  }

  Future<AppUser> _createOrGetUser(User firebaseUser) async {
    final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
    if (doc.exists) {
      return AppUser.fromMap(doc.data()!);
    }
    final appUser = AppUser(
      id: firebaseUser.uid,
      name: '',
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

  String? _verificationId;
}
