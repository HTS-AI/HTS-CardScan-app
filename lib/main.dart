import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android 15 and below use the documents picker unless this is set.
  // Android 16+ always uses the system photo picker.
  final imagePickerImplementation = ImagePickerPlatform.instance;
  if (imagePickerImplementation is ImagePickerAndroid) {
    imagePickerImplementation.useAndroidPhotoPicker = true;
  }
  await AppConfig.load();
  final packageInfo = await PackageInfo.fromPlatform();
  logApi('Package: ${packageInfo.packageName}');
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await AuthService.instance.load();
  runApp(const CardScanApp());
}

class CardScanApp extends StatelessWidget {
  const CardScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        return MaterialApp(
          key: ValueKey(AuthService.instance.isSignedIn),
          title: 'HTS CardScan',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: AuthService.instance.isSignedIn ? const HomeScreen() : const LoginScreen(),
        );
      },
    );
  }
}
