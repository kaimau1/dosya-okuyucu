// **Flutter kanal taslakları — YALNIZ yerel tür denetimi için** (APK'ya girmez).
// `ci/NearbyBle.kt` gerçek Android jar'ına karşı derlenirken Flutter gömme
// sınıflarının yerine geçer; yalnız kullanılan imzalar var.
package io.flutter.plugin.common

class MethodCall(val method: String, val arguments: Any?) {
    @Suppress("UNCHECKED_CAST")
    fun <T> argument(key: String): T? = (arguments as? Map<String, Any?>)?.get(key) as T?
}

class MethodChannel(val name: String) {
    interface Result {
        fun success(result: Any?)
        fun error(errorCode: String, errorMessage: String?, errorDetails: Any?)
        fun notImplemented()
    }

    interface MethodCallHandler {
        fun onMethodCall(call: MethodCall, result: Result)
    }

    fun setMethodCallHandler(handler: MethodCallHandler?) {}
    fun invokeMethod(method: String, arguments: Any?) {}
}
