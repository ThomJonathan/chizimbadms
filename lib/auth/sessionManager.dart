  // lib/auth/sessionManager.dart
  import 'package:shared_preferences/shared_preferences.dart';

  class SessionManager {
    static const String _keyUserId = 'user_id';
    static const String _keyFullName = 'user_fullname';
    static const String _keyPhone = 'user_phone';
    static const String _keyRole = 'user_role';
    static const String _keyIsLoggedIn = 'is_logged_in';

    static SessionManager? _instance;
    static SessionManager get instance => _instance ??= SessionManager._();
    SessionManager._();

    SharedPreferences? _prefs;
    bool _initialized = false;

    // Initialize SharedPreferences
    Future<void> initialize() async {
      if (!_initialized) {
        _prefs = await SharedPreferences.getInstance();
        _initialized = true;
      }
    }

    // Ensure initialization before any operation
    Future<void> _ensureInitialized() async {
      if (!_initialized) {
        await initialize();
      }
    }

    // Save user session
    Future<void> saveUserSession({
      required String userId,
      required String fullName,
      required String phone,
      required String role,
    }) async {
      await _ensureInitialized();
      await _prefs!.setString(_keyUserId, userId);
      await _prefs!.setString(_keyFullName, fullName);
      await _prefs!.setString(_keyPhone, phone);
      await _prefs!.setString(_keyRole, role);
      await _prefs!.setBool(_keyIsLoggedIn, true);
    }

    // Get current user data
    Future<Map<String, dynamic>?> getCurrentUser() async {
      await _ensureInitialized();

      if (!(_prefs!.getBool(_keyIsLoggedIn) ?? false)) {
        return null;
      }

      final userId = _prefs!.getString(_keyUserId);
      final fullName = _prefs!.getString(_keyFullName);
      final phone = _prefs!.getString(_keyPhone);
      final role = _prefs!.getString(_keyRole);

      if (userId == null || fullName == null || phone == null || role == null) {
        return null;
      }

      return {
        'id': userId,
        'fullname': fullName,
        'phone': phone,
        'role': role,
      };
    }

    // Check if user is logged in
    Future<bool> isLoggedIn() async {
      await _ensureInitialized();
      return _prefs!.getBool(_keyIsLoggedIn) ?? false;
    }

    // Get user role
    Future<String?> getUserRole() async {
      await _ensureInitialized();
      return _prefs!.getString(_keyRole);
    }

    // Clear all session data
    Future<void> clearSession() async {
      await _ensureInitialized();
      await _prefs!.remove(_keyUserId);
      await _prefs!.remove(_keyFullName);
      await _prefs!.remove(_keyPhone);
      await _prefs!.remove(_keyRole);
      await _prefs!.setBool(_keyIsLoggedIn, false);
    }

    // Logout user
    Future<void> logout() async {
      await clearSession();
    }
  }