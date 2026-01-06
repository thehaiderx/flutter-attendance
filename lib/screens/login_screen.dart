import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'attendance_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLoading = false;
  bool isPasswordVisible = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    String input = _emailController.text.trim();
    String password = _passwordController.text;

    if (input.isEmpty || password.isEmpty) {
      _showError("Credentials are required!");
      return;
    }

    setState(() => isLoading = true);
    bool isEmail = input.contains('@');

    Map<String, String> loginData = {
      isEmail ? 'email' : 'phone': input,
      'password': password,
    };

    try {
      final res = await ApiService.post('/login', loginData);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['access_token']);
        await prefs.setString('auth_user', jsonEncode(data['user']));

        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AttendanceScreen()));
      } else {
        _showError("Invalid Email or Password");
      }
    } catch (e) {
      _showError("Server Connection Failed");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          // Background Animation (Atomic Glow)
          Positioned(
            top: -100,
            right: -50,
            child: _buildGlowOrb(Colors.blueAccent.withOpacity(0.15), 300),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildGlowOrb(Colors.purpleAccent.withOpacity(0.1), 250),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    // --- ATOM SOFT SOLUTIONS LOGO AREA ---
                    _buildLogo(),
                    const SizedBox(height: 10),
                    const Text(
                      "ATOM SOFT",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    Text(
                      "S  O  L  U  T  I  O  N  S",
                      style: TextStyle(
                        color: Colors.blueAccent.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 60),

                    // Login Card
                    _buildInputContainer(
                      child: TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("Email or Phone", Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildInputContainer(
                      child: TextField(
                        controller: _passwordController,
                        obscureText: !isPasswordVisible,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("Password", Icons.lock_outline_rounded, isPass: true),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // SIGN IN BUTTON
                    GestureDetector(
                      onTap: isLoading ? null : handleLogin,
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text(
                                  "LOGIN TO PORTAL",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      "v1.0.2 • Powered by Atom Soft",
                      style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return RotationTransition(
      turns: _controller,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 1),
        ),
        child: const Icon(Icons.webhook_rounded, size: 60, color: Colors.blueAccent),
      ),
    );
  }

  Widget _buildGlowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 50)],
      ),
    );
  }

  Widget _buildInputContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool isPass = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.blueAccent.withOpacity(0.6), size: 20),
      suffixIcon: isPass
          ? IconButton(
              icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white24, size: 18),
              onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
            )
          : null,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }
}