package com.meghpy.pdf_lab_pro

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "pdf_lab_pro/open_file"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        // Handle the intent that launched the app
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // update Activity.intent
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        if (Intent.ACTION_VIEW == intent.action) {
            val uri: Uri? = intent.data
            if (uri != null) {
                // Copy the PDF into app's private storage and get a real file path
                val path = copyUriToInternalFile(uri)
                if (path != null) {
                    methodChannel?.invokeMethod("openPdf", path)
                }
            }
        }
    }

    private fun copyUriToInternalFile(uri: Uri): String? {
        return try {
            val contentResolver = applicationContext.contentResolver

            val fileName = uri.lastPathSegment?.substringAfterLast('/') ?: "document.pdf"
            val dir = applicationContext.getExternalFilesDir(null) ?: applicationContext.filesDir
            val outFile = File(dir, fileName)

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output ->
                    val buffer = ByteArray(8 * 1024)
                    var len: Int
                    while (input.read(buffer).also { len = it } != -1) {
                        output.write(buffer, 0, len)
                    }
                }
            }
            outFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
