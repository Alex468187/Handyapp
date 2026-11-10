"""Passt die von `flutter create` erzeugten Android-Dateien an.

Bricht laut ab, wenn eine erwartete Stelle fehlt (z. B. weil Flutter die
Vorlage geändert hat) – dann muss dieses Skript angepasst werden.
"""
import pathlib
import sys

MANIFEST = pathlib.Path("android/app/src/main/AndroidManifest.xml")
GRADLE = pathlib.Path("android/app/build.gradle.kts")


def replace_once(text: str, old: str, new: str, what: str) -> str:
    if old not in text:
        sys.exit(f"patch_android: '{what}' nicht gefunden")
    return text.replace(old, new, 1)


PERMISSIONS = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
    <application"""

RECEIVERS = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver"/>
        <service
            android:name="de.alex468187.handyapp.SummerListener"
            android:label="Summer"
            android:exported="true"
            android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
            <intent-filter>
                <action android:name="android.service.notification.NotificationListenerService"/>
            </intent-filter>
        </service>
    </application>"""

SPEECH_QUERY = """<queries>
        <intent>
            <action android:name="android.speech.RecognitionService"/>
        </intent>"""

m = MANIFEST.read_text(encoding="utf-8")
m = replace_once(m, "\n    <application", PERMISSIONS, "<application")
m = replace_once(m, "\n    </application>", RECEIVERS, "</application>")
m = replace_once(m, "<queries>", SPEECH_QUERY, "<queries>")
MANIFEST.write_text(m, encoding="utf-8")

g = GRADLE.read_text(encoding="utf-8")
g = replace_once(
    g,
    "compileOptions {",
    "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
    "compileOptions",
)
# Fester Signatur-Schlüssel (vom Build-Server in SUMMER_KEYSTORE abgelegt).
# Ohne ihn hat jeder Build eine andere Signatur und Updates schlagen fehl.
g = replace_once(
    g,
    "    buildTypes {",
    """    signingConfigs {
        create("summer") {
            storeFile = file(System.getenv("SUMMER_KEYSTORE") ?: "${System.getProperty("user.home")}/.android/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {""",
    "buildTypes",
)
g = replace_once(
    g,
    'signingConfig = signingConfigs.getByName("debug")',
    'signingConfig = signingConfigs.getByName("summer")',
    "release signingConfig",
)

# Nur 64-Bit-ARM einpacken (passend zu --target-platform android-arm64):
# Plugin-Bibliotheken anderer Prozessoren weglassen, damit die APK klein bleibt.
g += """
android {
    packaging {
        jniLibs {
            excludes += listOf("lib/armeabi-v7a/**", "lib/x86/**", "lib/x86_64/**")
        }
    }
}
"""
g += """
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
"""
GRADLE.write_text(g, encoding="utf-8")

print("patch_android: OK")
