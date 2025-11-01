package com.kyotee.mobile

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "kyotee/app_icon"

    private val aliasMap: Map<String?, String> = mapOf(
        null to "com.kyotee.mobile.MainActivityDefault",
        "NeonBlue" to "com.kyotee.mobile.MainActivityNeonBlue",
        "NeonPurple" to "com.kyotee.mobile.MainActivityNeonPurple",
        "NeonYellow" to "com.kyotee.mobile.MainActivityNeonYellow",
        "NeonWhite" to "com.kyotee.mobile.MainActivityNeonWhite",
        "NeonTeal" to "com.kyotee.mobile.MainActivityNeonTeal",
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureSingleEnabledAlias()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "supportsAlternateIcons" -> result.success(true)
                    "currentIconName" -> {
                        result.success(currentAliasName())
                    }
                    "setIcon" -> {
                        val iconName = (call.argument<String?>("iconName"))?.takeIf { it.isNotEmpty() }
                        if (!aliasMap.containsKey(iconName)) {
                            result.error("invalid_icon", "Unknown icon option: $iconName", null)
                            return@setMethodCallHandler
                        }
                        setIcon(alias = iconName)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureSingleEnabledAlias() {
        val pm = packageManager
        val enabledAliases = aliasMap.values.count { alias ->
            pm.getComponentEnabledSetting(ComponentName(this, alias)) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        }
        if (enabledAliases == 0) {
            setIcon(null)
        } else if (enabledAliases > 1) {
            val current = currentAliasName()
            setIcon(current)
        }
    }

    private fun currentAliasName(): String? {
        val pm = packageManager
        aliasMap.forEach { (name, aliasClass) ->
            val state = pm.getComponentEnabledSetting(ComponentName(this, aliasClass))
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return name
            }
        }
        return null
    }

    private fun setIcon(alias: String?) {
        val pm = packageManager
        aliasMap.forEach { (name, aliasClass) ->
            val component = ComponentName(this, aliasClass)
            val newState = if (name == alias) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            pm.setComponentEnabledSetting(component, newState, PackageManager.DONT_KILL_APP)
        }
    }
}
