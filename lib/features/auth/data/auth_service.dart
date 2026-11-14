
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get the currently logged-in user.
  User? get currentUser => _supabase.auth.currentUser;

  // Listen to authentication changes.
  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // Create a new account.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
      },
    );
  }

  // Log in an existing user.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Send a password reset email.
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email.trim(),
    );
  }

  // Log out.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
