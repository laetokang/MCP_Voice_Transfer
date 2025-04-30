import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class QwenPromptFormat extends PromptFormat {
  QwenPromptFormat()
    : super(
        PromptFormatType.chatml,
        inputSequence: "<|im_start|>user\n",
        outputSequence: "<|im_end|>\n<|im_start|>assistant\n",
        systemSequence: "<|im_start|>system\n",
        stopSequence: "<|im_end|>",
      );

  @override
  String formatPrompt(String prompt) {
    return """
<|im_start|>system
You are a helpful assistant.
<|im_end|>
<|im_start|>user
$prompt
<|im_end|>
<|im_start|>assistant
""";
  }
}

class NluService {
  late final LlamaParent _llamaParent;
  late final String _localModelPath;
  final StringBuffer _responseBuffer = StringBuffer();
  Stream<String> get stream => _llamaParent.stream;
  Stream<void> get completions => _llamaParent.completions;
  NluService();

  Future<void> _prepareModel() async {
    final byteData = await rootBundle.load(
      'assets/qwen2.5-0.5b-instruct-q2_k.gguf',
    );
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/qwen2.5-0.5b-instruct-q2_k.gguf');

    if (!(await file.exists())) {
      print('📦 모델 파일 복사 중...');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      print('✅ 모델 파일 복사 완료: ${file.path}');
    } else {
      print('⚡ 이미 모델 파일 존재: ${file.path}');
    }

    _localModelPath = file.path;
  }

  Future<void> initialize() async {
    await _prepareModel();

    final loadCommand = LlamaLoad(
      path: _localModelPath,
      modelParams: ModelParams(),
      contextParams: ContextParams(),
      samplingParams: SamplerParams(), // 출력 토큰 제한 추가
      format: QwenPromptFormat(),
    );

    _llamaParent = LlamaParent(loadCommand);
    await _llamaParent.init();
    print("🟢 [NLU Init] 모델 세션 로딩 성공!");

    _llamaParent.stream.listen((response) {
      if (response.trim().isEmpty) {
        print('🧠 (경고) 빈 응답 수신!');
      } else {
        _responseBuffer.write(response); // 누적
        print('🧠 모델 응답 스트림 수신: "$response"');
      }
    });

    _llamaParent.completions.listen((event) {
      print('📥 Completion 완료됨: $event');
      print('💬 전체 응답 결과: ${_responseBuffer.toString()}');
      _responseBuffer.clear(); // 다음 응답 위해 초기화
    });
  }

  void ask(String inputText) {
    final prompt = QwenPromptFormat().formatPrompt(inputText);
    print('📨 실제 전송될 Prompt: $prompt');
    _llamaParent.sendPrompt(prompt);
  }
}
