import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isLoading;

  const GlassPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isPrimary 
                ? const Color.fromRGBO(0, 0, 0, 0.07) 
                : const Color.fromRGBO(255, 255, 255, 0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color.fromRGBO(0, 0, 0, 0.08), 
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 18, height: 18, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                  )
                else
                  Icon(icon, size: 20, color: Colors.black87),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600, 
                    color: Colors.black87, 
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
