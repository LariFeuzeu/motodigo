import 'dart:convert';

import 'package:dio/dio.dart'; //pour faire des requetes
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; //stockage des donnees sensibles
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:untitled/models/location.dart';
import 'package:http/http.dart' as http;

class ApiService {
  bool _isRefreshing = false; //On déclare le verrou ici, au niveau de la classe
  //Utiliser un ip de la mchine
  static const String baseUrl = "https://wobbily-untheatrical-zuri.ngrok-free.dev";

  // gere les requete http
  // Header Ngrok
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {
      'ngrok-skip-browser-warning': 'true',
      // CETTE LIGNE EST INDISPENSABLE
      'Accept': 'application/json',
    },
  ));
  final FlutterSecureStorage _secureStorage =
  const FlutterSecureStorage(); //gere le stockage

  // Dans ton ApiService.dart

  ApiService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['ngrok-skip-browser-warning'] = 'true';
          return handler.next(options);
        },

        onError: (DioException e, handler) async {
          // On ne tente le refresh que si c'est une erreur 401 (Unauthorized)
          if (e.response?.statusCode == 401 && !_isRefreshing) {
            _isRefreshing = true; // On verrouille
            final refreshToken = await _secureStorage.read(
                key: 'refresh_token');

            if (refreshToken != null) {
              try {
                //  Utiliser une instance Dio NEUVE sans intercepteur
                // pour éviter une boucle infinie de refresh
                final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));

                final response = await refreshDio.post(
                  "/api/v1/auth/refresh",
                  queryParameters: {
                    'refresh_token': refreshToken
                  }, // ou data selon ton endpoint
                );

                if (response.statusCode == 200) {
                  final newAccess = response.data['access_token'];
                  final newRefresh = response.data['refresh_token'];

                  //  Sauvegarde des nouveaux tokens (Rotation)
                  await _secureStorage.write(
                      key: 'access_token', value: newAccess);
                  await _secureStorage.write(
                      key: 'refresh_token', value: newRefresh);

                  _isRefreshing = false; // On déverrouille après succès

                  final newHeaders = Map<String, dynamic>.from(
                      e.requestOptions.headers);
                  newHeaders['Authorization'] = 'Bearer $newAccess';
                  newHeaders['ngrok-skip-browser-warning'] = 'true';

                  //  On relance la requête originale qui avait échoué
                  // e.requestOptions.headers['Authorization'] = 'Bearer $newAccess';

                  // On crée un clone de la requête originale
                  final opts = Options(
                    method: e.requestOptions.method,
                    headers: e.requestOptions.headers,
                    contentType: e.requestOptions.contentType,
                  );
                  // On utilise refreshDio pour éviter que l'intercepteur '\onRequest principal
                  // ne vienne interférer ou écraser le header Authorization qu'on vient de fixer.
                  final retryResponse = await _dio.request(
                    e.requestOptions.path,
                    options: opts,
                    data: e.requestOptions.data,
                    queryParameters: e.requestOptions.queryParameters,
                  );

                  // On renvoie la réponse réussie au reste de l'application
                  return handler.resolve(retryResponse);
                }
              } catch (err) {
                _isRefreshing = false; // On déverrouille après succès
                // Si le refresh échoue (ex: refresh token expiré après 30 jours)
                // On déconnecte proprement l'utilisateur
                await _secureStorage.deleteAll();

                // Optionnel : Tu peux notifier ton AuthProvider ici via un stream ou un callback
                print("Session morte : Redirection vers Login");
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // Quand c’est fini, on obtient un Map JSON contenant access_token et refresh_token
  // Échange le token Firebase contre un JWT Empire
  Future<Map<String, dynamic>> loginWithFirebase(String idToken) async {
    try {
      final response = await _dio.post(
        "/api/v1/auth/login/firebase",
        data: {'id_token': idToken},
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception("USER_NOT_FOUND"); // Indique qu'il faut créer le profil
      }
      throw Exception("Erreur d'authentification serveur");
    }
  }

  // Inscription finale après vérification OTP
  // Inscription finale avec envoi de la photo de profil (Multipart)
  Future<Map<String, dynamic>> registerAfterFirebase({
    required Map<String, dynamic> userData,
    required File profilePhoto,
  }) async {
    try {
      // 1. On transforme le Map en FormData pour supporter le fichier
      FormData formData = FormData.fromMap({
        "full_name": userData['full_name'],
        "email": userData['email'],
        "phone": userData['phone'],
        "password": userData['password'],
        "role": userData['role'],
        "firebase_uid": userData['firebase_uid'],
        "country_code": userData['country_code'] ?? 'CM',
        // On ajoute le fichier image
        "profile_photo": await MultipartFile.fromFile(
          profilePhoto.path,
          filename: "profile_${userData['firebase_uid']}.jpg",
          contentType: MediaType(
              'image', 'jpeg'), // Nécessite l'import http_parser
        ),
      });

      // 2. Envoi à la route /register
      final response = await _dio.post(
        "/api/v1/auth/register",
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return response.data; // Retourne les Tokens
    } on DioException catch (e) {
      final errorMessage = e.response?.data is Map
          ? e.response?.data['detail']
          : "Erreur lors de l'inscription";
      print("🛑 ERREUR API REGISTER: $errorMessage");
      throw Exception(errorMessage);
    }
  }


  // Elle utilise automatiquement le token JWT grâce à l’intercepteur
  Future<Map<String, dynamic>> fetchUserProfile() async {
    try {
      final reponse = await _dio.get("/api/v1/users/me/");
      return reponse.data;
    } on DioException {
      throw Exception("Impossible de charger le profil.");
    }
  }


  // Fonction de Mise à jour du Profil (PATCH /api/v1/users/me)
  Future<Map<String, dynamic>> updateUserProfile(
      Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch(
        "/api/v1/users/me/",
        data: data, // Ex: {'requested_role': 'driver'}
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        // Gérer les erreurs métier spécifiques
        throw Exception(
            e.response!.data['detail'] ?? "Erreur lors de la mise à jour.");
      }
      throw Exception("Erreur réseau ou du serveur lors de la mise à jour.");
    }
  }


  // funtion add vehicle
  Future<Map<String, dynamic>> registerVehicleAndPromote({
    required Map<String, String> vehicleData,
    required File vehiclePhoto,
    required File regCardFile,
    required File techInspFile,
  }) async {
    try {
      //  Créer les objets MultipartFile
      final regCardPart = await MultipartFile.fromFile(
        regCardFile.path,
        filename: 'registration_card',
        // Le nom du fichier n'a pas d'importance ici
        contentType: MediaType('application',
            'octet-stream'), //'octet-stream' pour accepter tout type de fichier
      );
      final techInspPart = await MultipartFile.fromFile(
        techInspFile.path,
        filename: 'technical_inspection',
        contentType: MediaType('application', 'octet-stream'),
      );
      final vehiclePhoto = await MultipartFile.fromFile(
        techInspFile.path,
        filename: 'Photo_vehicule',
        contentType: MediaType('application', 'octet-stream'),
      );

      //  Créer le FormData (combinaison de champs texte et fichiers)
      FormData formData = FormData.fromMap({
        // Les champs texte doivent correspondre exactement aux paramètres @Form() du FastAPI
        "plate": vehicleData['plate']!,
        "model": vehicleData['model_name']!,
        "color": vehicleData['color']!,
        "seats": int.parse(vehicleData['seats']!.trim()),
        // Les noms des fichiers doivent correspondre aux paramètres UploadFile du FastAPI
        "registration_card": regCardPart,
        "technical_inspection": techInspPart,
        "vehicle_photo": vehiclePhoto,
      });

      // 3. Appel de l'API avec l'endpoint /register_full
      final response = await _dio.post(
        "/api/v1/vehicule/register_full",
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data;
    } on DioException catch (e) {
      print('CODE ERREUR SERVEUR: ${e.response?.statusCode}');
      print(' RÉPONSE DÉTAILLÉE DU SERVEUR: ${e.response?.data}');
      String detail = "Erreur lors de l'enregistrement du véhicule.";
      if (e.response?.statusCode == 400 && e.response?.data != null) {
        // Tente de récupérer le message d'erreur du backend (ex: "plaque deja enregistrée")
        detail = e.response!.data['detail'] ?? detail;
      }
      throw Exception(detail);
    }
  }


  //service api post trip
  Future<void> postTrip(Map<String, dynamic> tripData) async {
    try {
      final response = await _dio.post(
        "/api/v1/trips/", // L'endpoint FastAPI
        data: tripData,
      );

      if (response.statusCode != 201) {
        throw Exception('API a refusé la publication du trajet.');
      }
    } on DioException catch (e) {
      debugPrint('Erreur Dio lors de postTrip: ${e.response?.data}');
      // Relancer une exception claire pour que TripProvider la capture
      throw Exception('Erreur de réseau ou données invalides.');
    }
  }


  Future<List<dynamic>> getMyPublishedTrips() async {
    try {
      final response = await _dio.get("/api/v1/trips/meTrips");
      return response.data; // Retourne la liste des trajets JSON
    } on DioException catch (e) {
      throw Exception(
          e.response?.data['detail'] ?? "Erreur de récupération des trajets");
    }
  }


  Future<List<Map<String, dynamic>>> getDriverVehicles() async {
    try {
      // Utilisation du bon chemin défini dans ton main.py et vehicule.router
      final response = await _dio.get("/api/v1/vehicule/list_vehicule");
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      print("Erreur chargement véhicules: ${e.response?.data}");
      throw Exception("Impossible de charger vos véhicules.");
    }
  }

  // search suggestion and localisation avec Dio
  Future<List<Location>> searchLocation(String query,
      String countryCode) async {
    try {
      // On utilise _dio au lieu de http.post
      // Pas besoin de gérer le token ici, l'intercepteur s'en occupe déjà !
      final response = await _dio.post(
        "/api/v1/locations/searchlocation",
        // Dio    ajoute déjà le baseUrl automatiquement
        data: {
          'query': query,
          'country_code': countryCode.isEmpty ? 'CM' : countryCode,
        },
      );

      if (response.statusCode == 200) {
        // Dio décode automatiquement le JSON en List ou Map
        final List data = response.data;
        return data.map((item) => Location.fromJson(item)).toList();
      } else {
        throw Exception("Erreur API : ${response.statusCode}");
      }
    } on DioException catch (e) {
      print("Erreur Dio SearchLocation: ${e.response?.data}");
      throw Exception("Impossible de récupérer les suggestions.");
    }
  }


  Future <List<Map<String, dynamic>>> searchTrips(String origin,
      String destination, String date, String countryCode,
      {int seats = 1}) async {
    try {
      final response = await _dio.get(
        "/api/v1/trips/searchTrip",
        queryParameters: {
          'origin': origin,
          'destination': destination,
          'date': date,
          'country_code': countryCode,
          'seats': seats,
        },
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw Exception("Erreur lors de la recherche");
    }
  }

  // --- 1. RÉSERVER UN TRAJET ---
  Future<Response> postBooking(Map<String, dynamic> bookingData) async {
    try {
      // Rappel : bookingData contiendra { 'trip_id': id, 'payment_method': 'MTN' }
      final response = await _dio.post(
        "/api/v1/bookings/", // Endpoint FastAPI
        data: bookingData,
      );
      return response;
    } on DioException catch (e) {
      print('🛑 Erreur Réservation: ${e.response?.data}');
      // On récupère le message d'erreur du backend (ex: "Plus de places")
      String message = e.response?.data['detail'] ??
          "Erreur lors de la réservation";
      throw Exception(message);
    }
  }

  // ANNULER UNE RÉSERVATION regle des 12h Passager ---
  Future<Map<String, dynamic>> cancelBooking(int bookingId) async {
    try {
      final response = await _dio.delete("/api/v1/bookings/$bookingId/cancel");
      return response.data;
    } on DioException catch (e) {
      print('🛑 Erreur Annulation: ${e.response?.data}');
      // Le message "Annulation impossible moins de 12h avant le départ" viendra d'ici
      String message = e.response?.data['detail'] ??
          "Erreur lors de l'annulation";
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> cancelTrip(int tripId) async {
    try {
      final response = await _dio.delete("/api/v1/trips/$tripId/cancel");
      return response.data;
    } on DioException catch (e) {
      print('Erreur de suppression : ${e.response?.data}');
      String message = e.response?.data['detail'] ??
          "Erreur lors de la suppression";
      throw Exception(message);
    }
  }

  Future<List<dynamic>> getMyBookings() async {
    try {
      final response = await _dio.get("/api/v1/bookings/myBookings");
      return response.data; // C'est une liste de réservations JSON
    } catch (e) {
      throw Exception("Erreur lors du chargement des réservations");
    }
  }

  //  RÉCUPÉRER LES MESSAGES
  Future<List<dynamic>> getChatMessages(int tripId) async {
    try {
      // On utilise _dio pour que l'intercepteur ajoute le Token automatiquement
      final response = await _dio.get("/api/v1/messages/$tripId");

      if (response.statusCode == 200) {
        // Avec Dio, pas besoin de json.decode(), response.data est déjà une List
        return response.data;
      }
      throw Exception("Erreur lors du chargement des messages");
    } on DioException catch (e) {
      debugPrint("Erreur Chat GET: ${e.response?.data}");
      throw Exception("Session expirée ou erreur réseau sur le Chat");
    }
  }

// --- ENVOYER UN MESSAGE  ---
  Future<dynamic> postChatMessage(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        "/api/v1/messages/",
        data: data, // Dio convertit automatiquement la Map en JSON
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      debugPrint("Erreur Chat POST: ${e.response?.data}");
      return null;
    }
  }


  // RÉCUPÉRER LES PASSAGERS D'UN TRAJET Pour le chauffeur
  Future<List<dynamic>> getTripPassengers(int tripId) async {
    try {
      final response = await _dio.get("/api/v1/trips/$tripId/passengers");
      if (response.statusCode == 200) {
        return response.data; // Retourne la liste des passagers
      }
      return [];
    } catch (e) {
      print("Erreur ApiService getTripPassengers: $e");
      return [];
    }
  }

  Future<List<dynamic>> getUserDiscussions() async {
    try {
      // On appelle la route de ton backend FastAPI
      final response = await _dio.get("/api/v1/messages/discussions");

      if (response.statusCode == 200) {
        return response.data; // Retourne la liste des discussions
      } else {
        throw Exception("Erreur lors de la récupération des discussions");
      }
    } catch (e) {
      rethrow;
    }
  }
  Future <Response> startTrip(int tripId) async {
    try{
      final response = await _dio.patch("/api/v1/trips/$tripId/start");
      return response;
    }
    catch(e){
      debugPrint("🚨 [ApiService] Erreur startTrip: $e");
      rethrow;
    }
  }
  Future<Response> completeTrip(int tripId) async{
    try{
      final response = await _dio.patch("/api/v1/trips/$tripId/complete");
      return response;
    }
    catch(e)
    {
      debugPrint("🚨 [ApiService] Erreur startTrip: $e");
      rethrow;
    }
  }
  Future<Response> postReview(Map<String, dynamic> reviewData) async {
    try {
      // Dio gère automatiquement l'URL de base et injecte le Token grâce à l'intercepteur !
      final response = await _dio.post(
      "/api/v1/review/reviews",
        data: reviewData, // Converti automatiquement en JSON par Dio
      );
      return response;
    } on DioException catch (e) {
      // AJOUTE CES DEUX LIGNES TEMPORAIREMENT :
      debugPrint("🛑 CODE HTTP SERVEUR : ${e.response?.statusCode}");
      debugPrint("🛑 CONTENU DU REJET : ${e.response?.data}");
      debugPrint("🛑 [ApiService] Erreur postReview: ${e.response?.data}");
      String message = e.response?.data['detail'] ?? "Impossible d'enregistrer l'avis.";
      throw Exception(message);
    }
  }
}