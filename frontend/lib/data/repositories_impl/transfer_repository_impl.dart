import 'package:http/http.dart' as http;
import 'package:voicetransfer/data/models/transfer_request_model.dart';
import 'package:voicetransfer/domain/entities/transfer.dart';
import 'package:voicetransfer/domain/repositories/transfer_interface.dart';

class TransferRepositoryImpl implements TransferRepository {
  @override
  Future<void> sendMoney(Transfer transfer) async {
    final request = TransferRequestModel(
      recipient: transfer.recipient,
      amount: transfer.amount,
    );
    // 실제 API 호출 또는 로컬 DB 호출
    await http.post(Uri.parse(".../send"), body: request.toJson());
  }
}
