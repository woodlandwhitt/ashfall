package com.ashfall.meridian;

import android.app.Activity;
import android.content.SharedPreferences;
import android.webkit.JavascriptInterface;
import android.speech.tts.TextToSpeech;
import android.speech.tts.Voice;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import android.os.Bundle;
import android.view.View;
import android.view.WindowManager;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public class MainActivity extends Activity {
    private WebView web;
    private TextToSpeech tts;
    private final List<Voice> femVoices = new ArrayList<>(), maleVoices = new ArrayList<>();
    private boolean ttsReady = false;

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
        tts = new TextToSpeech(this, status -> {
            if (status != TextToSpeech.SUCCESS) return;
            tts.setLanguage(Locale.US);
            try {
                // Google voice ids: these codes are male, the rest female
                for (Voice v : tts.getVoices()) {
                    if (v.getLocale() == null || !"en".equals(v.getLocale().getLanguage()) || v.isNetworkConnectionRequired()) continue;
                    String n = v.getName().toLowerCase(Locale.US);
                    boolean male = (n.contains("male") && !n.contains("female")) || n.contains("-iol") || n.contains("-iom") || n.contains("-tpd") || n.contains("-rjs") || n.contains("-gbd") || n.contains("-end");
                    if (male) maleVoices.add(v);
                    else femVoices.add(v);
                }
            } catch (Exception ignored) {}
            ttsReady = true;
        });
        web.addJavascriptInterface(new NativeVoice(), "NativeVoice");
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

    // Lets the game speak NPC lines through Android's text-to-speech.
    class NativeVoice {
        @JavascriptInterface public void speak(String text, float pitch, float rate, boolean fem, float volume, int seed) {
            if (!ttsReady) return;
            List<Voice> pool = fem ? (femVoices.isEmpty() ? maleVoices : femVoices) : (maleVoices.isEmpty() ? femVoices : maleVoices);
            if (!pool.isEmpty()) tts.setVoice(pool.get(Math.abs(seed) % pool.size()));
            tts.setPitch(Math.max(.3f, Math.min(2f, pitch)));
            tts.setSpeechRate(Math.max(.5f, Math.min(2f, rate)));
            Bundle b = new Bundle();
            b.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, Math.max(0f, Math.min(1f, volume)));
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, b, "line");
        }
        @JavascriptInterface public void stop() { if (tts != null) tts.stop(); }
    }

    @Override
    protected void onDestroy() { if (tts != null) tts.shutdown(); super.onDestroy(); }

    @Override
    protected void onPause() {
        if (tts != null) tts.stop();
        web.evaluateJavascript("window.__autosave && window.__autosave()", null);
        super.onPause();
        web.onPause();
    }

    @Override
    protected void onResume() { super.onResume(); web.onResume(); }
}
