import 'package:flutter/material.dart';

class AppColors {
  // --- COULEURS PRINCIPALES (BRANDING) ---

  // Le Noir/Bleu très sombre pour les textes et boutons principaux (Uber Style)
  static const Color primaryDark = Color(0xFF09091A);

  // Le Bleu Électrique pour les actions, les liens et les icônes de départ
  static const Color accentBlue = Color(0xFF2D60FF);

  // Le fond de l'application (légèrement cassé pour ne pas fatiguer les yeux)
  static const Color lightBackground = Color(0xFFF8FAFD);

  // --- COULEURS D'ÉTAT ---

  // Pour les succès, les badges "Chauffeur Vérifié" ou "Payé"
  static const Color successGreen = Color(0xFF00C853);

  // Pour les erreurs, les alertes de suppression ou les destinations
  static const Color errorRed = Color(0xFFFF4B4B);

  // Pour les avertissements ou les paiements en attente
  static const Color warningOrange = Color(0xFFFF9100);

  // --- COULEURS DE TEXTE & SURFACES ---

  static const Color textMain = Color(0xFF09091A);
  static const Color textGrey = Color(0xFF8E8E93);
  static const Color surfaceWhite = Colors.white;

  // --- GRADIENTS PRÉFINIS (Pour tes bannières et boutons Premium) ---

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2D60FF), // Accent Blue
      Color(0xFF1E3C72), // Navy Blue sombre
    ],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00C853),
      Color(0xFF009624),
    ],
  );
}