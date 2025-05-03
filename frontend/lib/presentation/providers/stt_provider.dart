import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voicetransfer/presentation/viewmodels/stt_viewmodel.dart';
import 'package:voicetransfer/modules/1stt/stt_usecases.dart';
import 'package:voicetransfer/modules/1stt/stt_service_whisper.dart';
import 'package:voicetransfer/modules/1stt/stt_service.dart';

final sttViewModelProvider = ChangeNotifierProvider<SttViewModel>((ref) {
  //(1)Google API : SttService (2)Whisper API : SttServiceWhisper로 고치기
  final useCase = ListenAndTranscribe(SttServiceWhisper());
  return SttViewModel(useCase);
});
