import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;

  const AnimatedBackground({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> {

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient layers
        _buildBackgroundGradients(),
        
        // Content
        widget.child,
      ],
    );
  }

  Widget _buildBackgroundGradients() {
    return Stack(
      children: [
        // Primary gradient - PaveBoard exact: bg-gradient-to-br from-gray-950 via-black to-gray-950
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF030712), // gray-950
                Color(0xFF000000), // black
                Color(0xFF030712), // gray-950
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        
        // Secondary gradient overlay - PaveBoard exact: bg-gradient-to-tr from-slate-900/30 via-transparent to-gray-900/30
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0x4D0F172A), // slate-900/30
                Colors.transparent,
                Color(0x4D111827), // gray-900/30
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        
        // Tertiary gradient overlay - PaveBoard exact: bg-gradient-to-bl from-black/20 via-transparent to-slate-900/20
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0x33000000), // black/20
                Colors.transparent,
                Color(0x330F172A), // slate-900/20
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        
        // Content area background patterns - PaveBoard exact
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0x26111827), // from-gray-900/15
                Colors.transparent,
                Color(0x26000000), // to-black/15
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0x141E293B), // from-slate-800/8
                Colors.transparent,
                Color(0x14111827), // to-gray-800/8
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
      ],
    );
  }

}
