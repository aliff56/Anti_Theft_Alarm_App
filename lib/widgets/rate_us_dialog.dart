import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RateUsDialog extends StatefulWidget {
  const RateUsDialog({Key? key}) : super(key: key);

  @override
  State<RateUsDialog> createState() => _RateUsDialogState();
}

class _RateUsDialogState extends State<RateUsDialog> {
  int _rating = 5;
  @override
  Widget build(BuildContext context) {
    final Color mainColor = const Color(0xFF213B44);
    String emojiAsset;
    String text;
    // Assign a different emoji for each star rating
    switch (_rating) {
      case 1:
        emojiAsset = 'assets/icons/Very Sad Emoji.png';
        text = "We're sorry to hear that";
        break;
      case 2:
        emojiAsset = 'assets/icons/Face with Cold Sweat Emoji.png';
        text = "We'll try to do better";
        break;
      case 3:
        emojiAsset = 'assets/icons/Neutral Face Emoji.png';
        text = 'Appreciate your feedback!';
        break;
      case 4:
        emojiAsset = 'assets/icons/Smiling Face Emoji with Blushed Cheeks.png';
        text = 'Thanks for the rating!';
        break;
      case 5:
      default:
        emojiAsset = 'assets/icons/Heart Eyes Emoji.png';
        text = 'We like you too!';
        break;
    }
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Rate us !',
              style: GoogleFonts.poppins(
                color: mainColor,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return IconButton(
                  icon: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: mainColor,
                    size: 32,
                  ),
                  splashRadius: 20,
                  onPressed: () => setState(() => _rating = i + 1),
                );
              }),
            ),
            const SizedBox(height: 8),
            Image.asset(emojiAsset, width: 48, height: 48, fit: BoxFit.contain),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: mainColor,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
