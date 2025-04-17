import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:root_checker_plus/root_checker_plus.dart';

Future<void> collectDeviceInfo() async {
  final prefs = await SharedPreferences.getInstance();

  // 1. user_id
  const userId = "user_0001";
  await prefs.setString('user_id', userId);
  print("✅ user_id: $userId");

  // 2. device_id
  final deviceInfoPlugin = DeviceInfoPlugin();
  String? deviceId;
  if (Platform.isAndroid) {
    final androidInfo = await deviceInfoPlugin.androidInfo;
    deviceId = androidInfo.model;
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfoPlugin.iosInfo;
    deviceId = iosInfo.utsname.machine;
  }
  if (deviceId != null) {
    await prefs.setString('device_id', deviceId);
    print("✅ device_id: $deviceId");
  }

  // 3. app_version
  final packageInfo = await PackageInfo.fromPlatform();
  final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
  await prefs.setString('app_version', appVersion);
  print("✅ app_version: $appVersion");

  // 4. rooting / developer mode / jailbreak
  bool rootedCheck = false;
  bool devMode = false;
  bool jailbreak = false;

  try {
    if (Platform.isAndroid) {
      rootedCheck = (await RootCheckerPlus.isRootChecker()) ?? false;
      devMode = (await RootCheckerPlus.isDeveloperMode()) ?? false;
    } else if (Platform.isIOS) {
      jailbreak = (await RootCheckerPlus.isJailbreak()) ?? false;
    }
  } catch (e) {
    print("❌ Root/Jailbreak check failed: $e");
  }

  await prefs.setBool('rooting', Platform.isAndroid ? rootedCheck : jailbreak);
  await prefs.setBool('developer_mode', devMode);
  print("✅ rooting: ${Platform.isAndroid ? rootedCheck : jailbreak}");
  if (Platform.isAndroid) print("✅ developer_mode: $devMode");

  // 5. 위치 (위도, 경도)
  await getLatLngOnly();
}

Future<void> getLatLngOnly() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse) {
    try {
      final position = await Geolocator.getCurrentPosition();
      final lat = position.latitude;
      final lng = position.longitude;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('latitude', lat);
      await prefs.setDouble('longitude', lng);

      print("✅ 위도: $lat, 경도: $lng");
    } catch (e) {
      print("📛 위치 정보 가져오기 실패: $e");
    }
  } else {
    print("❗ 위치 권한이 없어서 위도/경도 가져오기 실패");
  }
}
