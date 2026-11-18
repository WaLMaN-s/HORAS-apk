package id.horas.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.horas.app/coarse_location"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getCoarseLocation") {
                val loc = readCoarseLocation()
                if (loc != null) {
                    result.success(
                        mapOf(
                            "latitude" to loc.latitude,
                            "longitude" to loc.longitude
                        )
                    )
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun readCoarseLocation(): Location? {
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) return null

        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        val providers = listOf(
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        )
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
        return best
    }
}
