import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'widgets/shimmer_widgets.dart';
// Imports Providers
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/location_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Imports Screens
import 'screens/PhoneInputScreen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'utils/app_colors.dart';
import 'firebase_options.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cette ligne est le "pont" universel pour Android, iOS et Web
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('fr_FR', null);

  // --- CONFIGURATION SYSTÈME INITIALE ---
  // On rend la barre de navigation transparente pour qu'elle puisse prendre
  // la couleur du fond des écrans (Edge-to-Edge)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent, // Transparente pour laisser passer le fond
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Optionnel : Forcer l'affichage plein écran sur Android (Edge-to-Edge)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final apiService = ApiService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initializeAuth()),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, auth, user) => (user ?? UserProvider())..updateAuth(auth),
        ),
        ChangeNotifierProvider(create: (_) => TripProvider(apiService)),
        ChangeNotifierProvider(create: (_) => LocationProvider(apiService)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MotoDigo',
      theme: ThemeData(
        useMaterial3: true,
        // Utilisation de tes couleurs centralisées
        scaffoldBackgroundColor: AppColors.lightBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accentBlue,
          primary: AppColors.primaryDark,
          secondary: AppColors.accentBlue,
          surface: Colors.white,
        ),
        // Style global des AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.primaryDark),
          titleTextStyle: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            // C'est ici qu'on assure que la barre du bas suit le thème
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        ),
        // Style des boutons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const AppRouter(),
      routes: {
        '/login': (context) => const PhoneInputScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, auth, userProv, _) {
        //  Splash Screen : Firebase n'est pas encore prêt
        if (!auth.initialized) return const CustomSplashScreen();

        //  Non authentifié : écran de login
        if (!auth.isLoggedIn) return const PhoneInputScreen();

        //  Authentifié mais données utilisateur manquantes
        // Ici, on ne met plus le Scaffold avec le CircularProgressIndicator
        if (userProv.currentUser == null) {
          // On déclenche le chargement si ce n'est pas déjà en cours
          if (!userProv.isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              userProv.fetchUserProfile();
            });
          }
          // On retourne directement le Shimmer (zéro circulaire, zéro texte)
          return const HomeShimmer();
        }

        // 4. Données chargées : Home
        return const HomeScreen();
      },
    );
  }
}

class CustomSplashScreen extends StatelessWidget {
  const CustomSplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(color: AppColors.accentBlue)),
  );
}