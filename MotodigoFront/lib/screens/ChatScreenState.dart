import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';
import '../providers/user_provider.dart';
import '../providers/trip_provider.dart';

class ChatScreen extends StatefulWidget {
  final int tripId; // L'ID du trajet (pour savoir de quoi on parle)
  final int receiverId; // L'ID de celui qui reçoit (le chauffeur ou le passager)
  final String receiverName; // Le nom à afficher en haut

  const ChatScreen({
    super.key,
    required this.tripId,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Le contrôleur pour le champ de texte ce qu'on écrit
  final TextEditingController _messageController = TextEditingController();
  // Le contrôleur pour faire défiler la liste vers le bas automatiquement
  final ScrollController _scrollController = ScrollController();
  // Le chrono qui va demander au serveur s'il y a du nouveau
  Timer? _chatTimer;

  @override
  void initState() {
    super.initState();
    ////  On demande les messages dès que l'écran s'affiche
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMessages());

    // On crée une boucle : toutes les 3 secondes, on appelle _loadMessages
    _chatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) _loadMessages(); //"if mounted" vérifie que l'utilisateur est encore sur l'écran
    });
  }

  void _loadMessages() {
    // On va chercher la fonction dans le Provider pour rafraîchir la liste
    context.read<TripProvider>().fetchMessages(widget.tripId);
  }

  @override
  void dispose() {
    _chatTimer?.cancel(); // On arrête le chrono quand on quitte l'écran
    _messageController.dispose(); // On libère la mémoire
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch pour reconstruire l'UI quand les messages changent
    final tripProvider = context.watch<TripProvider>();
    // On récupère uniquement les messages de CE trajet
    final messages = tripProvider.getMessagesByTrip(widget.tripId);
    // On suppose que l'ID de l'utilisateur actuel est dans UserProvider
    final currentUserId = context.read<UserProvider>().currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.lightBackground, // Fond gris léger Uber style
      appBar: AppBar( /* ... Configuration de la barre du haut ... */
        elevation: 0.5,
        backgroundColor: AppColors.surfaceWhite,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.accentBlue.withOpacity(0.1),
              child: Text(widget.receiverName[0],
                  style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.receiverName,
                      style: const TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text("En ligne", style: TextStyle(color: AppColors.successGreen, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty && tripProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue)) // On affiche un chargement au début
                : ListView.builder(
              controller: _scrollController, // On lie le contrôleur de défilement
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: messages.length, // Nombre de messages à afficher
              itemBuilder: (context, index) {
                final msg = messages[index];
                // Si l'envoyeur c'est moi, isMe = true
                final bool isMe = msg['sender_id'] == currentUserId;
                return _buildChatBubble(msg, isMe); // On crée la bulle
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(dynamic msg, bool isMe) {
    final DateTime time = DateTime.parse(msg['created_at']); // Heure du serveur
    final String formattedTime = DateFormat('HH:mm').format(time); // Formatage 14:30

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, // Droite si c'est moi
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Max 75% de l'écran
            decoration: BoxDecoration(
              color: isMe ? AppColors.accentBlue : AppColors.surfaceWhite, // Bleu si moi, Blanc si lui
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
              ],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 0), // Coin pointu à gauche si c'est lui
                bottomRight: Radius.circular(isMe ? 0 : 16), // Coin pointu à droite si c'est moi
              ),
            ),
            child: Text(
              msg['content'],
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textMain,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formattedTime,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 10), // Petite heure sous la bulle
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: "Message...",
                    hintStyle: TextStyle(color: AppColors.textGrey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _handleSend,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.premiumGradient,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSend() async {
    final text = _messageController.text.trim(); // On récupère le texte sans les espaces inutiles
    if (text.isEmpty) return; // Si c'est vide, on ne fait rien

    _messageController.clear();  // On vide le champ de texte immédiatement effet fluide

    // On envoie au serveur via le Provider
    final success = await context.read<TripProvider>().sendMessage(
      tripId: widget.tripId,
      receiverId: widget.receiverId,
      content: text,
    );

    if (success) {
      _scrollToBottom(); // Si ça a marché, on descend tout en bas de la liste
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
}