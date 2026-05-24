import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../utils/app_colors.dart';

class ReviewBottomSheet extends StatefulWidget {
  final int tripId;
  final int toUserId;
  final String toUserName;

  const ReviewBottomSheet({
    super.key,
    required this.tripId,
    required this.toUserId,
    required this.toUserName,
  });

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  int _selectedRating = 5; // Note par défaut
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 20),
            Text(
              "NOTER ${widget.toUserName.toUpperCase()}",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 15),

            // Ligne d'étoiles interactives
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 38,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedRating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 15),

            // Champ de commentaire
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: "Laissez un commentaire sur votre expérience (optionnel)...",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                fillColor: AppColors.lightBackground,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                counterText: "",
              ),
            ),
            const SizedBox(height: 20),

            // Bouton d'action de soumission
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSending ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSending
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("PUBLIER L'AVIS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitReview() async {
    setState(() => _isSending = true);

    final error = await context.read<TripProvider>().sendTripReview(
      tripId: widget.tripId,
      toUserId: widget.toUserId,
      rating: _selectedRating,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSending = false);
      Navigator.pop(context); // Ferme le BottomSheet

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Merci pour votre avis ! ⭐"), backgroundColor: AppColors.successGreen),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }
}