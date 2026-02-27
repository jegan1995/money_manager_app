import 'package:flutter/material.dart';
import 'home_screen.dart';
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

  // Budget removed — now lives as a tab inside EnhancedReportsScreen
  final List<Widget> _screens = const [
    HomeScreen(),
    AccountsScreen(),
    EnhancedReportsScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    const primary = Color(0xFF667eea);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_rounded,             Icons.home_outlined,            'Home',     primary),
                _navItem(1, Icons.account_balance_wallet,   Icons.account_balance_wallet_outlined, 'Accounts', primary),
                _navItem(2, Icons.insert_chart_rounded,     Icons.insert_chart_outlined,    'Reports',  primary),
                _navItem(3, Icons.grid_view_rounded,        Icons.grid_view_outlined,       'More',     primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData inactiveIcon,
      String label, Color primary) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () { if (_currentIndex != index) setState(() => _currentIndex = index); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primary.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            isActive ? activeIcon : inactiveIcon,
            color: isActive ? primary : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? primary : Colors.grey[400])),
        ]),
      ),
    );
  }
}