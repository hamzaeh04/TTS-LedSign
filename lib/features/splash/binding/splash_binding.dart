import 'package:get/get.dart';
import '../controller/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // lazyPut ensures the controller is initialized ONLY when the route is called.
    // This is the key to 'Maximum Performance' in GetX.
    Get.put(SplashController());
  }
}
