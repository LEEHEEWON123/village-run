// flutter/lib/features/auth/auth_service.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<AuthResponse> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google 로그인 취소됨');

    final googleAuth = await googleUser.authentication;
    if (googleAuth.accessToken == null || googleAuth.idToken == null) {
      throw Exception('Google 인증 토큰 없음');
    }

    return Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
      accessToken: googleAuth.accessToken!,
    );
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await Supabase.instance.client.auth.signOut();
  }

  User? get currentUser => Supabase.instance.client.auth.currentUser;
}
