import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../repositories/bus_line_service.dart';
import '../state/home_controller.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return ChangeNotifierProvider<HomeController>(
          create: (_) => HomeController(BusLineService(user.uid)),
          child: const HomeScreen(),
        );
      },
    );
  }
}