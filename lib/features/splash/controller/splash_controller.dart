import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';


class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));
    Get.offAllNamed("/connection");

    // The splash only runs on a cold start (not when resuming from the
    // background), so showing the warning here limits it to fresh launches.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDrivingWarning());
  }

  void _showDrivingWarning() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.only(left: 1.w, right: 1.w, top: 0.5.h, bottom: 5.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  iconSize: 20.sp,
                  tooltip: 'Close',
                  icon: const Icon(Icons.cancel),
                  onPressed: () => Get.back(),
                ),
              ),
              Icon(Icons.warning_amber_rounded, size: 9.w, color: Colors.orange),
              SizedBox(height: 1.h),
              Padding(
                padding: EdgeInsets.only(right: 0),
                child: Text(
                  'Do not use while driving',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18.5.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
