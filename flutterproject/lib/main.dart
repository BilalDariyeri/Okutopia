import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/student_selection_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/groups_screen.dart';
import 'models/category_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // SharedPreferences'ı başlat
  final prefs = await SharedPreferences.getInstance();
  
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(prefs),
      child: MaterialApp(
        title: 'OKUTOPIA',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4834D4),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/student-selection': (context) => const StudentSelectionScreen(),
          '/categories': (context) => const CategoriesScreen(),
          '/groups': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
            final category = args?['category'] as Category?;
            if (category == null) {
              return const CategoriesScreen();
            }
            return GroupsScreen(category: category);
          },
        },
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          );
        },
        builder: (context, child) {
          return Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final route = ModalRoute.of(context);
              final routeName = route?.settings.name;

              // Auth durumuna göre yönlendirme
              if (routeName == '/login' && authProvider.isAuthenticated) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/student-selection');
                  }
                });
                return child ?? const StudentSelectionScreen();
              }

              if (routeName == '/home' && !authProvider.isAuthenticated) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                });
                return child ?? const LoginScreen();
              }

              if (routeName == '/student-selection' && !authProvider.isAuthenticated) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                });
                return child ?? const LoginScreen();
              }

              return child ?? const SizedBox();
            },
          );
        },
      ),
    );
  }
}
