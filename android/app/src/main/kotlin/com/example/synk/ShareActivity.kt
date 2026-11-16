package com.example.synk

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import java.io.File

// Pictures and links shared to Synk from the phone's share menu, waiting for
// the app to ask which chats they go to (lib/utils/shared_to_synk.dart).
object SharedItems {
    private val photos = mutableListOf<String>()
    private val texts = mutableListOf<String>()

    // Set by MainActivity while the app is open, so it asks straight away.
    var onAdded: (() -> Unit)? = null

    @Synchronized
    fun addPhoto(path: String) {
        photos.add(path)
    }

    @Synchronized
    fun addText(text: String) {
        texts.add(text)
    }

    @Synchronized
    fun take(): Map<String, List<String>> {
        val taken = mapOf("photos" to photos.toList(), "texts" to texts.toList())
        photos.clear()
        texts.clear()
        return taken
    }
}

// Shows as Synk in the share menu. Keeps what was shared, then opens Synk the
// same way the app icon does.
class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        keep(intent)
        SharedItems.onAdded?.invoke()
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
            )
            startActivity(it)
        }
        finish()
    }

    private fun keep(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        val type = intent.type ?: return
        if (type.startsWith("image/")) {
            // A caption that comes with a picture is left out.
            keepPhoto(intent, type)
        } else if (type == "text/plain") {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
            if (!text.isNullOrEmpty()) SharedItems.addText(text)
        }
    }

    private fun keepPhoto(intent: Intent, type: String) {
        val uri = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        } ?: return
        val ending = when (type) {
            "image/png" -> "png"
            "image/webp" -> "webp"
            "image/heic" -> "heic"
            else -> "jpg"
        }
        try {
            val dir = File(cacheDir, "shared").apply { mkdirs() }
            val file = File(dir, "${System.currentTimeMillis()}.$ending")
            val input = contentResolver.openInputStream(uri) ?: return
            input.use { source -> file.outputStream().use { source.copyTo(it) } }
            SharedItems.addPhoto(file.path)
        } catch (e: Exception) {
        }
    }
}
