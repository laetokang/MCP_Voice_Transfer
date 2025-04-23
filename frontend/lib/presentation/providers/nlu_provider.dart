import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voicetransfer/presentation/viewmodels/nlu_viewmodel.dart';

final nluViewModelProvider = ChangeNotifierProvider<NluViewModel>((ref) {
  return NluViewModel();
});
