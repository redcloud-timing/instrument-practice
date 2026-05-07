package com.example.flute_practice

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
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
import java.io.ByteArrayOutputStream
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val metronomeChannelName = "flute_practice/metronome"
    private val documentsChannelName = "flute_practice/documents"
    private val tunerChannelName = "flute_practice/tuner"
    private val tunerEventChannelName = "flute_practice/tuner_events"
    private val pickDocumentRequestCode = 4701
    private val pickImageRequestCode = 4702
    private val tunerPermissionRequestCode = 4801
    private var toneGenerator: ToneGenerator? = null
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingTunerStartResult: MethodChannel.Result? = null
    private var tunerEventSink: EventChannel.EventSink? = null
    private var pitchTracker: PitchTracker? = null
    private var mediaPlayer: MediaPlayer? = null

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
                "pdfPageCount" -> {
                    val uri = call.argument<String>("uri")
                    pdfPageCount(uri, result)
                }
                "renderPdfPage" -> {
                    val uri = call.argument<String>("uri")
                    val pageIndex = call.argument<Int>("pageIndex") ?: 0
                    val maxWidth = call.argument<Int>("maxWidth") ?: 900
                    renderPdfPage(uri, pageIndex, maxWidth, result)
                }
                "openDocument" -> {
                    val uri = call.argument<String>("uri")
                    val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
                    openDocument(uri, mimeType, result)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            tunerChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> startTuner(result)
                "stop" -> {
                    val recordingPath = stopTuner()
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
                    pauseRecordingTuner()
                    result.success(null)
                }
                "resumeRecording" -> {
                    resumeRecordingTuner()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            tunerEventChannelName
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                tunerEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                tunerEventSink = null
            }
        })
    }

    private fun startTuner(result: MethodChannel.Result) {
        if (hasMicrophonePermission()) {
            startTunerWithResult(result)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (pendingTunerStartResult != null) {
                result.error("PERMISSION_PENDING", "正在等待麦克风权限。", null)
                return
            }

            pendingTunerStartResult = result
            requestPermissions(
                arrayOf(Manifest.permission.RECORD_AUDIO),
                tunerPermissionRequestCode
            )
            return
        }

        result.error("MIC_PERMISSION_DENIED", "没有麦克风权限。", null)
    }

    private fun startTunerWithResult(result: MethodChannel.Result) {
        try {
            if (pitchTracker == null) {
                pitchTracker = PitchTracker(
                    { reading ->
                        runOnUiThread {
                            tunerEventSink?.success(reading)
                        }
                    },
                    File(filesDir, "recordings")
                )
            }

            pitchTracker?.start()
            result.success(null)
        } catch (error: RuntimeException) {
            result.error("TUNER_START_FAILED", error.message, null)
        }
    }

    private fun stopTuner(): String? {
        return pitchTracker?.stop()
    }

    private fun pauseRecordingTuner() {
        pitchTracker?.pause()
    }

    private fun resumeRecordingTuner() {
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
        if (requestCode == tunerPermissionRequestCode) {
            val result = pendingTunerStartResult ?: return
            pendingTunerStartResult = null

            if (grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            ) {
                startTunerWithResult(result)
            } else {
                result.error("MIC_PERMISSION_DENIED", "请允许麦克风权限后再使用调音器。", null)
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

    private fun pdfPageCount(uriString: String?, result: MethodChannel.Result) {
        val uri = parseUri(uriString, result) ?: return

        try {
            val count = withPdfRenderer(uri) { renderer -> renderer.pageCount }
            result.success(count)
        } catch (error: SecurityException) {
            result.error("OPEN_DENIED", "没有权限读取这个 PDF，请重新添加。", null)
        } catch (error: RuntimeException) {
            result.error("PDF_READ_FAILED", error.message, null)
        }
    }

    private fun renderPdfPage(
        uriString: String?,
        pageIndex: Int,
        maxWidth: Int,
        result: MethodChannel.Result
    ) {
        val uri = parseUri(uriString, result) ?: return

        try {
            val bytes = withPdfRenderer(uri) { renderer ->
                if (pageIndex < 0 || pageIndex >= renderer.pageCount) {
                    throw IllegalArgumentException("PDF 页码无效。")
                }

                val output = renderer.openPage(pageIndex).use { page ->
                    val width = maxWidth.coerceIn(320, 2200)
                    val ratio = page.height.toFloat() / page.width.toFloat()
                    val height = (width * ratio).toInt().coerceAtLeast(1)
                    val bitmap = Bitmap.createBitmap(
                        width,
                        height,
                        Bitmap.Config.ARGB_8888
                    )
                    bitmap.eraseColor(Color.WHITE)

                    page.render(
                        bitmap,
                        null,
                        null,
                        PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY
                    )

                    val output = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                    bitmap.recycle()
                    output.toByteArray()
                }

                output
            }

            result.success(bytes)
        } catch (error: SecurityException) {
            result.error("OPEN_DENIED", "没有权限读取这个 PDF，请重新添加。", null)
        } catch (error: RuntimeException) {
            result.error("PDF_RENDER_FAILED", error.message, null)
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

    private fun <T> withPdfRenderer(uri: Uri, block: (PdfRenderer) -> T): T {
        val descriptor = contentResolver.openFileDescriptor(uri, "r")
            ?: throw IllegalStateException("无法打开 PDF。")
        try {
            PdfRenderer(descriptor).use { renderer ->
                return block(renderer)
            }
        } finally {
            descriptor.close()
        }
    }

    private fun openDocument(
        uriString: String?,
        mimeType: String,
        result: MethodChannel.Result
    ) {
        if (uriString.isNullOrBlank()) {
            result.error("INVALID_URI", "资料地址无效。", null)
            return
        }

        val uri = Uri.parse(uriString)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            startActivity(Intent.createChooser(intent, "打开资料"))
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("NO_VIEWER", "没有找到可打开 PDF 的应用。", null)
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

        val uri = data?.data
        if (uri == null) {
            result.success(null)
            return
        }

        val takeFlags = (data?.flags ?: 0) and Intent.FLAG_GRANT_READ_URI_PERMISSION
        if (takeFlags != 0) {
            try {
                contentResolver.takePersistableUriPermission(uri, takeFlags)
            } catch (_: SecurityException) {
            }
        }

        result.success(
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
            90
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
                    if (mediaPlayer === mp) mediaPlayer = null
                }
            }
            mediaPlayer = player
            result.success(mapOf("name" to file.name))
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
        stopTuner()
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }

    private class PitchTracker(
        private val onReading: (Map<String, Any>) -> Unit,
        private val recordingsDir: File
    ) {
        private val sampleRate = 44100
        private val windowSize = 4096
        private val minFrequency = 120.0
        private val maxFrequency = 2400.0

        @Volatile
        private var running = false

        private var worker: Thread? = null
        private var recorder: AudioRecord? = null
        private var smoothedFrequency = 0.0
        private val pcmShorts = mutableListOf<Short>()

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
                thread.name = "FluteTunerPitchTracker"
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
            smoothedFrequency = 0.0
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
                thread.name = "FluteTunerPitchTracker"
                thread.start()
            }
        }

        fun stop(): String? {
            running = false
            worker?.join(250)
            worker = null
            recorder = null
            smoothedFrequency = 0.0

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
                val value = (buffer[i].toDouble() - mean) / Short.MAX_VALUE
                val window = 0.5 - 0.5 * cos(2.0 * Math.PI * i / (read - 1))
                val sample = value * window
                samples[i] = sample
                energy += sample * sample
            }

            val amplitude = sqrt(energy / read)
            if (amplitude < 0.008) {
                smoothedFrequency = 0.0
                return reading(0.0, amplitude, 0.0)
            }

            val minLag = max(1, (sampleRate / maxFrequency).toInt())
            val maxLag = min(read - 2, (sampleRate / minFrequency).toInt())
            var bestLag = 0
            var bestCorrelation = 0.0

            for (lag in minLag..maxLag) {
                var correlation = 0.0
                var leftEnergy = 0.0
                var rightEnergy = 0.0

                val length = read - lag
                for (i in 0 until length) {
                    val left = samples[i]
                    val right = samples[i + lag]
                    correlation += left * right
                    leftEnergy += left * left
                    rightEnergy += right * right
                }

                val normalized = if (leftEnergy > 0 && rightEnergy > 0) {
                    correlation / sqrt(leftEnergy * rightEnergy)
                } else {
                    0.0
                }

                if (normalized > bestCorrelation) {
                    bestCorrelation = normalized
                    bestLag = lag
                }
            }

            if (bestLag <= 0 || bestCorrelation < 0.45) {
                smoothedFrequency = 0.0
                return reading(0.0, amplitude, bestCorrelation.coerceIn(0.0, 1.0))
            }

            val refinedLag = refineLag(samples, read, bestLag)
            val rawFrequency = sampleRate / refinedLag
            val frequency = if (smoothedFrequency <= 0) {
                rawFrequency
            } else if (abs(rawFrequency - smoothedFrequency) > smoothedFrequency * 0.18) {
                rawFrequency
            } else {
                smoothedFrequency * 0.72 + rawFrequency * 0.28
            }

            smoothedFrequency = frequency
            return reading(frequency, amplitude, bestCorrelation.coerceIn(0.0, 1.0))
        }

        private fun refineLag(samples: DoubleArray, read: Int, lag: Int): Double {
            if (lag <= 1 || lag >= read - 2) return lag.toDouble()

            val left = normalizedCorrelation(samples, read, lag - 1)
            val center = normalizedCorrelation(samples, read, lag)
            val right = normalizedCorrelation(samples, read, lag + 1)
            val denominator = left - 2 * center + right

            if (abs(denominator) < 1e-9) return lag.toDouble()

            val offset = 0.5 * (left - right) / denominator
            return lag + offset.coerceIn(-0.5, 0.5)
        }

        private fun normalizedCorrelation(
            samples: DoubleArray,
            read: Int,
            lag: Int
        ): Double {
            var correlation = 0.0
            var leftEnergy = 0.0
            var rightEnergy = 0.0
            val length = read - lag

            for (i in 0 until length) {
                val left = samples[i]
                val right = samples[i + lag]
                correlation += left * right
                leftEnergy += left * left
                rightEnergy += right * right
            }

            return if (leftEnergy > 0 && rightEnergy > 0) {
                correlation / sqrt(leftEnergy * rightEnergy)
            } else {
                0.0
            }
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
