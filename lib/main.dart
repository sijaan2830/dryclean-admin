import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'providers/firebase_auth_provider.dart';
import 'providers/firebase_admin_service.dart';
import 'services/fcm_sender_service.dart';
import 'screens/login_screen.dart';
import 'widgets/auth_wrapper.dart';
import 'theme/admin_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AdminPanelApp());
}

class AdminPanelApp extends StatelessWidget {
  const AdminPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FirebaseAuthProvider>(create: (_) => FirebaseAuthProvider()),
        ChangeNotifierProvider<FirebaseAdminService>(create: (_) => FirebaseAdminService()),
        Provider<FCMSenderService>(create: (_) => FCMSenderService()),
      ],
      child: MaterialApp(
        title: 'DryClean Plus · Admin console',
        theme: buildAdminTheme(),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
