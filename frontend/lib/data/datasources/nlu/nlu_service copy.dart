// import 'dart:typed_data';
// import 'package:flutter/services.dart';
// import 'package:onnxruntime/onnxruntime.dart';
// import 'package:voicetransfer/core/utils/model_loader.dart';
// import 'dart:io';
// import 'package:llama_cpp/llama_cpp.dart';

// class NluService {
//   final path = 'src/qwen2.5-0.5b-instruct-q2_k.gguf';
//   static late OrtSession _session;

//   /// 모델 초기화
//   static Future<void> initialize() async {
//     try {
//       print("🟡 [NLU Init] ONNX 환경 초기화...");
//       OrtEnv.instance.init();

//       final modelPath = await prepareOnnxModel('model.onnx');
//       final bytes = await File(modelPath).readAsBytes();

//       final sessionOptions = OrtSessionOptions();
//       sessionOptions.setIntraOpNumThreads(1);

//       _session = OrtSession.fromBuffer(bytes, sessionOptions);

//       print("🟢 [NLU Init] 모델 세션 로딩 성공!");
//     } catch (e, stack) {
//       print("❌ [NLU Init] 모델 초기화 실패: $e");
//       print(stack);
//       rethrow;
//     }
//   }

//   /// 텍스트 생성 모델: 입력 → 출력 텍스트 생성
//   static Future<String> generateText(String input) async {
//     // 🧩 1. 입력을 토큰 ID로 변환 (임시: 문자열 길이로 대체 중 → 실제로는 tokenizer 필요)
//     final inputTensor = OrtValueTensor.createTensorWithDataList(
//       [input.length], // 여기를 tokenizer 처리된 input_ids로 교체해야 정확함
//       [1],
//     );

//     final inputs = {'input': inputTensor};

//     // 🧠 2. 모델 추론
//     final runOptions = OrtRunOptions();
//     final outputs = await _session.runAsync(runOptions, inputs);

//     // 📤 3. 출력 텐서 → 텍스트로 디코딩
//     final output = outputs?[0]?.value;

//     // ✅ 예시: 모델 출력값이 문자열이라 가정
//     final generatedText = output?.toString() ?? '[No output]';

//     // 🧹 리소스 정리
//     inputTensor.release();
//     runOptions.release();
//     outputs?.forEach((e) => e?.release());

//     return generatedText;
//   }
// }
