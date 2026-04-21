# Android Setup for Local Development

## 1. Copy network_security_config.xml

Copy `network_security_config.xml` to:
```
android/app/src/main/res/xml/network_security_config.xml
```
Create the `xml/` directory if it doesn't exist.

## 2. Update AndroidManifest.xml

In `android/app/src/main/AndroidManifest.xml`, add these attributes to the `<application>` tag:

```xml
<application
    android:label="fraud_detection_app"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:networkSecurityConfig="@xml/network_security_config"
    android:usesCleartextTraffic="true">
```

Also add the INTERNET permission before `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

## 3. For iOS — Add to Info.plist

In `ios/Runner/Info.plist`, add inside the root `<dict>`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

> ⚠️ These settings are for local development only.
> Use HTTPS with a valid certificate in production.
