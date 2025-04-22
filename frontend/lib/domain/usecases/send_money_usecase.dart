// domain/usecases/send_money_usecase.dart
import '../entities/transfer.dart';
import '../repositories/transfer_repository.dart';

class SendMoneyUseCase {
  final TransferRepository repository;

  SendMoneyUseCase(this.repository);

  Future<void> call(Transfer transfer) async {
    return repository.sendMoney(transfer);
  }
}
