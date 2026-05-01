import 'package:flutter/material.dart';

class TopbarWidget extends StatelessWidget {
  const TopbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo Section
          Image.asset(
            'assets/images/logo.png',
            height: 150, // Increased logo size
            width: 150,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            // errorBuilder: (context, error, stackTrace) => const Row(
              // children: [
              //   Icon(Icons.check_box_outlined, color: Color(0xFF4CAF50), size: 38), // Increased icon size
              //   SizedBox(width: 8),
              //   Text(
              //     'KrishiDealer',
              //     style: TextStyle(
              //       fontWeight: FontWeight.bold,
              //       fontSize: 24, // Increased font size
              //       color: Color(0xFF4CAF50),
              //       letterSpacing: -0.5,
              //     ),
              //   ),
              // ],
            // ),
          ),
          const Spacer(),
          
          // Search Field
          Container(
            width: 400, // Slightly reduced width to prevent overflow
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Search anything here...',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          
          const Spacer(),
          
          // Actions Section
          SizedBox(
            width: 320, // Increased width to prevent internal overflow
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildIconButton(
                  icon: Icons.notifications_none_outlined,
                  hasBadge: true,
                ),
                const SizedBox(width: 8),
                _buildIconButton(icon: Icons.mail_outline),
                const SizedBox(width: 8),
                _buildIconButton(icon: Icons.person_outline),
                const SizedBox(width: 16),
                const VerticalDivider(width: 1, indent: 20, endIndent: 20, color: Color(0xFFE5E7EB)),
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                      ),
                      child: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFFF3F4F6),
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=admin'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Super Admin',
                              style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                            ),
                            Icon(Icons.keyboard_arrow_down, size: 12, color: Color(0xFF6B7280)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, bool hasBadge = false}) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(icon, color: const Color(0xFF4B5563), size: 20),
        ),
        if (hasBadge)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
