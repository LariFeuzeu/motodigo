import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import 'auth/register_screen.dart'; // Assure-toi du chemin
import '../providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

class OtpVerifyScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpVerifyScreen({super.key, required this.phoneNumber, required this.verificationId});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  bool _isVerifying = false;

  final defaultPinTheme = PinTheme(
    width: 56,
    height: 60,
    textStyle: const TextStyle(fontSize: 22, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.transparent),
    ),
  );

  Future<void> _verifyCode(String code) async {
    setState(() => _isVerifying = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Échange du code contre connexion
      await authProvider.verifyOtpAndLogin(code, explicitVerificationId: widget.verificationId);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      setState(() => _isVerifying = false);

      // --- LOGIQUE SAAS : REDIRECTION SI NOUVEAU COMPTE ---
      if (e.toString().contains("404") || e.toString().contains("USER_NOT_FOUND")) {
        // On récupère le "diplôme" Firebase pour prouver l'identité au Backend
        final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

        if (!mounted) return;

        // On passe directement le token au constructeur pour éviter les erreurs de route
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterScreen(idToken: idToken ?? ""),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Code incorrect ou expiré"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: Colors.white,
        border: Border.all(color: AppColors.accentBlue, width: 2),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(elevation: 0, backgroundColor: Colors.white, leading: const BackButton(color: Colors.black)),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text("Vérification", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text("Entrez le code envoyé au ${widget.phoneNumber}",
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 40),
                Pinput(
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  onCompleted: (pin) => _verifyCode(pin),
                  hapticFeedbackType: HapticFeedbackType.lightImpact,
                  cursor: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(margin: const EdgeInsets.only(bottom: 9), width: 22, height: 1, color: AppColors.accentBlue),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                if (_isVerifying)
                  const CircularProgressIndicator(color: AppColors.accentBlue)
                else
                  TextButton(
                    onPressed: () {},
                    child: const Text("Je n'ai pas reçu de code", style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold)),
                  ),
                const Spacer(),
                const Text("Sécurisé par Firebase Auth", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}