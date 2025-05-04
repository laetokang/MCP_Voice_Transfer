import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voicetransfer/presentation/viewmodels/nlu_viewmodel.dart';
import 'package:voicetransfer/modules/2nlu/nlu_service.dart';

// NluService Provider
final nluServiceProvider = Provider<NluService>((ref) {
  final service = NluService();
  service.initialize(); // 초기화까지 여기서 처리
  return service;
});

// NluViewModel Provider
final nluViewModelProvider = ChangeNotifierProvider<NluViewModel>((ref) {
  final nluService = ref.read(nluServiceProvider);
  return NluViewModel(nluService);
});
