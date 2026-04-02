import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'signin_screen.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref("users");

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isOtpSent = false;
  String _generatedOtp = "";

  // 🔹 Function to generate a 6-digit OTP
  String _generateOtp() {
    Random random = Random();
    int otp = random.nextInt(900000) + 100000;
    return otp.toString();
  }

  // 🔹 Send OTP via email using Gmail SMTP
  Future<void> _sendOtpEmail(String email, String otp) async {
    String username = 'haridatapro7@gmail.com'; // Replace with your email
    String password = 'jpwn ssrd mswy yhjp'; // Replace with your app password

    final smtpServer = gmail(username, password);
    final message = Message()
      ..from = Address(username, 'WalletGuard')
      ..recipients.add(email)
      ..subject = 'Your OTP for WalletGuard'
      ..text = 'Your OTP is: $otp. Please enter it to verify your account.';

    try {
      await send(message, smtpServer);
      print('OTP sent to $email');
    } catch (e) {
      print('Failed to send OTP: $e');
    }
  }

  // 🔹 Function to initiate OTP sending process
  void _sendOtp() async {
    _generatedOtp = _generateOtp();
    await _sendOtpEmail(_emailController.text.trim(), _generatedOtp);

    setState(() {
      _isOtpSent = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("OTP sent to your email. Please check your inbox.")),
    );
  }

  // 🔹 Function to verify OTP and create user in Firebase only after OTP verification
  void _verifyOtpAndSignUp() async {
    if (_otpController.text.trim() == _generatedOtp) {
      setState(() => _isLoading = true);

      try {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        User? user = userCredential.user;
        if (user != null) {
          await _databaseRef.child(user.uid).set({
            "name": _nameController.text.trim(),
            "phone": _phoneController.text.trim(),
            "email": _emailController.text.trim(),
          });

          user.sendEmailVerification();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("OTP verified successfully! Account created.")),
          );

          Future.delayed(Duration(seconds: 2), () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SignInScreen()),
            );
          });
        }
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "An error occurred")),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid OTP. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'WalletGuard',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, spreadRadius: 5)],
                  ),
                  child: Column(
                    children: [
                      buildTextField(controller: _nameController, label: "Name", icon: Icons.person),
                      buildTextField(controller: _phoneController, label: "Phone", icon: Icons.phone, keyboardType: TextInputType.phone),
                      buildTextField(controller: _emailController, label: "Email", icon: Icons.email, keyboardType: TextInputType.emailAddress),
                      buildTextField(controller: _passwordController, label: "Password", icon: Icons.lock, isPassword: true),
                      const SizedBox(height: 20),
                      if (!_isOtpSent)
                        ElevatedButton(
                          onPressed: _sendOtp,
                          child: const Text('Send OTP'),
                        ),
                      if (_isOtpSent) ...[
                        buildTextField(controller: _otpController, label: "Enter OTP", icon: Icons.lock, keyboardType: TextInputType.number),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtpAndSignUp,
                          child: _isLoading ? CircularProgressIndicator(color: Colors.white) : const Text('Verify OTP & Sign Up'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          hintText: label,
          filled: true,
          fillColor: Colors.deepPurple.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
