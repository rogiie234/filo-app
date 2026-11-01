package com.filo.filo

// Only fixed failure markers and exception class names may cross the debug bridge.
internal fun pushFailureSummary(error: Throwable?): String {
    val markers = listOf("SERVICE_NOT_AVAILABLE", "AUTHENTICATION_FAILED", "TOO_MANY_REGISTRATIONS",
        "FIS_AUTH_ERROR", "BAD_CONFIG", "API_KEY_SERVICE_BLOCKED", "PERMISSION_DENIED",
        "INVALID_ARGUMENT", "INTERNAL_SERVER_ERROR", "NETWORK_ERROR")
    val types = mutableListOf<String>()
    val codes = linkedSetOf<String>()
    var cause = error
    repeat(8) {
        val current = cause ?: return@repeat
        types.add(current.javaClass.simpleName)
        val message = current.message.orEmpty()
        markers.filterTo(codes) { message.contains(it) }
        cause = current.cause
    }
    return "types=" + types.joinToString(" > ") + "; codes=" + codes.joinToString(",").ifEmpty { "unspecified" }
}
