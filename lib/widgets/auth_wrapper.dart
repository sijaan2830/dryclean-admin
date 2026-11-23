import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/firebase_auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/admin_navigation_wrapper.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAuthProvider>(
      builder: (context, authProvider, _) {
        // If we're still checking auth status (initial app load)
        // or performing a login/logout action, we might show a loading indicator
        // or just stay on the current screen.
        
        if (authProvider.isAuthenticated) {
          return const AdminNavigationWrapper();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
