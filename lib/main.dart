import 'package:flutter/material.dart';

import 'ble_screen.dart';

// Phone Connection chat feature disabled for now — see HomeScreen below.
// import 'chat_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LED App',
      theme: _buildTheme(),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3D5AFE),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        elevation: 0,
        indicatorColor: colorScheme.primaryContainer,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide.none,
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Chat feature disabled for now — see commented-out tab wiring below.
  // int _index = 0;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: BleScreen(),
    );
  }

  // Multi-tab version (LED Sign + Phone Connection chat). Re-enable by
  // restoring the import above, replacing the build() method with this one,
  // and removing the leading underscore workaround if any.
  //
  // Widget _buildWithChatTab(BuildContext context) {
  //   return Scaffold(
  //     body: IndexedStack(
  //       index: _index,
  //       children: const [
  //         BleScreen(),
  //         ChatScreen(),
  //       ],
  //     ),
  //     bottomNavigationBar: NavigationBar(
  //       selectedIndex: _index,
  //       onDestinationSelected: (index) {
  //         setState(() {
  //           _index = index;
  //         });
  //       },
  //       destinations: const [
  //         NavigationDestination(
  //           icon: Icon(Icons.tv_outlined),
  //           selectedIcon: Icon(Icons.tv),
  //           label: 'LED Sign',
  //         ),
  //         NavigationDestination(
  //           icon: Icon(Icons.chat_bubble_outline),
  //           selectedIcon: Icon(Icons.chat_bubble),
  //           label: 'Phone Connection',
  //         ),
  //       ],
  //     ),
  //   );
  // }
}
