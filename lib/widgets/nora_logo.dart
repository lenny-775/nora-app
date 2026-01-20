import 'package:flutter/material.dart';

class NoraLogo extends StatelessWidget {
  final double size; 

  const NoraLogo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    const Color darkColor = Color(0xFF2D3436);
    const Color brandColor = Color(0xFFFF6B00);

    // 1. Style du texte
    TextStyle textStyle = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900, 
      color: darkColor,
      letterSpacing: 2.0, 
      fontFamily: 'Avenir', 
      height: 1.0, 
    );

    final double iconSize = size; 
    final double strokeWidth = size * 0.12; 
    final double leafSize = size * 0.45;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center, 
      children: [
        Text('N', style: textStyle),
        
        SizedBox(width: size * 0.08), 

        // --- LE "O" ---
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // L'ANNEAU
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: darkColor, 
                    width: strokeWidth, 
                  ),
                ),
              ),
              
              // LA FEUILLE D'ÉRABLE
              Image.network(
                "https://img.icons8.com/ios-filled/100/maple-leaf.png",
                width: leafSize,
                height: leafSize,
                color: brandColor,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.eco, color: brandColor, size: leafSize),
              ),
            ],
          ),
        ),

        SizedBox(width: size * 0.08), 
        
        Text('R', style: textStyle),
        SizedBox(width: size * 0.02), 
        Text('A', style: textStyle),
        
        // J'ai supprimé le Text('.') ici
      ],
    );
  }
}