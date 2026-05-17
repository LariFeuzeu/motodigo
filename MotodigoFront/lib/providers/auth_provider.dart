import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../providers/trip_provider.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  File? _profileImageFile;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;


  String? _accessToken;
  bool _isLoggedIn = false;
  bool _initialized = false;
  String? _verificationId;
  bool _isLoading = false;

  // Getters
  File? get profileImageFile => _profileImageFile; // Getter pour l'UI
  bool get isLoggedIn => _isLoggedIn;

  bool get initialized => _initialized;

  String? get accessToken => _accessToken;

  bool get isLoading => _isLoading;

  // Dans AuthProvider.dart
  String _currentCountryCode = "CM"; // Défaut par défaut

  String get currentCountryCode => _currentCountryCode;

  void setCountryCode(String code) {
    _currentCountryCode = code;
    notifyListeners();
  }
  /// Initialisation au démarrage : Vérifie si un token existe en local
  Future<void> initializeAuth() async {
    final token = await _secureStorage.read(key: 'access_token');
    if (token != null) {
      _accessToken = token;
      _isLoggedIn = true;
    }
    _initialized = true;
    notifyListeners();
  }

  ///  Envoyer le SMS via Firebase
  Future<void> sendOtp(String phoneNumber, Function(String) onCodeSent) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Sur certains Android, Firebase valide le SMS automatiquement
          await _signInWithFirebaseCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _isLoading = false; // On arrête le chargement
          notifyListeners(); // On rafraîchit l'UI pour faire disparaître le cercle

          print("DEBUG FIREBASE: ${e.code} - ${e.message}");

          // On affiche l'erreur réelle à l'utilisateur
          String errorMessage = "Erreur de connexion";
          if (e.code == 'network-request-failed') {
            errorMessage = "Vérifiez votre connexion internet.";
          } else if (e.code == 'invalid-phone-number') {
            errorMessage = "Numéro de téléphone invalide.";
          }

          throw Exception(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _isLoading = false;
          notifyListeners();
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// --- ÉTAPE 2 : Vérifier le code OTP ---
  Future<void> verifyOtpAndLogin(
    String smsCode, {
    String? explicitVerificationId,
  }) async {
    final vid = explicitVerificationId ?? _verificationId;
    if (vid == null) throw Exception("Session expirée. Renvoyez le code.");

    // _isLoading = true;
    // notifyListeners();

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: vid,
        smsCode: smsCode,
      );

      await _signInWithFirebaseCredential(credential);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fonction interne d'échange de token (Firebase -> FastAPI)
  Future<void> _signInWithFirebaseCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      // 1. Authentification Firebase
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      // 2. Récupération de l'ID Token (La preuve de succès pour ton backend)
      final idToken = await userCredential.user?.getIdToken();

      if (idToken != null) {
        // 3. Échange avec FastAPI
        final tokens = await _apiService.loginWithFirebase(idToken);
        await _handleLoginSuccess(tokens);
      }
    } on FirebaseAuthException {
      throw Exception("Code OTP incorrect ou expiré.");
    } catch (e) {
      // Si le backend renvoie 404 (USER_NOT_FOUND), on laisse l'UI capturer l'erreur
      // pour rediriger vers l'écran Register.
      rethrow;
    }
  }
  void setProfileImage(File image) {
    _profileImageFile = image;
    notifyListeners(); // Prévenir l'UI que l'image est sélectionnée
  }

  ///  Inscription Création du profil dans PostgreSQL
  Future<void> register(Map<String, dynamic> userData) async {
    if (_profileImageFile == null) {
      throw Exception("Veuillez sélectionner une photo de profil.");
    }
    _isLoading = true;
    notifyListeners();

    try {
      final user = _firebaseAuth.currentUser;


      // On prépare le payload exact pour UserCreate (Pydantic)
      final Map<String, dynamic> completeData = {
        'full_name': userData['full_name'],
        'email': userData['email'],
        'phone': user?.phoneNumber ?? "",
        // Doit être 'passenger' ou 'driver' (minuscules, comme ton Enum Python)
        'role': userData['role'] ?? 'passenger',
        // Doit faire 2 caractères max (ex: 'CM')
        'country_code': userData['country_code'] ?? 'CM',
        // ATTENTION : Ton modèle Python attend 'password_hash'
        'password_hash': userData['password'],
        'firebase_uid': user?.uid ?? "",
      };

      print("Envoi des données au backend : $completeData");

      final tokens = await _apiService.registerAfterFirebase(
        userData: completeData,
        profilePhoto: _profileImageFile!, // Le fichier de la photo
      );
      await _handleLoginSuccess(tokens);
    } catch (e) {
      print("Erreur Inscription détaillée : $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Persistance des tokens JWT Empire
  Future<void> _handleLoginSuccess(Map<String, dynamic> tokens) async {
    if (tokens is Map<String, dynamic> && tokens.containsKey('access_token')) {
      _accessToken = tokens['access_token'];
      await _secureStorage.write(key: 'access_token', value: _accessToken);
      await _secureStorage.write(
        key: 'refresh_token',
        value: tokens['refresh_token'],
      );

      _isLoggedIn = true;
      notifyListeners();
    } else {
      // Si le serveur a répondu n'importe quoi (ex: une String d'erreur)
      print("Format de tokens invalide reçu: $tokens");
      throw Exception("Le serveur a renvoyé un format de données invalide.");
    }
  }

  /// Déconnexion complète (Firebase + Local)
  Future<void> logout() async {
    _accessToken = null;
    _isLoggedIn = false;
    await _firebaseAuth.signOut();
    await _secureStorage.deleteAll();
    notifyListeners();
  }
}
