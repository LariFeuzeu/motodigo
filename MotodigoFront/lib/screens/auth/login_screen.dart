// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../../utils/app_colors.dart';
// import '../../providers/auth_provider.dart';
// import '../otp_verify_screen.dart';
//
// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _phoneController = TextEditingController();
//   bool _isLoading = false;
//
//   /// Gère l'envoi de l'OTP via Firebase
//   Future<void> _handleSendOtp() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() => _isLoading = true);
//
//     try {
//       final authProvider = Provider.of<AuthProvider>(context, listen: false);
//
//       // Appel à Firebase Auth via le provider
//       await authProvider.sendOtp(
//         _phoneController.text.trim(),
//             (verificationId) {
//           // Si le SMS est envoyé avec succès, on navigue vers l'écran de saisie du code
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) => OtpVerifyScreen(
//                 phoneNumber: _phoneController.text.trim(),
//               ),
//             ),
//           );
//         },
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Erreur : ${e.toString().replaceFirst('Exception: ', '')}"),
//           backgroundColor: Colors.redAccent,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Style de la barre système pour un look Premium
//     return AnnotatedRegion<SystemUiOverlayStyle>(
//       value: const SystemUiOverlayStyle(
//         systemNavigationBarColor: Colors.white,
//         systemNavigationBarIconBrightness: Brightness.dark,
//         statusBarColor: Colors.transparent,
//         statusBarIconBrightness: Brightness.dark,
//       ),
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         body: SafeArea(
//           child: Center(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(horizontal: 30),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     _buildLogo(),
//                     const SizedBox(height: 40),
//                     const Text(
//                       "Bienvenue sur MotoDigo",
//                       style: TextStyle(
//                         fontSize: 26,
//                         fontWeight: FontWeight.bold,
//                         color: AppColors.primaryDark,
//                         letterSpacing: -0.5,
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     Text(
//                       "Entrez votre numéro pour continuer",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
//                     ),
//                     const SizedBox(height: 40),
//
//                     // Champ Téléphone Style Premium
//                     TextFormField(
//                       controller: _phoneController,
//                       keyboardType: TextInputType.phone,
//                       style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
//                       decoration: InputDecoration(
//                         labelText: "Numéro de téléphone",
//                         hintText: "+237 6XX XXX XXX",
//                         prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.accentBlue),
//                         filled: true,
//                         fillColor: Colors.grey.shade50,
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(16),
//                           borderSide: BorderSide(color: Colors.grey.shade100),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(16),
//                           borderSide: const BorderSide(color: AppColors.accentBlue, width: 1.5),
//                         ),
//                       ),
//                       validator: (v) => (v == null || v.isEmpty) ? "Numéro requis" : null,
//                     ),
//
//                     const SizedBox(height: 30),
//
//                     // Bouton Principal
//                     SizedBox(
//                       width: double.infinity,
//                       height: 58,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: AppColors.primaryDark,
//                           foregroundColor: Colors.white,
//                           elevation: 0,
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                         ),
//                         onPressed: _isLoading ? null : _handleSendOtp,
//                         child: _isLoading
//                             ? const SizedBox(
//                           height: 24,
//                           width: 24,
//                           child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
//                         )
//                             : const Text("Recevoir le code",
//                             style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                       ),
//                     ),
//
//                     const SizedBox(height: 30),
//                     _buildDivider(),
//                     const SizedBox(height: 30),
//
//                     // Google Login (Optionnel/Design)
//                     _buildSocialButton(
//                       label: "Continuer avec Google",
//                       iconPath: "assets/images/g.png",
//                       onPressed: () {
//                         // Logique Google si besoin
//                       },
//                     ),
//
//                     const SizedBox(height: 40),
//                     Text(
//                       "En continuant, vous acceptez nos Conditions d'utilisation",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLogo() {
//     return Container(
//       height: 100,
//       width: 100,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(22),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.06),
//             blurRadius: 20,
//             offset: const Offset(0, 10),
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(22),
//         child: Image.asset("assets/images/motodigo.jpg", fit: BoxFit.cover),
//       ),
//     );
//   }
//
//   Widget _buildDivider() {
//     return Row(
//       children: [
//         Expanded(child: Divider(color: Colors.grey.shade200)),
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 15),
//           child: Text("OU", style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold)),
//         ),
//         Expanded(child: Divider(color: Colors.grey.shade200)),
//       ],
//     );
//   }
//
//   Widget _buildSocialButton({required String label, required String iconPath, required VoidCallback onPressed}) {
//     return SizedBox(
//       width: double.infinity,
//       height: 56,
//       child: OutlinedButton.icon(
//         style: OutlinedButton.styleFrom(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           side: BorderSide(color: Colors.grey.shade200),
//         ),
//         onPressed: onPressed,
//         icon: Image.asset(iconPath, height: 22),
//         label: Text(
//           label,
//           style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
//         ),
//       ),
//     );
//   }
// }