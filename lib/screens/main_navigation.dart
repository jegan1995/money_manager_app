// lib/screens/main_navigation.dart
import 'package:flutter/material.dart';
import 'smart_dashboard.dart';
import 'accounts_screen.dart';
import 'enhanced_reports_screen.dart';
import 'more_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const SmartDashboard(),
    const AccountsScreen(),
    const EnhancedReportsScreen(),
    const MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12, offset: const Offset(0, -4),
          )],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_rounded,
                    Icons.home_outlined, 'Home'),
                _navItem(1, Icons.account_balance_wallet_rounded,
                    Icons.account_balance_wallet_outlined, 'Accounts'),
                _navItem(2, Icons.insert_chart_rounded,
                    Icons.insert_chart_outlined, 'Reports'),
                _navItem(3, Icons.grid_view_rounded,
                    Icons.grid_view_outlined, 'More'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int idx, IconData active, IconData inactive,
      String label) {
    final sel   = _currentIndex == idx;
    final color = sel ? const Color(0xFF667eea) : Colors.grey;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 6),
        decoration: sel ? BoxDecoration(
          color: const Color(0xFF667eea).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ) : null,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(sel ? active : inactive, color: color, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
              fontSize: 10, color: color,
              fontWeight: sel
                  ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}