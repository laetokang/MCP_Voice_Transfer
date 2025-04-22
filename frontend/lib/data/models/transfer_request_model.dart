// data/models/transfer_request_model.dart
import '../../../domain/entities/transfer.dart';

class TransferRequestModel extends Transfer {
  TransferRequestModel({required String recipient, required int amount})
    : super(recipient: recipient, amount: amount);

  Map<String, dynamic> toJson() => {'recipient': recipient, 'amount': amount};
}
