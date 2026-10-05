import 'package:get/get.dart';


class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));
    Get.offAllNamed("/connection");
  }
}
