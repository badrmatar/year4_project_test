package com.example.year4_project

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel


import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.request.ReadRecordsRequest


import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

import java.time.Instant

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.year4_project/health_connect"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->

            when (call.method) {

                
                "checkAvailability" -> {
                    val status = HealthConnectClient.getSdkStatus(this)
                    
                    val isAvailable = (status != HealthConnectClient.SDK_UNAVAILABLE)
                    result.success(isAvailable)
                }

                
                "getStepCount" -> {
                    val startTime = call.argument<Long>("startTime")
                    val endTime = call.argument<Long>("endTime") ?: Instant.now().toEpochMilli()

                    if (startTime == null) {
                        result.error("INVALID_ARGUMENT", "startTime is required", null)
                        return@setMethodCallHandler
                    }

                    
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            
                            val client = HealthConnectClient.getOrCreate(this@MainActivity)

                            
                            val timeRange = TimeRangeFilter.between(
                                Instant.ofEpochMilli(startTime),
                                Instant.ofEpochMilli(endTime)
                            )

                            
                            val readRequest = ReadRecordsRequest(
                                StepsRecord::class,
                                timeRange 
                            )

                            
                            val response = client.readRecords(readRequest)

                            
                            val totalSteps = response.records.sumOf { record -> record.count }

                            
                            runOnUiThread {
                                result.success(totalSteps)
                            }

                        } catch (e: Exception) {
                            
                            runOnUiThread {
                                result.error("READ_ERROR", e.localizedMessage, null)
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
