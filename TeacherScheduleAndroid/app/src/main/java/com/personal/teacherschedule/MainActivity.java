package com.personal.teacherschedule;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

public class MainActivity extends Activity {
    private static final int PICK_IMPORT = 10;
    private static final int PICK_EXPORT = 11;
    private static final int REQUEST_NOTIFICATIONS = 12;
    private WebView webView;
    private ValueCallback<Uri[]> fileCallback;
    private byte[] pendingBackup;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(android.graphics.Color.rgb(12, 17, 25));
        getWindow().setNavigationBarColor(android.graphics.Color.rgb(12, 17, 25));
        webView = new WebView(this);
        webView.setBackgroundColor(android.graphics.Color.rgb(12, 17, 25));
        webView.getSettings().setJavaScriptEnabled(true);
        webView.getSettings().setDomStorageEnabled(true);
        webView.getSettings().setAllowFileAccess(true);
        webView.getSettings().setAllowContentAccess(true);
        webView.addJavascriptInterface(new AppBridge(), "TeacherScheduleAndroid");
        webView.setWebViewClient(new WebViewClient());
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (fileCallback != null) fileCallback.onReceiveValue(null);
                fileCallback = callback;
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("application/json");
                startActivityForResult(intent, PICK_IMPORT);
                return true;
            }
        });
        setContentView(webView);
        webView.loadUrl("file:///android_asset/pwa/index.html");
    }

    private class AppBridge {
        @JavascriptInterface
        public void saveBackup(String json, String filename) {
            runOnUiThread(() -> {
                pendingBackup = json.getBytes(StandardCharsets.UTF_8);
                Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("application/json");
                intent.putExtra(Intent.EXTRA_TITLE, filename);
                startActivityForResult(intent, PICK_EXPORT);
            });
        }

        @JavascriptInterface
        public void syncSchedule(String json) {
            getSharedPreferences(ScheduleNotifications.PREFS, MODE_PRIVATE)
                    .edit().putString(ScheduleNotifications.SCHEDULE_KEY, json).apply();
            ScheduleWidgetProvider.updateAll(MainActivity.this);
            if (ScheduleNotifications.isEnabled(MainActivity.this)) {
                ScheduleNotifications.schedule(MainActivity.this);
            }
        }

        @JavascriptInterface
        public boolean notificationsEnabled() {
            return ScheduleNotifications.isEnabled(MainActivity.this)
                    && (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED);
        }

        @JavascriptInterface
        public void requestNotificationPermission() {
            runOnUiThread(() -> {
                if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, REQUEST_NOTIFICATIONS);
                } else {
                    enableNotifications();
                }
            });
        }

        @JavascriptInterface
        public void setNotificationsEnabled(boolean enabled) {
            runOnUiThread(() -> {
                if (enabled) enableNotifications();
                else {
                    ScheduleNotifications.setEnabled(MainActivity.this, false);
                    ScheduleNotifications.cancelAll(MainActivity.this);
                    notifyPage(false);
                }
            });
        }
    }

    private void enableNotifications() {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            notifyPage(false);
            return;
        }
        ScheduleNotifications.createChannel(this);
        ScheduleNotifications.setEnabled(this, true);
        ScheduleNotifications.schedule(this);
        notifyPage(true);
    }

    private void notifyPage(boolean enabled) {
        if (webView != null) webView.evaluateJavascript("window.onNotificationPermissionChanged(" + enabled + ")", null);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_NOTIFICATIONS) {
            boolean granted = grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
            if (granted) enableNotifications(); else notifyPage(false);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == PICK_IMPORT) {
            if (fileCallback != null) {
                fileCallback.onReceiveValue(resultCode == RESULT_OK && data != null ? new Uri[]{data.getData()} : null);
                fileCallback = null;
            }
        } else if (requestCode == PICK_EXPORT && resultCode == RESULT_OK && data != null) {
            try (OutputStream output = getContentResolver().openOutputStream(data.getData())) {
                if (output != null && pendingBackup != null) output.write(pendingBackup);
                Toast.makeText(this, "课表备份已保存", Toast.LENGTH_SHORT).show();
            } catch (Exception error) {
                Toast.makeText(this, "保存失败，请重试", Toast.LENGTH_SHORT).show();
            } finally {
                pendingBackup = null;
            }
        } else if (requestCode == PICK_EXPORT) {
            pendingBackup = null;
        }
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }
}
