import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/attendance_screen.dart';
// 1. Footer wali file import karein
import 'layout/support_footer.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      // Footer ko dark theme ke mutabiq set karne ke liye
      scaffoldBackgroundColor: const Color(0xFF020D1A), 
    ),
    home: token != null ? const AttendanceScreen() : const LoginScreen(),
  ));
}