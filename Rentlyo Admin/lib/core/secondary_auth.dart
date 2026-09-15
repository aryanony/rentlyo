import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'phone_utils.dart';

class SecondaryAuthService {
  /// Create or update a renter Auth account using a temporary secondary FirebaseApp instance
  /// so the currently logged-in Owner session remains completely untouched.
  static Future<UserCredential> createOrUpdateRenterAccount({
    required String phone,
    required String password,
    String? oldPassword,
  }) async {
    final defaultApp = Firebase.app();
    final options = defaultApp.options;

    final appName = 'secondary_auth_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? tempApp;

    try {
      tempApp = await Firebase.initializeApp(
        name: appName,
        options: options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final pseudoEmail = PhoneUtils.toPseudoEmail(phone);

      UserCredential credential;
      try {
        credential = await tempAuth.createUserWithEmailAndPassword(
          email: pseudoEmail,
          password: password,
        );
        await tempAuth.signOut();
        return credential;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Account exists in Auth. Authenticate via old/candidate passwords and update to requested password.
          final candidatePasswords = <String>[];
          if (password.isNotEmpty) candidatePasswords.add(password);
          if (oldPassword != null && oldPassword.isNotEmpty && !candidatePasswords.contains(oldPassword)) {
            candidatePasswords.add(oldPassword);
          }
          if (!candidatePasswords.contains('123456')) candidatePasswords.add('123456');

          UserCredential? loggedInCred;
          for (var candidate in candidatePasswords) {
            try {
              loggedInCred = await tempAuth.signInWithEmailAndPassword(
                email: pseudoEmail,
                password: candidate,
              );
              break;
            } catch (_) {
              // Try next candidate
            }
          }

          if (loggedInCred != null && tempAuth.currentUser != null) {
            await tempAuth.currentUser!.updatePassword(password);
            await tempAuth.signOut();
            return loggedInCred;
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }
    } finally {
      if (tempApp != null) {
        await tempApp.delete();
      }
    }
  }

  /// Backward-compatible wrapper
  static Future<UserCredential> createRenterAccount({
    required String phone,
    required String password,
    String? oldPassword,
  }) =>
      createOrUpdateRenterAccount(phone: phone, password: password, oldPassword: oldPassword);
}
