package id.horas.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val locationExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.horas.app/coarse_location"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getCoarseLocation") {
                resolveCoarseLocation(result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun resolveCoarseLocation(result: MethodChannel.Result) {
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            result.success(null)
            return
        }

        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (lm == null) {
            result.success(null)
            return
        }

        val providers = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            providers.add(LocationManager.FUSED_PROVIDER)
        }
        providers.add(LocationManager.NETWORK_PROVIDER)
        providers.add(LocationManager.PASSIVE_PROVIDER)

        var best: Location? = null
        for (p in providers) {
            try {
                if (lm.isProviderEnabled(p)) {
                    val l = lm.getLastKnownLocation(p)
                    if (l != null && (best == null || l.time > best.time)) {
                        best = l
                    }
                }
            } catch (_: SecurityException) {
            } catch (_: IllegalArgumentException) {
            }
        }

        // Jika cache lokasi masih fresh (< 10 menit), langsung kembalikan.
        val tenMinutesMs = 10 * 60 * 1000L
        if (best != null && (System.currentTimeMillis() - best.time) < tenMinutesMs) {
            result.success(mapOf("latitude" to best.latitude, "longitude" to best.longitude))
            return
        }

        // Pada Android 11+ (API 30+), coba ambil 1 lokasi perkiraan terbaru (tetap COARSE).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val activeProvider = when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    lm.isProviderEnabled(LocationManager.FUSED_PROVIDER) ->
                    LocationManager.FUSED_PROVIDER
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                    LocationManager.NETWORK_PROVIDER
                else -> null
            }
            if (activeProvider != null) {
                try {
                    val signal = CancellationSignal()
                    var replied = false
                    val mainHandler = android.os.Handler(mainLooper)
                    mainHandler.postDelayed({
                        if (!replied) {
                            replied = true
                            signal.cancel()
                            result.success(
                                best?.let {
                                    mapOf("latitude" to it.latitude, "longitude" to it.longitude)
                                }
                            )
                        }
                    }, 3500)
                    lm.getCurrentLocation(activeProvider, signal, locationExecutor) { fresh ->
                        mainHandler.post {
                            if (!replied) {
                                replied = true
                                val chosen = fresh ?: best
                                result.success(
                                    chosen?.let {
                                        mapOf(
                                            "latitude" to it.latitude,
                                            "longitude" to it.longitude
                                        )
                                    }
                                )
                            }
                        }
                    }
                    return
                } catch (_: SecurityException) {
                } catch (_: IllegalArgumentException) {
                }
            }
        }

        result.success(
            best?.let {
                mapOf("latitude" to it.latitude, "longitude" to it.longitude)
            }
        )
    }
}
