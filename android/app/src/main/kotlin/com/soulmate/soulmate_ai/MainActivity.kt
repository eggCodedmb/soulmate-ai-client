package com.soulmate.soulmate_ai

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // 通过反射设置支付宝 SDK 为沙箱环境，避免编译期由于包隔离导致的类路径缺失错误
        try {
            val envUtilsClass = Class.forName("com.alipay.sdk.app.EnvUtils")
            val envEnumClass = Class.forName("com.alipay.sdk.app.EnvUtils\$EnvEnum")
            val sandboxEnum = envEnumClass.getField("SANDBOX").get(null)
            val setEnvMethod = envUtilsClass.getMethod("setEnv", envEnumClass)
            setEnvMethod.invoke(null, sandboxEnum)
            android.util.Log.d("AlipaySandbox", "Successfully set Alipay SDK to SANDBOX mode via reflection")
        } catch (e: Exception) {
            android.util.Log.e("AlipaySandbox", "Failed to set Alipay SDK to SANDBOX mode: " + e.message)
        }
        
        super.onCreate(savedInstanceState)
    }
}
