import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/datasources/local_database.dart';
import 'data/repositories/product_repository.dart';
import 'domain/usecases/scan_receipt.dart';
import 'services/ocr_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await LocalDatabase.initialize();

  final ProductRepository productRepository = ProductRepository();
  final ScanReceiptUseCase scanReceiptUseCase = ScanReceiptUseCase(productRepository);
  final OcrService ocrService = OcrService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ProductRepository>.value(value: productRepository),
        Provider<ScanReceiptUseCase>.value(value: scanReceiptUseCase),
        Provider<OcrService>.value(value: ocrService),
      ],
      child: const DietChekApp(),
    ),
  );
}