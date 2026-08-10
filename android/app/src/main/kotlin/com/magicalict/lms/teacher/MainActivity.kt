package com.magicalict.lms.teacher

import android.media.MediaRecorder
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val audioChannel = "magical_lms_teacher/audio_recorder"
    private var recorder: MediaRecorder? = null
    private var outputPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> startRecording(result)
                    "stop" -> stopRecording(result)
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun startRecording(result: MethodChannel.Result) {
        try {
            recorder?.release()
            val file = File(cacheDir, "voice-message-${System.currentTimeMillis()}.m4a")
            outputPath = file.absolutePath
            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                MediaRecorder()
            }.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(128000)
                setAudioSamplingRate(44100)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }
            result.success(file.absolutePath)
        } catch (error: Exception) {
            recorder?.release()
            recorder = null
            outputPath = null
            result.error("RECORD_START_FAILED", error.message, null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        val path = outputPath
        try {
            recorder?.stop()
            recorder?.release()
            recorder = null
            outputPath = null
            result.success(path)
        } catch (error: Exception) {
            recorder?.release()
            recorder = null
            outputPath = null
            result.error("RECORD_STOP_FAILED", error.message, null)
        }
    }

    override fun onDestroy() {
        recorder?.release()
        recorder = null
        super.onDestroy()
    }
}