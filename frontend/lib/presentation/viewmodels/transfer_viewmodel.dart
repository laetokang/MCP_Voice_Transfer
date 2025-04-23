import '../../../domain/usecases/send_money_usecase.dart';
import '../../../domain/entities/transfer.dart';

class TransferViewModel {
  String _recipient = '';
  int _amount = 0;

  final SendMoneyUseCase useCase;

  TransferViewModel({required this.useCase});

  void setRecipient(String r) => _recipient = r;
  void setAmount(int a) => _amount = a;

  Future<void> sendMoney() async {
    final transfer = Transfer(recipient: _recipient, amount: _amount);
    await useCase(transfer);
  }
}
