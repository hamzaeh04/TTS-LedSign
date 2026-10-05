
import 'package:get/get.dart';
import 'package:iphone_bluetooth/features/ble/views/ble_screen.dart';
import 'package:iphone_bluetooth/features/splash/binding/splash_binding.dart';
import 'package:iphone_bluetooth/features/splash/views/splash_screen.dart';

class AppRoutes {
  static List<GetPage<dynamic>> routes = [
    GetPage(name: '/', page: () => SplashScreen(),binding: SplashBinding()),
    GetPage(name: '/connection', page: () => BleScreen()),

  ];
}
