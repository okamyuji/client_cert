# クライアント証明書認証デモ

このプロジェクトは、Flutterアプリケーションでのクライアント証明書認証（双方向SSL/TLS）の実装例を示しています。

## 開発環境

- Flutter 3.27.4(channel stable)
- Dart SDK version: 3.6.2 (stable)
- OpenSSL 3.4.0 22 Oct 2024 (Library: OpenSSL 3.4.0 22 Oct 2024)
- macOS 15.3.1
- VScode 1.97.1

## テスト環境

- iOS Simulator iPhone 16 Pro / iOS 18.2

## 証明書の作成手順

- **gitでは管理していませんが、プロジェクト直下に`cert_files`ディレクトリを作成し、その中に証明書ファイルを配置してください。**
- **作成した証明書ファイルのうち、`ca.crt`と`client.p12`を`client_cert_app/assets`ディレクトリにコピーしてください。**

### 1. 認証局（CA）の作成

- 認証局（Certificate Authority / CA）は、デジタル証明書を発行する信頼できる第三者機関です。
    - 本来は正規の認証局が発行したCAがデバイスにインストール済ですが、ここでは検証用に開発向けの自己署名CAを作成します。
- このCAは、後続のサーバー証明書とクライアント証明書の両方に署名するために使用されます。

#### 秘密鍵の生成

```bash
# 秘密鍵の生成
openssl genrsa -out ca.key 2048
```

- オプションの説明
    - genrsa: RSA秘密鍵の生成を指定
    - -out ca.key: 生成された秘密鍵の出力先ファイル
    - 2048: 鍵の長さ（ビット）。2048ビットは現在のセキュリティ標準を満たす長さ

#### CA証明書の生成

```bash
openssl req -x509 -new -nodes -key ca.key -sha256 -days 1825 -out ca.crt \
    -subj "/C=JP/ST=Tokyo/L=Chiyoda-ku/O=Test Company/OU=Test Department/CN=testuser/emailAddress=test@example.com"
```

- オプションの説明
    - req: 証明書要求の処理を指定
    - -x509: 自己署名証明書の生成を指定
    - -new: 新規証明書要求の作成
    - -nodes: 秘密鍵を暗号化しない
    - -key ca.key: 使用する秘密鍵ファイル
    - -sha256: SHA-256ハッシュアルゴリズムを使用
    - -days 1825: 証明書の有効期間（5年）
    - -out ca.crt: 出力ファイル名
    - -subj: 証明書のサブジェクト情報
        - /C=JP: 国名（Country）
        - /ST=Tokyo: 都道府県（State）
        - /L=Chiyoda-ku: 市区町村（Locality）
        - /O=Test Company: 組織名（Organization）
        - /OU=Test Department: 部門名（Organizational Unit）
        - /CN=testuser: 通称名（Common Name）
        - /emailAddress=<test@example.com>: メールアドレス

### 2. サーバー証明書の作成

- サーバー証明書は、HTTPSサーバーの身元を証明し、クライアントとの安全な通信を確立するために使用されます。

#### サーバーの秘密鍵の生成

```bash
openssl genrsa -out server.key 2048
```

- オプションの説明
    - 上記CAの秘密鍵生成と同様です

#### 証明書署名要求（CSR）の生成

```bash
openssl req -new -key server.key -out server.csr \
    -subj "/C=JP/ST=Tokyo/L=Chiyoda-ku/O=Test Company/OU=Test Department/CN=testuser/emailAddress=test@example.com"
```

- オプションの説明
    - req: 証明書要求の処理
    - -new: 新規CSRの作成
    - -key server.key: 使用する秘密鍵
    - -out server.csr: CSRの出力ファイル
    - -subj: サブジェクト情報（CAと同様）

#### CAによる署名

```bash
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256
```

- オプションの説明
    - x509: X.509証明書の処理
    - -req: CSRの処理を指定
    - -in server.csr: 入力CSRファイル
    - -CA ca.crt: 署名に使用するCA証明書
    - -CAkey ca.key: CA秘密鍵
    - -CAcreateserial: シリアル番号ファイルの生成
    - -out server.crt: 出力証明書ファイル
    - -days 365: 有効期間（1年）
    - -sha256: SHA-256ハッシュアルゴリズムを使用

### 3. クライアント証明書の作成

- クライアント証明書は、クライアント（この場合はFlutterアプリ）の身元を証明するために使用され、サーバーとの相互認証（双方向SSL/TLS）を実現します。

```bash
# クライアント証明書の作成
openssl genrsa -out client.key 2048

# 証明書署名要求（CSR）の生成
openssl req -new -key client.key -out client.csr \
    -subj "/C=JP/ST=Tokyo/L=Chiyoda-ku/O=Test Company/OU=Test Department/CN=testuser/emailAddress=test@example.com" \
    -config <(cat /etc/ssl/openssl.cnf \
        <(printf "\n[usr_cert]\nextendedKeyUsage=clientAuth"))

# CAによる署名
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out client.crt -days 365 -sha256 \
    -extensions usr_cert

# PKCS#12形式への変換
openssl pkcs12 -export \
    -in client.crt \
    -inkey client.key \
    -out client.p12 \
    -certfile ca.crt \
    -name "client-cert" \
    -password pass:password
```

- PKCS#12形式への変換のオプションの説明
    - pkcs12: PKCS#12形式の処理
    - -export: PKCS#12ファイルの作成
    - -out client.p12: 出力ファイル
    - -inkey client.key: 秘密鍵ファイル
    - -in client.crt: 証明書ファイル
    - -certfile ca.crt: CA証明書ファイル
    - -password pass:password: PKCS#12ファイルのパスワード設定

## テストサーバーの起動

`cert_files`ディレクトリに移動して、以下のコマンドでOpenSSLのテストサーバーを起動します

```bash
openssl s_server -cert server.crt -key server.key -CAfile ca.crt -Verify 1 -WWW -port 3000
```

- オプションの説明
    - s_server: SSLサーバーの起動
    - -cert server.crt: サーバー証明書
    - -key server.key: サーバーの秘密鍵
    - -CAfile ca.crt: 信頼するCA証明書
    - -Verify 1: クライアント認証を要求（1は検証深度）
    - -WWW: 基本的なHTTPレスポンスの提供
    - -port 3000: リッスンポート

## Flutterアプリケーションの設定

### 1. プロジェクト構造

```shell
client_cert_app/
  ├── assets/
  │   ├── client.p12    # 生成したクライアント証明書をコピーして配置します
  │   └── ca.crt        # 生成したCA証明書をコピーして配置します
  └── pubspec.yaml      # アセットの設定など 
```

### 2. pubspec.yamlの設定

```yaml
flutter:
  assets:
    - assets/client.p12
    - assets/ca.crt
```

### 3. クライアント証明書認証の実装

```dart
Future<void> _performClientCertificateAuthentication() async {
  try {
    // 1. 証明書ファイルの読み込み
    final caBytes = await rootBundle.load('assets/ca.crt');
    final p12Data = await rootBundle.load('assets/client.p12');
    
    final caList = caBytes.buffer.asUint8List();
    final certificateBytes = p12Data.buffer.asUint8List();

    // 2. PKCS#12のパスワード設定
    String p12Password = 'password';  // .p12作成時のパスワード

    // 3. SecurityContextの設定
    SecurityContext clientContext = SecurityContext(withTrustedRoots: true);
    clientContext.setTrustedCertificatesBytes(caList);
    clientContext.useCertificateChainBytes(certificateBytes, password: p12Password);
    clientContext.usePrivateKeyBytes(certificateBytes, password: p12Password);

    // 4. HTTPクライアントの作成
    HttpClient client = HttpClient(context: clientContext);
    client.badCertificateCallback = (cert, host, port) {
      logger.w('証明書警告 - Subject: ${cert.subject}');
      logger.w('証明書警告 - Issuer: ${cert.issuer}');
      logger.w('証明書警告 - Host: $host, Port: $port');
      return true;  // 開発環境のみtrue
    };

    // 5. リクエストの送信
    final url = Uri.https('localhost:3000', '/');
    final request = await client.getUrl(url);
    request.headers.add(HttpHeaders.contentTypeHeader, 'application/json');
    
    final response = await request.close().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('リクエストがタイムアウトしました'),
    );

    // 6. レスポンスの処理
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

    client.close();
  } catch (e, stack) {
    logger.e('エラー発生: $e', error: e, stackTrace: stack);
    setState(() {
      _isLoading = false;
      _authStatus = 'エラー: $e';
    });
  }
}
```

## 注意事項

1. パスワードの管理
   - PKCS#12ファイルのパスワードは、実際にはセキュアな方法で管理してください
   - 実運用では、環境変数や設定ファイルから読み込むことを推奨します

2. 証明書の有効期限
   - 証明書の有効期限を確認し、適切なタイミングで更新してください
   - 実運用では、証明書の自動更新の仕組みを検討してください

3. セキュリティ考慮事項
   - クライアント証明書（client.p12）は、セキュアな方法で配布してください
   - 開発環境でのbadCertificateCallbackの使用は、本番環境では避けてください

4. エラーハンドリング
   - 証明書の読み込みエラー
   - ネットワークエラー
   - 認証エラー
   など、適切なエラーハンドリングを実装してください

## トラブルシューティング

1. 証明書の内容確認

    ```bash
    # 証明書の内容確認（有効期限、発行者、サブジェクト、拡張設定などを確認）
    openssl x509 -in ca.crt -text -noout    # CA証明書の内容
    openssl x509 -in client.crt -text -noout # クライアント証明書の内容
    openssl x509 -in server.crt -text -noout # サーバー証明書の内容
    ```

    - 確認ポイント
        - 有効期限（Validity）が切れていないこと
        - Subject（サブジェクト）が正しく設定されていること
        - X509v3 Extended Key Usageに適切な用途が設定されていること
            - サーバー証明書: TLS Web Server Authentication
            - クライアント証明書: TLS Web Client Authentication
        - Basic ConstraintsでCA証明書のみ CA:TRUE となっていること

2. PKCS#12ファイルの確認

    ```bash
    # PKCS#12ファイルの内容確認
    openssl pkcs12 -info -in client.p12 -noout -password pass:password
    # 詳細な内容確認（証明書チェーンも表示）
    openssl pkcs12 -info -in client.p12 -password pass:password
    ```

    - 確認ポイント
        - 秘密鍵（PRIVATE KEY）が含まれていること
        - クライアント証明書が含まれていること
        - 必要に応じてCA証明書も含まれていること
        - エラーが表示されないこと（MAC検証に成功すること）

3. 証明書チェーンの検証

    ```bash
    # クライアント証明書の検証（CA証明書で署名されていることを確認）
    openssl verify -CAfile ca.crt client.crt
    # サーバー証明書の検証（CA証明書で署名されていることを確認）
    openssl verify -CAfile ca.crt server.crt
    # より詳細な検証（証明書チェーンの完全性確認）
    openssl verify -verbose -CAfile ca.crt -purpose sslclient client.crt
    openssl verify -verbose -CAfile ca.crt -purpose sslserver server.crt
    ```

    - 正常な出力
        - client.crt: OK または server.crt: OK が表示される
        - エラーメッセージが表示されない

4. 診断コマンド

    ```bash
    # 証明書の指紋（フィンガープリント）確認
    openssl x509 -in client.crt -noout -fingerprint
    # 証明書の公開鍵情報確認
    openssl x509 -in client.crt -noout -pubkey
    # 証明書の署名アルゴリズム確認
    openssl x509 -in client.crt -noout -text | grep "Signature Algorithm"
    ```

    - エラー発生時の対処
        - 有効期限切れ > 証明書を再発行
        - 署名検証エラー > CA証明書が正しいか確認
        - 用途の不一致 > Extended Key Usage を正しく設定して再発行
        - MAC検証エラー > PKCS#12のパスワードが正しいか確認
        - チェーン検証エラー > 中間証明書が必要か確認
