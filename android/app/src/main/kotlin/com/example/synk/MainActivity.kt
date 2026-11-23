package com.example.synk

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // The "add to calendar" request waiting for the calendar app to close.
    private var calendarResult: MethodChannel.Result? = null
    private var calendarEvent: Map<*, *>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Pictures and links shared to Synk (ShareActivity.kt).
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "synk/shared")
        SharedItems.onAdded = { channel.invokeMethod("added", null) }
        channel.setMethodCallHandler { call, result ->
            if (call.method == "take") {
                result.success(SharedItems.take())
            } else {
                result.notImplemented()
            }
        }

        // Adds an activity to the phone's calendar (lib/utils/add_to_calendar.dart),
        // then checks the calendar to tell whether the user saved it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "synk/calendar")
            .setMethodCallHandler { call, result ->
                val event = call.arguments as? Map<*, *>
                if (call.method != "add" || event == null) {
                    result.notImplemented()
                } else if (calendarResult != null) {
                    result.success("busy")
                } else {
                    calendarResult = result
                    calendarEvent = event
                    if (canReadCalendar()) {
                        openCalendar()
                    } else {
                        // Asked once; the calendar opens either way.
                        requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), ASK_CALENDAR)
                    }
                }
            }
    }

    private fun canReadCalendar() =
        checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED

    private fun openCalendar() {
        val event = calendarEvent ?: return
        val intent = Intent(Intent.ACTION_INSERT)
            .setData(CalendarContract.Events.CONTENT_URI)
            .putExtra(CalendarContract.Events.TITLE, event["title"] as? String)
            .putExtra(CalendarContract.Events.DESCRIPTION, event["description"] as? String)
            .putExtra(CalendarContract.Events.EVENT_LOCATION, event["location"] as? String)
            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, (event["start"] as Number).toLong())
            .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, (event["end"] as Number).toLong())
        try {
            startActivityForResult(intent, OPEN_CALENDAR)
        } catch (_: ActivityNotFoundException) {
            finishCalendar("unavailable")
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == ASK_CALENDAR) openCalendar()
    }

    @Deprecated("Deprecated in Android, still how FlutterActivity hears back")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != OPEN_CALENDAR) return
        if (!canReadCalendar()) {
            // Without access there's no way to tell whether it was saved.
            finishCalendar("opened")
            return
        }
        // Give the calendar a moment to finish writing the event.
        Handler(Looper.getMainLooper()).postDelayed({
            finishCalendar(if (eventIsSaved()) "saved" else "cancelled")
        }, 600)
    }

    // An event with the same title starting within a minute of the activity.
    private fun eventIsSaved(): Boolean {
        val event = calendarEvent ?: return false
        val title = event["title"] as? String ?: return false
        val start = (event["start"] as Number).toLong()
        return try {
            contentResolver.query(
                CalendarContract.Events.CONTENT_URI,
                arrayOf(CalendarContract.Events._ID),
                "${CalendarContract.Events.TITLE} = ? AND " +
                    "${CalendarContract.Events.DTSTART} BETWEEN ? AND ? AND " +
                    "${CalendarContract.Events.DELETED} = 0",
                arrayOf(title, (start - 60_000).toString(), (start + 60_000).toString()),
                null,
            )?.use { it.count > 0 } ?: false
        } catch (_: SecurityException) {
            false
        }
    }

    private fun finishCalendar(outcome: String) {
        calendarResult?.success(outcome)
        calendarResult = null
        calendarEvent = null
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        SharedItems.onAdded = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        private const val ASK_CALENDAR = 7301
        private const val OPEN_CALENDAR = 7302
    }
}
