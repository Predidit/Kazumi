package com.example.kazumi

internal object VideoGpu {
    private val available by lazy {
        try {
            System.loadLibrary("kazumi_gpu")
            true
        } catch (_: UnsatisfiedLinkError) {
            false
        }
    }

    private external fun enumerateVulkan(): Array<Array<String>>

    fun adapters(): List<Map<String, Any>> {
        if (!available) return emptyList()
        return enumerateVulkan().mapNotNull { row ->
            val vendor = row.getOrNull(2)?.toLongOrNull() ?: return@mapNotNull null
            mapOf("id" to row[0], "name" to row[1], "vendorId" to vendor, "apiVersion" to row[3])
        }
    }
}
