package com.example.flute_practice

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val metronomeChannelName = "flute_practice/metronome"
    private val documentsChannelName = "flute_practice/documents"
    private val pitchTraceChannelName = "flute_practice/pitch_trace"
    private val pitchTraceEventChannelName = "flute_practice/pitch_trace_events"
    private val pickDocumentRequestCode = 4701
    private val pickImageRequestCode = 4702
    private val pitchTracePermissionRequestCode = 4801
    private var toneGenerator: ToneGenerator? = null
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingPitchTraceStartResult: MethodChannel.Result? = null
    private var pendingPitchTraceMinFrequency = 80.0
    private var pendingPitchTraceMaxFrequency = 2200.0
    private var pendingPitchTraceWindowSize = 2048
    private var pendingPitchTraceOverlapRatio = 0.5
    private var pitchTraceEventSink: EventChannel.EventSink? = null
    private var pitchTracker: PitchTracker? = null
    private var mediaPlayer: MediaPlayer? = null
    private var pitchTraceChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            metronomeChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "tick" -> {
                    val role = call.argument<String>("role") ?: "upbeat"
                    val soundStyle = call.argument<String>("soundStyle") ?: "classic"
                    val vibrate = call.argument<Boolean>("vibrate") ?: false
                    try {
                        playMetronomeTick(role, soundStyle, vibrate)
                        result.success(null)
                    } catch (error: RuntimeException) {
                        result.error(
                            "METRONOME_SOUND_ERROR",
                            error.message,
                            null
                        )
                    }
                }
                "click" -> {
                    val accent = call.argument<Boolean>("accent") ?: false
                    playMetronomeTick(
                        if (accent) "downbeat" else "upbeat",
                        "classic",
                        false
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            documentsChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDocument" -> pickDocument(result)
                "pickImage" -> pickImage(result)
                "loadImage" -> {
                    val uri = call.argument<String>("uri")
                    loadImage(uri, result)
                }
                "openWithSystemViewer" -> {
                    val uri = call.argument<String>("uri")
                    val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
                    openWithSystemViewer(uri, mimeType, result)
                }
                "getPdfViewerApps" -> {
                    getPdfViewerApps(result)
                }
                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    getAppIcon(packageName, result)
                }
                "openWithSpecificApp" -> {
                    val uri = call.argument<String>("uri")
                    val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
                    val packageName = call.argument<String>("packageName") ?: ""
                    openWithSpecificApp(uri, mimeType, packageName, result)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            pitchTraceChannelName
        ).also { pitchTraceChannel = it }
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val minFrequency = call.argument<Double>("minFrequency") ?: 80.0
                    val maxFrequency = call.argument<Double>("maxFrequency") ?: 2200.0
                    val windowSize = call.argument<Int>("windowSize") ?: 2048
                    val overlapRatio = call.argument<Double>("overlapRatio") ?: 0.5
                    startPitchTrace(minFrequency, maxFrequency, windowSize, overlapRatio, result)
                }
                "stop" -> {
                    val recordingPath = stopPitchTrace()
                    result.success(mapOf("recordingPath" to recordingPath))
                }
                "listRecordings" -> listRecordings(result)
                "deleteRecording" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "录音路径无效。", null)
                    } else {
                        deleteRecording(path, result)
                    }
                }
                "playRecording" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "录音路径无效。", null)
                    } else {
                        playRecording(path, result)
                    }
                }
                "stopPlayback" -> {
                    stopPlayback()
                    result.success(null)
                }
                "pausePlayback" -> {
                    pausePlayback()
                    result.success(null)
                }
                "resumePlayback" -> {
                    resumePlayback()
                    result.success(null)
                }
                "seekPlayback" -> {
                    val positionMs = call.argument<Int>("positionMs") ?: 0
                    seekPlayback(positionMs)
                    result.success(null)
                }
                "pauseRecording" -> {
                    pausePitchTraceRecording()
                    result.success(null)
                }
                "resumeRecording" -> {
                    resumePitchTraceRecording()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            pitchTraceEventChannelName
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                pitchTraceEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                pitchTraceEventSink = null
            }
        })
    }

    private fun startPitchTrace(
        minFrequency: Double,
        maxFrequency: Double,
        windowSize: Int,
        overlapRatio: Double,
        result: MethodChannel.Result
    ) {
        if (hasMicrophonePermission()) {
            startPitchTraceWithResult(minFrequency, maxFrequency, windowSize, overlapRatio, result)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (pendingPitchTraceStartResult != null) {
                result.error("PERMISSION_PENDING", "正在等待麦克风权限。", null)
                return
            }

            pendingPitchTraceStartResult = result
            pendingPitchTraceMinFrequency = minFrequency
            pendingPitchTraceMaxFrequency = maxFrequency
            pendingPitchTraceWindowSize = windowSize
            pendingPitchTraceOverlapRatio = overlapRatio
            requestPermissions(
                arrayOf(Manifest.permission.RECORD_AUDIO),
                pitchTracePermissionRequestCode
            )
            return
        }

        result.error("MIC_PERMISSION_DENIED", "没有麦克风权限。", null)
    }

    private fun startPitchTraceWithResult(
        minFrequency: Double,
        maxFrequency: Double,
        windowSize: Int = 2048,
        overlapRatio: Double = 0.5,
        result: MethodChannel.Result
    ) {
        try {
            if (pitchTracker == null) {
                pitchTracker = PitchTracker(
                    { reading ->
                        runOnUiThread {
                            pitchTraceEventSink?.success(reading)
                        }
                    },
                    File(filesDir, "recordings")
                )
            }

            pitchTracker?.setFrequencyRange(minFrequency, maxFrequency)
            pitchTracker?.setWindowSize(windowSize)
            pitchTracker?.setOverlapRatio(overlapRatio)
            pitchTracker?.start()
            result.success(null)
        } catch (error: RuntimeException) {
            result.error("PITCH_TRACE_START_FAILED", error.message, null)
        }
    }

    private fun stopPitchTrace(): String? {
        return pitchTracker?.stop()
    }

    private fun pausePitchTraceRecording() {
        pitchTracker?.pause()
    }

    private fun resumePitchTraceRecording() {
        pitchTracker?.resume()
    }

    private fun hasMicrophonePermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == pitchTracePermissionRequestCode) {
            val result = pendingPitchTraceStartResult ?: return
            pendingPitchTraceStartResult = null

            if (grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            ) {
                startPitchTraceWithResult(
                    pendingPitchTraceMinFrequency,
                    pendingPitchTraceMaxFrequency,
                    pendingPitchTraceWindowSize,
                    pendingPitchTraceOverlapRatio,
                    result
                )
            } else {
                result.error("MIC_PERMISSION_DENIED", "请允许麦克风权限后再使用听音。", null)
            }
            return
        }

        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun pickDocument(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("PICK_IN_PROGRESS", "已有文件选择正在进行。", null)
            return
        }

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/pdf", "image/*")
            )
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }

        try {
            pendingPickResult = result
            startActivityForResult(intent, pickDocumentRequestCode)
        } catch (error: ActivityNotFoundException) {
            pendingPickResult = null
            result.error("NO_FILE_PICKER", "没有找到可选择资料的应用。", null)
        }
    }

    private fun pickImage(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("PICK_IN_PROGRESS", "已有文件选择正在进行。", null)
            return
        }

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }

        try {
            pendingPickResult = result
            startActivityForResult(intent, pickImageRequestCode)
        } catch (error: ActivityNotFoundException) {
            pendingPickResult = null
            result.error("NO_FILE_PICKER", "没有找到可选择图片的应用。", null)
        }
    }

    private fun loadImage(uriString: String?, result: MethodChannel.Result) {
        val uri = parseUri(uriString, result) ?: return

        try {
            val bytes = contentResolver.openInputStream(uri)?.use { stream ->
                stream.readBytes()
            }

            if (bytes == null) {
                result.error("IMAGE_READ_FAILED", "无法读取图片。", null)
                return
            }

            result.success(bytes)
        } catch (error: SecurityException) {
            result.error("OPEN_DENIED", "没有权限读取这个图片，请重新添加。", null)
        } catch (error: RuntimeException) {
            result.error("IMAGE_READ_FAILED", error.message, null)
        }
    }

    private fun parseUri(
        uriString: String?,
        result: MethodChannel.Result
    ): Uri? {
        if (uriString.isNullOrBlank()) {
            result.error("INVALID_URI", "资料地址无效。", null)
            return null
        }

        return Uri.parse(uriString)
    }

    private fun openWithSystemViewer(
        uriString: String?,
        mimeType: String,
        result: MethodChannel.Result
    ) {
        if (uriString.isNullOrBlank()) {
            result.error("INVALID_URI", "资料地址无效。", null)
            return
        }

        try {
            val uri = Uri.parse(uriString)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(Intent.createChooser(intent, "用其他应用打开"))
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("NO_VIEWER", "没有找到可打开 PDF 的应用，请安装 PDF 阅读器。", null)
        } catch (error: SecurityException) {
            result.error("OPEN_DENIED", "没有权限打开这个资料，请重新添加。", null)
        }
    }

    private fun getPdfViewerApps(result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                type = "application/pdf"
            }
            val resolveInfos = packageManager.queryIntentActivities(intent, 0)
            val apps = resolveInfos.map { info ->
                mapOf(
                    "packageName" to info.activityInfo.packageName,
                    "appName" to info.loadLabel(packageManager).toString()
                )
            }
            result.success(apps)
        } catch (error: Exception) {
            result.error("GET_APPS_FAILED", error.message ?: "获取应用列表失败。", null)
        }
    }

    private fun getAppIcon(packageName: String, result: MethodChannel.Result) {
        try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            val drawable = packageManager.getApplicationIcon(appInfo)
            val bitmap = android.graphics.Bitmap.createBitmap(
                drawable.intrinsicWidth.coerceAtLeast(1),
                drawable.intrinsicHeight.coerceAtLeast(1),
                android.graphics.Bitmap.Config.ARGB_8888
            )
            val canvas = android.graphics.Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)

            val stream = java.io.ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
            val bytes = stream.toByteArray()
            result.success(bytes)
        } catch (error: Exception) {
            result.error("GET_ICON_FAILED", error.message ?: "获取应用图标失败。", null)
        }
    }

    private fun openWithSpecificApp(
        uriString: String?,
        mimeType: String,
        packageName: String,
        result: MethodChannel.Result
    ) {
        if (uriString.isNullOrBlank()) {
            result.error("INVALID_URI", "资料地址无效。", null)
            return
        }

        try {
            val uri = Uri.parse(uriString)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(packageName)
            }
            startActivity(intent)
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("NO_VIEWER", "指定的应用无法打开 PDF。", null)
        } catch (error: SecurityException) {
            result.error("OPEN_DENIED", "没有权限打开这个资料，请重新添加。", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        if (requestCode == pickDocumentRequestCode || requestCode == pickImageRequestCode) {
            handlePickedDocument(resultCode, data)
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun handlePickedDocument(resultCode: Int, data: Intent?) {
        val result = pendingPickResult ?: return
        pendingPickResult = null

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val items = mutableListOf<Map<String, Any?>>()
        val takeFlags = (data?.flags ?: 0) and Intent.FLAG_GRANT_READ_URI_PERMISSION

        // 处理多选：通过 clipData 获取所有 URI
        val clipData = data?.clipData
        if (clipData != null && clipData.itemCount > 0) {
            for (i in 0 until clipData.itemCount) {
                val uri = clipData.getItemAt(i).uri
                addUriToItems(uri, takeFlags, items)
            }
        } else {
            // 单选（兼容不支持多选的文件管理器）
            val uri = data?.data
            if (uri != null) {
                addUriToItems(uri, takeFlags, items)
            }
        }

        if (items.isEmpty()) {
            result.success(null)
            return
        }

        result.success(items)
    }

    private fun addUriToItems(
        uri: Uri,
        takeFlags: Int,
        items: MutableList<Map<String, Any?>>
    ) {
        if (takeFlags != 0) {
            try {
                contentResolver.takePersistableUriPermission(uri, takeFlags)
            } catch (_: SecurityException) {
            }
        }
        items.add(
            mapOf(
                "uri" to uri.toString(),
                "name" to displayNameFor(uri),
                "mimeType" to (contentResolver.getType(uri) ?: "application/octet-stream"),
                "sizeBytes" to sizeFor(uri)
            )
        )
    }

    private fun displayNameFor(uri: Uri): String {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                val value = cursor.getString(index)
                if (!value.isNullOrBlank()) return value
            }
        }

        return uri.lastPathSegment ?: "未命名 PDF"
    }

    private fun sizeFor(uri: Uri): Long? {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.SIZE)
            if (index >= 0 && cursor.moveToFirst() && !cursor.isNull(index)) {
                return cursor.getLong(index)
            }
        }

        return null
    }

    private fun playMetronomeTick(
        role: String,
        soundStyle: String,
        vibrate: Boolean
    ) {
        if (vibrate) {
            vibrateTick(role)
        }

        if (role == "rest" || soundStyle == "silent") {
            return
        }

        val generator = toneGenerator ?: ToneGenerator(
            AudioManager.STREAM_MUSIC,
            100
        ).also { toneGenerator = it }

        generator.startTone(toneTypeFor(role, soundStyle), durationFor(role))
    }

    private fun toneTypeFor(role: String, soundStyle: String): Int {
        return when (soundStyle) {
            "wood" -> when (role) {
                "downbeat" -> ToneGenerator.TONE_DTMF_1
                "subdivision" -> ToneGenerator.TONE_DTMF_3
                else -> ToneGenerator.TONE_DTMF_2
            }
            "electronic" -> when (role) {
                "downbeat" -> ToneGenerator.TONE_DTMF_9
                "subdivision" -> ToneGenerator.TONE_DTMF_6
                else -> ToneGenerator.TONE_DTMF_8
            }
            "soft" -> when (role) {
                "downbeat" -> ToneGenerator.TONE_PROP_PROMPT
                "subdivision" -> ToneGenerator.TONE_PROP_ACK
                else -> ToneGenerator.TONE_PROP_BEEP
            }
            "digital" -> when (role) {
                "downbeat" -> ToneGenerator.TONE_DTMF_D
                "subdivision" -> ToneGenerator.TONE_DTMF_S
                else -> ToneGenerator.TONE_DTMF_P
            }
            "warm" -> when (role) {
                "downbeat" -> ToneGenerator.TONE_DTMF_5
                "subdivision" -> ToneGenerator.TONE_DTMF_6
                else -> ToneGenerator.TONE_DTMF_4
            }
            "bright" -> when (role) {
                "downbeat" -> ToneGenerator.TONE_DTMF_7
                "subdivision" -> ToneGenerator.TONE_DTMF_9
                else -> ToneGenerator.TONE_DTMF_8
            }
            "deep" -> when (role) {
                "downbeat" -> ToneGenerator.TONE_DTMF_0
                "subdivision" -> ToneGenerator.TONE_DTMF_A
                else -> ToneGenerator.TONE_DTMF_1
            }
            else -> when (role) {
                "downbeat" -> ToneGenerator.TONE_PROP_BEEP2
                "subdivision" -> ToneGenerator.TONE_PROP_ACK
                else -> ToneGenerator.TONE_PROP_BEEP
            }
        }
    }

    private fun durationFor(role: String): Int {
        return when (role) {
            "downbeat" -> 90
            "subdivision" -> 35
            else -> 60
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrateTick(role: String) {
        if (role == "rest") return

        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(VibratorManager::class.java)
            manager.defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        if (!vibrator.hasVibrator()) return

        val durationMs = if (role == "downbeat") 24L else 10L
        val amplitude = if (role == "downbeat") 180 else 80

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(durationMs, amplitude)
            )
        } else {
            vibrator.vibrate(durationMs)
        }
    }

    private fun listRecordings(result: MethodChannel.Result) {
        val dir = File(filesDir, "recordings")
        if (!dir.exists()) {
            result.success(emptyList<Map<String, Any>>())
            return
        }
        val files = dir.listFiles { f -> f.name.endsWith(".wav") } ?: emptyArray()
        val list = files.sortedByDescending { it.lastModified() }.map { file ->
            val dataSize = file.length() - 44
            val durationSeconds = if (dataSize > 0) dataSize / (44100 * 2) else 0
            mapOf(
                "path" to file.absolutePath,
                "name" to file.name,
                "sizeBytes" to file.length(),
                "lastModified" to file.lastModified(),
                "durationSeconds" to durationSeconds
            )
        }
        result.success(list)
    }

    private fun deleteRecording(path: String, result: MethodChannel.Result) {
        val file = File(path)
        if (file.exists() && file.delete()) {
            result.success(null)
        } else {
            result.error("DELETE_FAILED", "无法删除录音文件。", null)
        }
    }

    private fun playRecording(path: String, result: MethodChannel.Result) {
        try {
            stopPlaybackInternal()
            val file = File(path)
            val player = MediaPlayer().apply {
                setDataSource(path)
                prepare()
                start()
                setOnCompletionListener { mp ->
                    mp.release()
                    if (mediaPlayer === mp) {
                        mediaPlayer = null
                        // 通知 Flutter 播放完成
                        pitchTraceChannel?.invokeMethod("onPlaybackComplete", null)
                    }
                }
            }
            mediaPlayer = player
            val durationMs = player.duration
            result.success(mapOf("name" to file.name, "durationMs" to durationMs))
        } catch (e: Exception) {
            result.error("PLAYBACK_ERROR", e.message, null)
        }
    }

    private fun stopPlayback() {
        stopPlaybackInternal()
    }

    private fun pausePlayback() {
        try {
            mediaPlayer?.pause()
        } catch (_: Exception) {}
    }

    private fun resumePlayback() {
        try {
            mediaPlayer?.start()
        } catch (_: Exception) {}
    }

    private fun seekPlayback(positionMs: Int) {
        try {
            mediaPlayer?.seekTo(positionMs)
        } catch (_: Exception) {}
    }

    private fun stopPlaybackInternal() {
        mediaPlayer?.release()
        mediaPlayer = null
    }

    override fun onDestroy() {
        stopPlaybackInternal()
        stopPitchTrace()
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }

    private class PitchTracker(
        private val onReading: (Map<String, Any>) -> Unit,
        private val recordingsDir: File
    ) {
        private val sampleRate = 44100
        @Volatile
        private var windowSize = 2048
        @Volatile
        private var overlapRatio = 0.5
        @Volatile
        private var minFrequency = 80.0
        @Volatile
        private var maxFrequency = 2200.0

        @Volatile
        private var running = false

        private var worker: Thread? = null
        private var recorder: AudioRecord? = null
        private val pcmShorts = mutableListOf<Short>()

        fun setFrequencyRange(minFrequency: Double, maxFrequency: Double) {
            val low = minFrequency.coerceIn(80.0, 2600.0)
            val high = maxFrequency.coerceIn(80.0, 2600.0)
            val cleanLow = min(low, high)
            val cleanHigh = max(low, high)
            if (cleanHigh - cleanLow < 50.0) {
                this.minFrequency = cleanLow
                this.maxFrequency = (cleanLow + 50.0).coerceAtMost(2600.0)
                return
            }
            this.minFrequency = cleanLow
            this.maxFrequency = cleanHigh
        }

        fun setWindowSize(size: Int) {
            windowSize = size.coerceIn(1024, 8192)
        }

        fun setOverlapRatio(ratio: Double) {
            overlapRatio = ratio.coerceIn(0.0, 0.75)
        }

        @Suppress("MissingPermission")
        fun start() {
            if (running) return

            val minBuffer = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBuffer <= 0) {
                throw IllegalStateException("无法初始化麦克风。")
            }

            val recordBufferSize = max(minBuffer, windowSize * 2)
            val newRecorder = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                recordBufferSize
            )
            if (newRecorder.state != AudioRecord.STATE_INITIALIZED) {
                newRecorder.release()
                throw IllegalStateException("麦克风不可用。")
            }

            recorder = newRecorder
            running = true
            pcmShorts.clear()

            worker = Thread {
                val hopSize = max(1, (windowSize * (1.0 - overlapRatio)).toInt())
                val readBuffer = ShortArray(hopSize)
                val analysisBuffer = mutableListOf<Short>()
                try {
                    newRecorder.startRecording()
                    while (running) {
                        val read = newRecorder.read(readBuffer, 0, readBuffer.size)
                        if (read > 0) {
                            for (i in 0 until read) {
                                pcmShorts.add(readBuffer[i])
                                analysisBuffer.add(readBuffer[i])
                            }
                            // 当累积的样本达到窗口大小时进行分析
                            while (analysisBuffer.size >= windowSize) {
                                val window = analysisBuffer.take(windowSize).toShortArray()
                                onReading(analyze(window, windowSize))
                                // 移除 hopSize 个样本（重叠分析）
                                val removeCount = min(hopSize, analysisBuffer.size)
                                repeat(removeCount) { analysisBuffer.removeAt(0) }
                            }
                        }
                    }
                } catch (_: RuntimeException) {
                    onReading(emptyReading())
                } finally {
                    try {
                        newRecorder.stop()
                    } catch (_: RuntimeException) {
                    }
                    newRecorder.release()
                }
            }.also { thread ->
                thread.name = "FlutePitchTraceTracker"
                thread.start()
            }
        }

        fun pause() {
            if (!running) return
            running = false
            worker?.join(250)
            worker = null
            try { recorder?.stop() } catch (_: RuntimeException) {}
            recorder?.release()
            recorder = null
        }

        @Suppress("MissingPermission")
        fun resume() {
            if (running) return

            val minBuffer = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBuffer <= 0) {
                onReading(emptyReading())
                return
            }

            val recordBufferSize = max(minBuffer, windowSize * 2)
            val newRecorder = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                recordBufferSize
            )
            if (newRecorder.state != AudioRecord.STATE_INITIALIZED) {
                newRecorder.release()
                onReading(emptyReading())
                return
            }

            recorder = newRecorder
            running = true

            worker = Thread {
                val buffer = ShortArray(windowSize)
                try {
                    newRecorder.startRecording()
                    while (running) {
                        val read = newRecorder.read(buffer, 0, buffer.size)
                        if (read > 0) {
                            for (i in 0 until read) {
                                pcmShorts.add(buffer[i])
                            }
                            onReading(analyze(buffer, read))
                        }
                    }
                } catch (_: RuntimeException) {
                    onReading(emptyReading())
                } finally {
                    try {
                        newRecorder.stop()
                    } catch (_: RuntimeException) {
                    }
                    newRecorder.release()
                }
            }.also { thread ->
                thread.name = "FlutePitchTraceTracker"
                thread.start()
            }
        }

        fun stop(): String? {
            running = false
            worker?.join(250)
            worker = null
            recorder = null

            val path = if (pcmShorts.isNotEmpty()) {
                writeWav()
            } else {
                null
            }
            pcmShorts.clear()
            return path
        }

        private fun writeWav(): String {
            val bytes = shortsToBytes(pcmShorts)
            val timestamp = System.currentTimeMillis()
            recordingsDir.mkdirs()
            val dateStr = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault()).format(Date(timestamp))
            val file = File(recordingsDir, "${dateStr}.wav")
            val totalDataLen = bytes.size + 36
            val byteRate = sampleRate * 1 * 16 / 8

            file.outputStream().use { out ->
                out.write("RIFF".toByteArray())
                out.write(intToByteArray(totalDataLen))
                out.write("WAVE".toByteArray())
                out.write("fmt ".toByteArray())
                out.write(intToByteArray(16))
                out.write(shortToByteArray(1))
                out.write(shortToByteArray(1))
                out.write(intToByteArray(sampleRate))
                out.write(intToByteArray(byteRate))
                out.write(shortToByteArray(2))
                out.write(shortToByteArray(16))
                out.write("data".toByteArray())
                out.write(intToByteArray(bytes.size))
                out.write(bytes)
            }

            return file.absolutePath
        }

        private fun shortsToBytes(shorts: List<Short>): ByteArray {
            val bytes = ByteArray(shorts.size * 2)
            for (i in shorts.indices) {
                val value = shorts[i].toInt()
                bytes[i * 2] = (value and 0xFF).toByte()
                bytes[i * 2 + 1] = ((value shr 8) and 0xFF).toByte()
            }
            return bytes
        }

        private fun intToByteArray(value: Int): ByteArray {
            return byteArrayOf(
                (value and 0xFF).toByte(),
                ((value shr 8) and 0xFF).toByte(),
                ((value shr 16) and 0xFF).toByte(),
                ((value shr 24) and 0xFF).toByte()
            )
        }

        private fun shortToByteArray(value: Int): ByteArray {
            return byteArrayOf(
                (value and 0xFF).toByte(),
                ((value shr 8) and 0xFF).toByte()
            )
        }

        private fun analyze(buffer: ShortArray, read: Int): Map<String, Any> {
            var sum = 0.0
            for (i in 0 until read) {
                sum += buffer[i].toDouble()
            }
            val mean = sum / read

            val samples = DoubleArray(read)
            var energy = 0.0
            for (i in 0 until read) {
                val sample = (buffer[i].toDouble() - mean) / Short.MAX_VALUE
                samples[i] = sample
                energy += sample * sample
            }

            val amplitude = sqrt(energy / read)
            if (amplitude < 0.006) {
                return reading(0.0, amplitude, 0.0)
            }

            val minLag = max(2, (sampleRate / maxFrequency).toInt())
            val maxLag = min(read - 2, (sampleRate / minFrequency).toInt())
            if (maxLag <= minLag + 2) {
                return reading(0.0, amplitude, 0.0)
            }

            val detected = detectFundamentalLag(samples, read, minLag, maxLag)
            if (detected == null) {
                return reading(0.0, amplitude, 0.0)
            }

            val frequency = sampleRate / detected.lag
            return reading(frequency, amplitude, detected.clarity)
        }

        private data class PitchLagResult(
            val lag: Double,
            val clarity: Double
        )

        private fun detectFundamentalLag(
            samples: DoubleArray,
            read: Int,
            minLag: Int,
            maxLag: Int
        ): PitchLagResult? {
            val yin = DoubleArray(maxLag + 1)
            for (lag in 1..maxLag) {
                var difference = 0.0
                val length = read - lag
                for (i in 0 until length) {
                    val delta = samples[i] - samples[i + lag]
                    difference += delta * delta
                }
                yin[lag] = difference
            }

            var cumulative = 0.0
            var bestLag = minLag
            var bestValue = Double.MAX_VALUE
            for (lag in 1..maxLag) {
                cumulative += yin[lag]
                yin[lag] = if (cumulative > 0.0) {
                    yin[lag] * lag / cumulative
                } else {
                    1.0
                }
                if (lag >= minLag && yin[lag] < bestValue) {
                    bestLag = lag
                    bestValue = yin[lag]
                }
            }

            val threshold = 0.18
            var selectedLag = 0
            var lag = minLag
            while (lag <= maxLag) {
                if (yin[lag] < threshold) {
                    selectedLag = lag
                    while (selectedLag + 1 <= maxLag &&
                        yin[selectedLag + 1] < yin[selectedLag]
                    ) {
                        selectedLag++
                    }
                    break
                }
                lag++
            }

            if (selectedLag == 0) {
                if (bestValue > 0.32) return null
                selectedLag = bestLag
            }

            val clarity = (1.0 - yin[selectedLag]).coerceIn(0.0, 1.0)
            if (clarity < 0.52) return null

            return PitchLagResult(refineYinLag(yin, selectedLag), clarity)
        }

        private fun refineYinLag(yin: DoubleArray, lag: Int): Double {
            if (lag <= 1 || lag >= yin.size - 2) return lag.toDouble()

            val left = yin[lag - 1]
            val center = yin[lag]
            val right = yin[lag + 1]
            val denominator = left - 2 * center + right

            if (abs(denominator) < 1e-9) return lag.toDouble()

            val offset = 0.5 * (left - right) / denominator
            return lag + offset.coerceIn(-0.5, 0.5)
        }

        private fun reading(
            frequency: Double,
            amplitude: Double,
            clarity: Double
        ): Map<String, Any> {
            return mapOf(
                "frequency" to frequency,
                "amplitude" to amplitude,
                "clarity" to clarity,
                "timestampMillis" to System.currentTimeMillis()
            )
        }

        private fun emptyReading(): Map<String, Any> {
            return reading(0.0, 0.0, 0.0)
        }
    }
}
