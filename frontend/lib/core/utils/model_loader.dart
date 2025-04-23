import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

Future<String> prepareOnnxModel(String fileName) async {
  final appDocDir = await getApplicationDocumentsDirectory();
  final targetPath = '${appDocDir.path}/$fileName';
  final targetFile = File(targetPath);

  if (!await targetFile.exists()) {
    // ✅ 프로젝트 루트 경로 기준 상대경로 (개발 환경 전용)
    final devModelPath = File(
      '/Users/l-20190029/Project/MCP_Voice_Transfer/frontend/onnx_models/$fileName',
    );

    if (!await devModelPath.exists()) {
      throw Exception('❌ 모델 파일이 $devModelPath 경로에 존재하지 않습니다.');
    }

    final bytes = await devModelPath.readAsBytes();
    await targetFile.writeAsBytes(bytes);
    print("✅ 모델 복사 완료: $targetPath");
  } else {
    print("✅ 모델 이미 존재: $targetPath");
  }

  return targetPath;
}
