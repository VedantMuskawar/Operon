import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class DriverMapPage extends StatelessWidget {
  const DriverMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Map (coming soon)',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 18,
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

