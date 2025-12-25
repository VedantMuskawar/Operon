import 'package:flutter/material.dart';

class LoginPageShell extends StatelessWidget {
  const LoginPageShell({
    super.key,
    required this.child,
    this.title = 'Welcome!'
        ' Log in to Dash SuperAdmin to continue.',
  });

  final Widget child;
  final String title;

  static const _outerBackground = Color(0xFF020205);
  static const _panelColor = Color(0xFF0B0B12);
  static const _dividerColor = Color(0x1AFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _outerBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 720),
            decoration: BoxDecoration(
              color: _panelColor,
              borderRadius: BorderRadius.circular(48),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 70,
                  offset: Offset(0, 35),
                ),
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(48),
                        bottomLeft: Radius.circular(48),
                      ),
                      gradient: LinearGradient(
                        colors: [Color(0xFF0E0E17), Color(0xFF08080F)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 56,
                          vertical: 48,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF9F7BFF),
                                          Color(0xFF6F4BFF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.blur_on,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    'Dash SuperAdmin',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 48),
                              Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF11111D),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: _dividerColor),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x11000000),
                                      blurRadius: 20,
                                      offset: Offset(0, 12),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 32,
                                ),
                                child: child,
                              ),
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(48),
                      bottomRight: Radius.circular(48),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF080816),
                            Color(0xFF0C0C1F),
                            Color(0xFF120F25),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 120,
                            right: 140,
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(48),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0x332E1BFF),
                                    Color(0x003C1DA6),
                                  ],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x40836DFF),
                                    blurRadius: 100,
                                    spreadRadius: 40,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
