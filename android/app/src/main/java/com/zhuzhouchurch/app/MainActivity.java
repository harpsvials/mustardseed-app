package com.zhuzhouchurch.app;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkInfo;
import android.os.Build;
import android.os.Bundle;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

import com.getcapacitor.BridgeActivity;
import com.getcapacitor.CapConfig;

import java.util.Locale;

public class MainActivity extends BridgeActivity {

    private AppTTS ttsBridge;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        // 纯本地优先：始终加载 App 内置的网页文件（assets/public），秒开不依赖网络；
        // 留言板 / 祷告墙等动态数据在联网时通过 https://zhuzhouchurch.com/api/... 读写线上数据库（Worker 已开放 CORS）
        super.onCreate(savedInstanceState);
        // 注入原生 TTS 桥：Android WebView 的 speechSynthesis 不可用，网页朗读走原生引擎
        try {
            ttsBridge = new AppTTS(this);
            WebView wv = getBridge().getWebView();
            wv.addJavascriptInterface(ttsBridge, "AndroidTTS");
        } catch (Exception ignored) {
        }
    }

    @Override
    public void onDestroy() {
        if (ttsBridge != null) {
            ttsBridge.shutdown();
        }
        super.onDestroy();
    }

    private boolean isOnline() {
        try {
            ConnectivityManager cm = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
            if (cm == null) {
                return false;
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Network network = cm.getActiveNetwork();
                if (network == null) {
                    return false;
                }
                NetworkCapabilities caps = cm.getNetworkCapabilities(network);
                return caps != null && caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
            } else {
                NetworkInfo activeNetwork = cm.getActiveNetworkInfo();
                return activeNetwork != null && activeNetwork.isConnected();
            }
        } catch (Exception e) {
            return false;
        }
    }

    /** 原生 TTS 桥：页面 JS 通过 window.AndroidTTS 朗读全文（逐句，onDone 回调驱动高亮跟读） */
    public static class AppTTS {

        private final MainActivity act;
        private TextToSpeech tts;
        private volatile boolean ready = false;

        AppTTS(MainActivity act) {
            this.act = act;
            tts = new TextToSpeech(act, new TextToSpeech.OnInitListener() {
                @Override
                public void onInit(int status) {
                    if (status == TextToSpeech.SUCCESS) {
                        ready = true;
                        tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                            @Override
                            public void onStart(String utteranceId) {
                                js("window.__ttsCb && window.__ttsCb('start', '" + utteranceId + "')");
                            }

                            @Override
                            public void onDone(String utteranceId) {
                                js("window.__ttsCb && window.__ttsCb('done', '" + utteranceId + "')");
                            }

                            @Override
                            public void onError(String utteranceId) {
                                js("window.__ttsCb && window.__ttsCb('error', '" + utteranceId + "')");
                            }
                        });
                    }
                }
            });
        }

        private void js(final String script) {
            act.runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    try {
                        act.getBridge().getWebView().evaluateJavascript(script, null);
                    } catch (Exception ignored) {
                    }
                }
            });
        }

        @JavascriptInterface
        public boolean isReady() {
            return ready;
        }

        @JavascriptInterface
        public void speak(String text, String bcpLang, float rate, float pitch) {
            if (!ready || text == null || text.isEmpty()) {
                return;
            }
            try {
                Locale loc = Locale.forLanguageTag(bcpLang);
                int r = tts.setLanguage(loc);
                if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
                    tts.setLanguage(Locale.getDefault());
                }
                tts.setSpeechRate(Math.max(0.5f, Math.min(2.0f, rate)));
                tts.setPitch(Math.max(0.5f, Math.min(2.0f, pitch)));
                String id = "u" + System.currentTimeMillis();
                Bundle params = new Bundle();
                params.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, id);
                tts.speak(text, TextToSpeech.QUEUE_FLUSH, params, id);
            } catch (Exception ignored) {
            }
        }

        @JavascriptInterface
        public void stop() {
            try {
                if (tts != null) {
                    tts.stop();
                }
            } catch (Exception ignored) {
            }
        }

        public void shutdown() {
            try {
                if (tts != null) {
                    tts.stop();
                    tts.shutdown();
                }
            } catch (Exception ignored) {
            }
        }
    }
}
