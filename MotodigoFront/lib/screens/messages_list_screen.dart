import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trip_provider.dart';
import '../../utils/app_colors.dart';
import 'ChatScreenState.dart'; // Assure-toi que l'import vers ton fichier Chat est correct

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  @override
  void initState() {
    super.initState();
    // On charge les discussions dès que l'écran s'affiche
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().fetchUserDiscussions();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch permet de reconstruire l'écran dès que la liste change dans le Provider
    final tripProvider = context.watch<TripProvider>();
    final discussions = tripProvider.userDiscussions;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          "MES MESSAGES",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: AppColors.primaryDark,
      ),
      // Si on charge, on affiche le loader, sinon on affiche la liste ou le vide
      body: tripProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : discussions.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: discussions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final chat = discussions[index];
          return _buildConversationCard(context, chat);
        },
      ),
    );
  }

  Widget _buildConversationCard(BuildContext context, dynamic chat) {
    // On extrait les données pour plus de clarté
    // IMPORTANT : Vérifie que ton backend renvoie bien ces noms de clés exacts
    final String otherUserName = chat['other_user_name'] ?? "Utilisateur";
    final String lastMessage = chat['last_message'] ?? "";
    final int tripId = chat['trip_id'];
    final int otherUserId = chat['other_user_id'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        onTap: () {
          // Navigation vers l'écran de chat avec les infos de la discussion
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                tripId: tripId,
                receiverId: otherUserId,
                receiverName: otherUserName,
              ),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: AppColors.accentBlue.withOpacity(0.1),
          child: Text(
            otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : "?",
            style: const TextStyle(
              color: AppColors.accentBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          otherUserName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey, size: 20),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: AppColors.textGrey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            "Aucune discussion pour le moment",
            style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}