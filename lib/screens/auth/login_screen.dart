import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  
  bool _codeSent = false;
  bool _loading = false;
  
  // Web specific confirmation holder
  ConfirmationResult? _webConfirmationResult;
  
  // Native specific verification ID holder
  String? _nativeVerificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty || rawPhone.length < 10) {
      _showError('Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() => _loading = true);

    // Format with Indian country code (+91)
    final formattedPhone = '+91$rawPhone';

    try {
      if (kIsWeb) {
        // Firebase Web Phone sign-in with compact reCAPTCHA
        final auth = FirebaseAuth.instance;
        final verifier = RecaptchaVerifier(
          auth: FirebaseAuthPlatform.instance,
          container: 'recaptcha-container',
          size: RecaptchaVerifierSize.compact,
        );
        final confirmationResult = await auth.signInWithPhoneNumber(
          formattedPhone,
          verifier,
        );
        setState(() {
          _webConfirmationResult = confirmationResult;
          _codeSent = true;
          _loading = false;
        });
      } else {
        // Firebase Native Android/iOS Phone sign-in
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: formattedPhone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) setState(() => _loading = false);
          },
          verificationFailed: (FirebaseAuthException e) {
            _showError(e.message ?? 'Verification failed');
            setState(() => _loading = false);
          },
          codeSent: (String verificationId, int? resendToken) {
            setState(() {
              _nativeVerificationId = verificationId;
              _codeSent = true;
              _loading = false;
            });
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            setState(() {
              _nativeVerificationId = verificationId;
            });
          },
        );
      }
    } catch (e) {
      _showError('Error sending OTP: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length < 6) {
      _showError('Please enter the 6-digit verification code');
      return;
    }

    setState(() => _loading = true);

    try {
      if (kIsWeb) {
        if (_webConfirmationResult != null) {
          await _webConfirmationResult!.confirm(code);
        } else {
          _showError('Something went wrong, please send OTP again');
          setState(() => _loading = false);
        }
      } else {
        if (_nativeVerificationId != null) {
          final credential = PhoneAuthProvider.credential(
            verificationId: _nativeVerificationId!,
            smsCode: code,
          );
          await FirebaseAuth.instance.signInWithCredential(credential);
        } else {
          _showError('Session expired, please resend OTP');
          setState(() => _loading = false);
        }
      }
      
      // Routing is handled automatically by authStateChanges() inside main.dart
    } catch (e) {
      _showError('Invalid code. Please try again.');
      setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo/Icon
              Icon(
                Icons.account_balance_wallet,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              
              // App Title
              Text(
                'PapaDesk',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              
              const Text(
                'Smart Business Manager',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),

              if (!_codeSent) ...[
                // Phone input step
                const Text(
                  'Enter Mobile Number',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixText: '+91 ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                  style: const TextStyle(fontSize: 20),
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _loading ? null : _sendOtp,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Send OTP',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                
                const SizedBox(height: 32),
                Text(
                  'Dev Note: You can use +91 99999 99999 with code 123456 to test on web emulator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ] else ...[
                // OTP Code Verification Step
                const Text(
                  'Enter 6-Digit OTP',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sent to +91 ${_phoneController.text}',
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'OTP Code',
                    hintText: '123456',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  maxLength: 6,
                ),
                const SizedBox(height: 16),
                
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _loading ? null : _verifyOtp,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Verify & Login',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _codeSent = false;
                            _codeController.clear();
                          }),
                  child: const Text(
                    'Change Phone Number',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
