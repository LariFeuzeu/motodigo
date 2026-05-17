import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class UserProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  AuthProvider? _authProvider;
  User? _currentUser;
  bool _isLoading = false;

  // Initialisé par défaut, mais sera écrasé par l'Auth
  String _userCountryCode = 'CM';

  // --- Getters ---
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String get userCountryCode => _userCountryCode;

  /// Synchronisation intelligente avec AuthProvider via ProxyProvider
  void updateAuth(AuthProvider auth) {
    final bool wasLoggedIn = _authProvider?.isLoggedIn ?? false;
    _authProvider = auth;

    // 1. Mise à jour immédiate du pays choisi lors du login
    if (_userCountryCode != auth.currentCountryCode) {
      _userCountryCode = auth.currentCountryCode;
      // On sauvegarde en cache pour que les autres services y accèdent
      _saveCountryToPrefs(_userCountryCode);
    }

    // 2. Gestion automatique de la session
    if (!auth.isLoggedIn && wasLoggedIn) {
      // Si déconnexion détectée
      clearUser();
    } else if (auth.isLoggedIn && !wasLoggedIn) {
      // Si nouvelle connexion détectée, on charge le profil automatiquement
      fetchUserProfile();
    }
  }

  ///  Récupère le profil (SharedPreferences d'abord, puis API)
  Future<void> fetchUserProfile({bool shouldLogoutOnError = true}) async {
    // On ne met pas _isLoading à true ici pour permettre un rafraîchissement
    // silencieux sans bloquer l'interface utilisateur.
    _isLoading = true;
    notifyListeners(); // Affiche le Shimmer
    try {
      final prefs = await SharedPreferences.getInstance();

      //  Charger le cache SharedPreferences pour un affichage instantané
      if (_currentUser == null) {
        final cached = prefs.getString('user_profile_cache');
        if (cached != null) {
          _currentUser = User.fromJson(jsonDecode(cached));
          notifyListeners();
        }
      }

      //  Appel API pour rafraîchir les données
      final userData = await _apiService.fetchUserProfile().timeout(const Duration(seconds: 10));
      _currentUser = User.fromJson(userData);

      //  Mise à jour du cache local
      await prefs.setString('user_profile_cache', jsonEncode(userData));
      notifyListeners();

    } on DioException catch (e) {
      debugPrint(" UserProvider API Error: ${e.message}");
      if (e.response?.statusCode == 401 && shouldLogoutOnError) {
        _handleSessionExpired();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ///  Méthodes privées de gestion
  void _handleSessionExpired() {
    clearUser();
    _authProvider?.logout();
  }

  Future<void> _saveCountryToPrefs(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_country_code', code);
    notifyListeners();
  }

  ///  Actions de profil (Chauffeur / Véhicule)
  Future<void> requestDriverRole() async {
    if (_currentUser == null || _isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      final updatedData = await _apiService.updateUserProfile({'requested_role': 'driver'});
      _currentUser = User.fromJson(updatedData);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Erreur promotion: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> registerVehicleAndPromote({
    required Map<String, String> vehicleData,
    required File vehiclePhoto,
    required File regCardFile,
    required File techInspFile,
  }) async {
    if (_currentUser == null) throw Exception("Non connecté");
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.registerVehicleAndPromote(
        vehicleData: vehicleData,
        vehiclePhoto: vehiclePhoto,
        regCardFile: regCardFile,
        techInspFile: techInspFile,
      );
      // On rafraîchit le profil pour obtenir le nouveau statut/véhicule
      await fetchUserProfile(shouldLogoutOnError: false);
      return response;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ///  Nettoyage complet (Logout)
  void clearUser() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_profile_cache'); // Nettoyage impératif du cache
    notifyListeners();
  }
}