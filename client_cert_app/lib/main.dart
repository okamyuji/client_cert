import 'dart:async' show TimeoutException;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';

final logger = Logger();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Client Certificate Auth Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Client Certificate Auth Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _authStatus = '認証実行中...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _performClientCertificateAuthentication();
  }

  Future<void> _performClientCertificateAuthentication() async {
    try {
      // 1. 自己証明書なのでCAファイルを信頼し、クライアント証明書を登録
      final caBytes = await rootBundle.load('assets/ca.crt');
      final p12Data = await rootBundle.load('assets/client.p12');

      final caList = caBytes.buffer.asUint8List();
      final certificateBytes = p12Data.buffer.asUint8List();

      // 2. クライアント証明書のパスワード
      String p12Password = 'password'; // .p12生成時に設定したパスワード

      // 3. SecurityContextを作成し、CA証明書を信頼し、クライアント証明書を登録
      SecurityContext clientContext = SecurityContext(withTrustedRoots: true);

      // CA証明書の設定
      clientContext.setTrustedCertificatesBytes(caList);

      // PKCS#12を設定
      clientContext.useCertificateChainBytes(certificateBytes,
          password: p12Password);
      clientContext.usePrivateKeyBytes(certificateBytes, password: p12Password);

      logger.i('SecurityContext設定完了');

      // 4. HTTPクライアント作成
      HttpClient client;
      try {
        client = HttpClient(context: clientContext);
        client.badCertificateCallback = (cert, host, port) {
          logger.w('証明書警告 - Subject: ${cert.subject}');
          logger.w('証明書警告 - Issuer: ${cert.issuer}');
          logger.w('証明書警告 - Host: $host, Port: $port');
          return true; // 自己証明書なので開発環境のみtrueを返す
        };
        logger.i('HTTPクライアント作成成功');
      } catch (e) {
        throw Exception('HTTPクライアント作成失敗: $e');
      }

      // 5. リクエスト作成
      try {
        Uri url = Uri.https('127.0.0.1:3000', '/');
        logger.i('接続先URL: $url');

        final request = await client.getUrl(url);
        request.headers.add(HttpHeaders.contentTypeHeader, 'application/json');

        final response = await request.close().timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('リクエストがタイムアウトしました'),
            );

        // 6. レスポンスを処理
        if (response.statusCode == HttpStatus.ok) {
          setState(() {
            _isLoading = false;
            _authStatus = '認証成功 (${response.statusCode})';
          });
        } else {
          setState(() {
            _isLoading = false;
            _authStatus = '認証失敗 (${response.statusCode})';
          });
        }
      } catch (e) {
        throw Exception('リクエスト処理中のエラー: $e');
      } finally {
        client.close();
      }
    } catch (e, stack) {
      logger.e('エラー発生: $e', error: e, stackTrace: stack);
      setState(() {
        _isLoading = false;
        _authStatus = 'エラー: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _authStatus,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
