// presentation/pages/transfer_page.dart
import 'package:flutter/material.dart';
import 'package:voicetransfer/data/repositories_impl/transfer_repository_impl.dart';
import '../viewmodels/transfer_viewmodel.dart';
import '../../domain/usecases/send_money_usecase.dart';

class TransferPage extends StatelessWidget {
  final viewModel = TransferViewModel(
    useCase: SendMoneyUseCase(TransferRepositoryImpl()),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("송금하기")),
      body: Column(
        children: [
          TextField(onChanged: viewModel.setRecipient),
          TextField(
            onChanged: (value) => viewModel.setAmount(int.parse(value)),
          ),
          ElevatedButton(onPressed: viewModel.sendMoney, child: Text("보내기")),
        ],
      ),
    );
  }
}
