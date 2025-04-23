// domain/repositories/transfer_repository.dart
import '../entities/transfer.dart';

abstract class TransferRepository {
  Future<void> sendMoney(Transfer transfer);
}
