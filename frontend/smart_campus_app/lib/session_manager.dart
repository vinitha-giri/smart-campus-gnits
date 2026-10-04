class SessionManager {
  static String email = '';
  static String token = '';
  static void setSession({required String userEmail, required String sessionToken}) { email=userEmail; token=sessionToken; }
  static void clear() { email=''; token=''; }
}
