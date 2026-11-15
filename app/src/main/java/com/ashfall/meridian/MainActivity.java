package com.ashfall.meridian;

import android.app.Activity;
import android.content.SharedPreferences;
import android.webkit.JavascriptInterface;
import android.os.Bundle;
import android.view.View;
import android.view.WindowManager;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public class MainActivity extends Activity {
    private WebView web;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(true);
        web.addJavascriptInterface(new NativeStore(getSharedPreferences("ashfall_saves", MODE_PRIVATE)), "NativeStore");
        web.setWebViewClient(new WebViewClient());
        web.setBackgroundColor(0xFF000000);
        setContentView(web);
        web.loadUrl("file:///android_asset/index.html");
        immersive();
    }

    private void immersive() {
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) immersive();
    }

    @Override
    public void onBackPressed() {
        web.evaluateJavascript("window.__back ? window.__back() : false", value -> {
            if (!"true".equals(value)) finish();
        });
    }

    // Saves are written to app storage directly, so they survive the app being swiped away.
    static class NativeStore {
        private final SharedPreferences prefs;
        NativeStore(SharedPreferences p) { prefs = p; }
        @JavascriptInterface public String get(String k) { return prefs.getString(k, null); }
        @JavascriptInterface public boolean set(String k, String v) { return prefs.edit().putString(k, v).commit(); }
    }

    @Override
    protected void onPause() {
        web.evaluateJavascript("window.__autosave && window.__autosave()", null);
        super.onPause();
        web.onPause();
    }

    @Override
    protected void onResume() { super.onResume(); web.onResume(); }
}
