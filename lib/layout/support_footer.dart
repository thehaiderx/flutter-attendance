import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportFooter extends StatelessWidget {
  const SupportFooter({super.key});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  // Cool & Minimal QR Overlay
  void _showQrDialog(BuildContext context, String imagePath, String title) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87, // Deep dark overlay
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.all(40),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F26), // Dark Grey/Blue
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 20),
                  // QR Image Size Fix: Screen ki 40% height se zyada nahi hoga
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset(imagePath, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Text("CLOSE", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Stealth Bottom Sheet
  void _showSupportMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1117), // GitHub Dark style
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 30),
            _stealthButton(context, "Patreon", "assets/support/patreon.png", () => _launchURL("https://patreon.com")),
            _stealthButton(context, "JazzCash QR", null, () => _showQrDialog(context, "assets/support/jazzcash.png", "JazzCash"), isQr: true),
            _stealthButton(context, "Binance QR", null, () => _showQrDialog(context, "assets/support/binance.png", "Binance Pay"), isQr: true),
            _stealthButton(context, "Crypto Address", null, () => _showQrDialog(context, "assets/support/crpto_address.jfif", "USDT Address"), isQr: true),
          ],
        ),
      ),
    );
  }

  Widget _stealthButton(BuildContext context, String label, String? iconPath, VoidCallback action, {bool isQr = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Icon(isQr ? Icons.qr_code_2 : Icons.link, color: Colors.blueGrey, size: 20),
              const SizedBox(width: 15),
              Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, color: Colors.white10, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
      color: const Color(0xFF0D1117),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _footerText("✨ SUPPORT PROJECT", () => _showSupportMenu(context)),
              _footerText("CONTACT DEV", () => _launchURL("https://wa.me/923333525173")),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Made with ", style: TextStyle(fontSize: 10, color: Colors.white24)),
              const Text("❤️", style: TextStyle(fontSize: 10, color: Colors.redAccent)),
              const Text(" By ", style: TextStyle(fontSize: 10, color: Colors.white24)),
              _footerText("Ali Haider", () => _launchURL("https://linkedin.com/in/..."), isBold: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footerText(String text, VoidCallback onTap, {bool isBold = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(text, 
        style: TextStyle(
          fontSize: 10, 
          color: Colors.white54, 
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          letterSpacing: 0.5
        )
      ),
    );
  }
}