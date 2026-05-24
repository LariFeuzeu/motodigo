import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../screens/PhoneInputScreen.dart';
import '../screens/MyBookingsScreen.dart';
import '../screens/MyTripsScreen.dart';

class ProfileDrawer extends StatelessWidget {
  final User user;
  final double scale;

  const ProfileDrawer({
    super.key,
    required this.user,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDriver = user.role == 'driver';
    final double rating = user.rating;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 💎 HEADER PREMIUM CUSTOM
          _buildPremiumHeader(context, isDriver, rating),

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              "MENU PRINCIPAL",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade400,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // 📜 OPTIONS DU MENU (Design épuré et moderne)
          _buildMenuTile(
            icon: Icons.history_rounded,
            title: "Mes Réservations",
            subtitle: "Historique de vos déplacements",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
            },
          ),

          if (isDriver)
            _buildMenuTile(
              icon: Icons.alt_route_rounded,
              title: "Mes Trajets",
              subtitle: "Planifier et gérer vos courses",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTripsScreen()));
              },
            ),

          _buildMenuTile(
            icon: Icons.person_outline_rounded,
            title: "Mon Profil",
            subtitle: "Gérer vos informations personnelles",
            onTap: () {
              Navigator.pop(context);
              // TODO: Ajouter la navigation vers ton écran de profil
            },
          ),

          _buildMenuTile(
            icon: Icons.help_outline_rounded,
            title: "Support & Aide",
            subtitle: "Contacter le service client",
            onTap: () {
              Navigator.pop(context);
            },
          ),

          const Spacer(),

          // 🚪 BOUTON DE DÉCONNEXION PREMIUM
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppColors.errorRed, size: 20),
                ),
                title: const Text(
                  "Déconnexion",
                  style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onTap: () async {
                  //
                  // On ferme le drawer instantanément pour donner une sensation de rapidité
                  Navigator.pop(context);

                  //
                  // On ne fait pas attendre l'UI pour la réponse serveur
                  context.read<AuthProvider>().logout();

                  //
                  // On utilise pushAndRemoveUntil pour nettoyer toute la pile de navigation
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
                            (route) => false
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 Widget : Header sur mesure
  Widget _buildPremiumHeader(BuildContext context, bool isDriver, double rating) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 25),
      decoration: const BoxDecoration(
        gradient: AppColors.premiumGradient,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar avec une bordure blanche premium discrète
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                ),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  backgroundImage: (user.profilePhotoUrl != null && user.profilePhotoUrl!.isNotEmpty)
                      ? NetworkImage("${ApiService.baseUrl}${user.profilePhotoUrl}")
                      : null,
                  child: (user.profilePhotoUrl == null || user.profilePhotoUrl!.isEmpty)
                      ? Text(
                    user.fullName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                  )
                      : null,
                ),
              ),
              const Spacer(),
              // Badge de rôle stylisé
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isDriver ? "CHAUFFEUR" : "PASSAGER",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Nom complet
          Text(
            user.fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          // Note globale (si chauffeur) ou numéro de téléphone anonymisé/statut
          Row(
            children: [
              Icon(
                isDriver ? Icons.verified_user_rounded : Icons.shield_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                isDriver ? "Compte Chauffeur Vérifié" : "Compte Sécurisé",
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500),
              ),
              if (isDriver && rating > 0) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                      ]
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }

  //  Boutons du menu élégants
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        onTap: onTap,
        dense: true,
        horizontalTitleGap: 15,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accentBlue.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.grey.shade300,
          size: 12,
        ),
      ),
    );
  }
}