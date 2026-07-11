# HTTPS 配置指南

## 问题描述
开启HTTPS后，应用发起请求失败。这通常是由以下原因造成的：

1. **Android网络安全配置**：默认情况下，Android 9+限制了对未安装CA的信任
2. **iOS ATS配置**：iOS默认启用App Transport Security，要求使用HTTPS
3. **证书问题**：服务器证书可能无效、过期或自签名

## 解决方案

### 1. Android 配置

已更新 `android/app/src/main/res/xml/network_security_config.xml`：

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- 允许 HTTP 明文请求（开发环境） -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">39.108.137.45</domain>
        <domain includeSubdomains="true">10.2.3.6</domain>
        <domain includeSubdomains="true">192.168.2.222</domain>
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">10.0.2.2</domain>
    </domain-config>

    <!-- HTTPS 配置 -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>

    <!-- 如果使用自签名证书，取消注释以下配置 -->
    <!--
    <domain-config>
        <domain includeSubdomains="true">hupokeji.top</domain>
        <trust-anchors>
            <certificates src="@raw/certificate" />
        </trust-anchors>
    </domain-config>
    -->
</network-security-config>
```

### 2. iOS 配置

已更新 `ios/Runner/Info.plist`，添加ATS配置：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>hupokeji.top</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSThirdPartyExceptionRequiresForwardSecrecy</key>
            <true/>
            <key>NSRequiresCertificateTransparency</key>
            <false/>
        </dict>
    </dict>
</dict>
```

### 3. Dio 配置

已更新 `lib/core/network/api_client.dart`，添加证书验证配置：

```dart
/// 配置证书验证
void _configureCertificateVerification() {
  // 注意：仅在开发环境中使用，生产环境应使用正式证书
  if (kDebugMode) {
    // 开发环境：信任所有证书（仅用于调试）
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      // 信任所有证书（仅用于开发调试）
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        print('⚠️ 警告：信任了自签名证书 - $host:$port');
        return true;
      };
      return client;
    };
  }
}
```

## 自签名证书配置

如果服务器使用自签名证书，请按照以下步骤操作：

### 步骤1：获取证书文件
从服务器获取 `.cer` 或 `.pem` 格式的证书文件。

### 步骤2：放置证书文件
将证书文件放入 `android/app/src/main/res/raw/` 目录。

### 步骤3：更新Android配置
取消 `network_security_config.xml` 中自签名证书配置的注释。

### 步骤4：iOS证书配置
将证书文件添加到Xcode项目的"Resources"中。

## 测试HTTPS连接

### 1. 检查服务器证书
使用以下命令检查服务器证书：
```bash
openssl s_client -connect hupokeji.top:443 -showcerts
```

### 2. 检查应用日志
运行应用并查看控制台输出，寻找证书相关错误。

### 3. 使用Postman测试
使用Postman测试API端点，确保服务器正常响应。

## 常见问题

### 1. 证书过期
- 检查服务器证书有效期
- 更新证书或配置自动续期

### 2. 证书链不完整
- 确保服务器配置了完整的证书链
- 包含中间证书

### 3. 域名不匹配
- 确保证书中的域名与请求的域名匹配
- 如果是通配符证书，确保格式正确

### 4. Android 9+限制
- Android 9+默认不信任用户安装的CA
- 需要在网络安全配置中明确指定

## 生产环境注意事项

⚠️ **重要**：在生产环境中，不要使用 `badCertificateCallback = (cert, host, port) => true`，这会禁用证书验证，存在安全风险。

生产环境应该：
1. 使用有效的SSL证书（如Let's Encrypt）
2. 确保证书链完整
3. 定期更新证书
4. 不要禁用证书验证

## 调试技巧

### 1. 启用详细日志
在 `api_client.dart` 中，确保 `LoggingInterceptor` 在调试模式下启用。

### 2. 检查网络请求
使用Chrome DevTools或Charles Proxy检查网络请求。

### 3. 查看错误信息
捕获 `DioException` 并查看详细错误信息：
```dart
try {
  final response = await dio.get('/api/endpoint');
} on DioException catch (e) {
  print('请求失败: ${e.message}');
  print('响应: ${e.response?.data}');
}
```