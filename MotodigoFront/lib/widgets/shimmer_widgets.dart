import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Brique de base réutilisable pour créer n'importe quel Shimmer
class ShimmerBlock extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const ShimmerBlock({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// Squelette complet de la page d'accueil (Home) amélioré
class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header : Avatar + Texte
              Row(
                children: [
                  const ShimmerBlock(width: 55, height: 55, borderRadius: BorderRadius.all(Radius.circular(55))),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBlock(width: 140, height: 16),
                      SizedBox(height: 8),
                      ShimmerBlock(width: 90, height: 12),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Barre de recherche (Souvent plus arrondie pour un look moderne)
              const ShimmerBlock(height: 60, borderRadius: BorderRadius.all(Radius.circular(30))),

              const SizedBox(height: 35),

              // Section Titre
              const ShimmerBlock(width: 180, height: 22),

              const SizedBox(height: 20),

              // Liste de cartes de trajets
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3, // 3 ou 4 suffisent pour remplir l'écran
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, __) => Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            ShimmerBlock(width: 100, height: 15),
                            ShimmerBlock(width: 60, height: 15),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const ShimmerBlock(height: 40), // Zone trajet
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}