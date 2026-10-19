package com.zhuzhouchurch.app;

import android.app.AlertDialog;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

import com.getcapacitor.BridgeActivity;
import com.getcapacitor.CapConfig;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class MainActivity extends BridgeActivity {

    private AppTTS ttsBridge;

    /* 待发通知（等待用户授权通知权限后弹出） */
    private String pendingNoticeTitle = null;
    private String pendingNoticeMessage = null;
    private int pendingNoticeId = 0;
    private SharedPreferences pendingNoticePrefs = null;

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
        // 延迟检查 GitHub 新版本（后台线程，不阻塞启动）
        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
            @Override
            public void run() {
                checkForUpdate();
            }
        }, 3000);
        // 延迟拉取教会最新通知（后台线程，启动即检查；5 秒和 15 秒各查一次，兼顾慢网络）
        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
            @Override
            public void run() {
                checkForNotice();
            }
        }, 5000);
        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
            @Override
            public void run() {
                checkForNotice();
            }
        }, 15000);
    }

    /** 自动检查更新：读取 GitHub 最新 Release 版本号，比内置版本高则弹窗提示 */
    private void checkForUpdate() {
        final int curCode;
        try {
            curCode = getPackageManager().getPackageInfo(getPackageName(), 0).versionCode;
        } catch (Exception ignored) {
            return;
        }
        if (curCode <= 1) return;
        final SharedPreferences prefs = getSharedPreferences("app_updates", MODE_PRIVATE);
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    URL url = new URL("https://api.github.com/repos/harpsvials/mustardseed-app/releases/latest");
                    HttpURLConnection c = (HttpURLConnection) url.openConnection();
                    c.setConnectTimeout(8000);
                    c.setReadTimeout(8000);
                    c.setRequestProperty("User-Agent", "mustardseed-app");
                    c.setRequestProperty("Accept", "application/vnd.github+json");
                    if (c.getResponseCode() != 200) return;
                    InputStream is = c.getInputStream();
                    BufferedReader br = new BufferedReader(new InputStreamReader(is, "UTF-8"));
                    StringBuilder sb = new StringBuilder();
                    String line;
                    while ((line = br.readLine()) != null) sb.append(line);
                    Matcher m = Pattern.compile("\"tag_name\":\"v([\\d.]+)\"").matcher(sb.toString());
                    if (!m.find()) return;
                    final String latestTag = m.group(1);
                    String curName = "";
                    try {
                        curName = getPackageManager().getPackageInfo(getPackageName(), 0).versionName;
                    } catch (Exception ignored) {
                    }
                    if (curName.startsWith("v")) curName = curName.substring(1);
                    if (compareVersion(latestTag, curName) <= 0) return;
                    if (latestTag.equals(prefs.getString("ignored_version", ""))) return;
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            showUpdateDialog(latestTag, prefs);
                        }
                    });
                } catch (Exception ignored) {
                }
            }
        }).start();
    }

    /** 版本号比较："2026.10.19.1953" 形式，逐段数字比较，避免整串转 int 溢出 */
    private int compareVersion(String a, String b) {
        try {
            String[] as = a.split("\\.");
            String[] bs = b.split("\\.");
            int n = Math.max(as.length, bs.length);
            for (int i = 0; i < n; i++) {
                long x = i < as.length ? Long.parseLong(as[i]) : 0;
                long y = i < bs.length ? Long.parseLong(bs[i]) : 0;
                if (x != y) return x < y ? -1 : 1;
            }
            return 0;
        } catch (Exception e) {
            return 0;
        }
    }

    /** 拉取式通知：读取 GitHub 仓库根目录 notice.json，有新消息则在通知栏弹出（每次打开 App 检查一次） */
    private void checkForNotice() {
        if (!isOnline()) {
            android.util.Log.i("ChurchNotice", "checkForNotice: 网络不可用，跳过");
            return;
        }
        final SharedPreferences prefs = getSharedPreferences("app_notices", MODE_PRIVATE);
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    /* 多源拉取：优先 api.github.com（大陆可访问），失败再走 jsDelivr CDN（有国内节点） */
                    String json = httpGet("https://api.github.com/repos/harpsvials/mustardseed-app/contents/notice.json",
                            "application/vnd.github.raw");
                    android.util.Log.i("ChurchNotice", "api.github.com 拉取结果: " + (json != null ? "成功(" + json.length() + "字符)" : "失败"));
                    if (json == null) {
                        json = httpGet("https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/notice.json", null);
                        android.util.Log.i("ChurchNotice", "jsDelivr 拉取结果: " + (json != null ? "成功(" + json.length() + "字符)" : "失败"));
                    }
                    if (json == null) return;
                    JSONObject root = new JSONObject(json);
                    JSONArray arr = root.optJSONArray("notices");
                    if (arr == null || arr.length() == 0) return;
                    JSONObject last = arr.getJSONObject(arr.length() - 1);
                    final int id = last.optInt("id", 0);
                    if (id <= 0) return;
                    final int lastId = prefs.getInt("last_notice_id", 0);
                    android.util.Log.i("ChurchNotice", "最新通知 id=" + id + "，已处理 id=" + lastId);
                    if (id <= lastId) return;
                    final String title = last.optString("title", "芥菜种教会");
                    final String message = last.optString("message", "教会发布了一条新通知");
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            showNoticeNotification(title, message, id, prefs);
                        }
                    });
                } catch (Exception e) {
                    android.util.Log.i("ChurchNotice", "拉取异常: " + e.toString());
                }
            }
        }).start();
    }

    /** 简单的 HTTP GET 工具：成功返回响应文本，失败返回 null */
    private String httpGet(String urlStr, String accept) {
        try {
            URL url = new URL(urlStr);
            HttpURLConnection c = (HttpURLConnection) url.openConnection();
            c.setConnectTimeout(8000);
            c.setReadTimeout(8000);
            c.setRequestProperty("User-Agent", "mustardseed-app");
            if (accept != null) c.setRequestProperty("Accept", accept);
            if (c.getResponseCode() != 200) return null;
            InputStream is = c.getInputStream();
            BufferedReader br = new BufferedReader(new InputStreamReader(is, "UTF-8"));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) sb.append(line);
            return sb.toString();
        } catch (Exception e) {
            return null;
        }
    }

    /** 弹出通知；Android 13+ 未授权时先请求权限，授权成功后再真正弹出 */
    private void showNoticeNotification(String title, String message, int id, SharedPreferences prefs) {
        try {
            if (Build.VERSION.SDK_INT >= 33
                    && checkSelfPermission("android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED) {
                /* 未授权：保存待发通知，请求权限；不标记已读，授权成功后再弹 */
                pendingNoticeTitle = title;
                pendingNoticeMessage = message;
                pendingNoticeId = id;
                pendingNoticePrefs = prefs;
                requestPermissions(new String[]{"android.permission.POST_NOTIFICATIONS"}, 1001);
                return;
            }
            /* 已授权（或系统版本 < 33）：真正弹出并标记已读 */
            deliverNotice(title, message, id, prefs);
        } catch (Exception ignored) {
        }
    }

    private void deliverNotice(String title, String message, int id, SharedPreferences prefs) {
        try {
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm == null) return;
            String chId = "church_notices";
            if (Build.VERSION.SDK_INT >= 26) {
                NotificationChannel ch = new NotificationChannel(chId, "教会通知", NotificationManager.IMPORTANCE_DEFAULT);
                ch.setDescription("芥菜种教会 App 发布的最新通知");
                nm.createNotificationChannel(ch);
            }
            Intent intent = new Intent(this, MainActivity.class);
            PendingIntent pi = PendingIntent.getActivity(this, 0, intent,
                    PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
            Notification.Builder builder;
            if (Build.VERSION.SDK_INT >= 26) {
                builder = new Notification.Builder(this, chId);
            } else {
                builder = new Notification.Builder(this);
            }
            Notification n = builder
                    .setContentTitle(title)
                    .setContentText(message)
                    .setSmallIcon(R.drawable.ic_notify)
                    .setAutoCancel(true)
                    .setContentIntent(pi)
                    .build();
            nm.notify(1002, n);
            /* 只有真正弹出通知（或已获授权）才标记已读，避免消息丢失 */
            prefs.edit().putInt("last_notice_id", id).apply();
        } catch (Exception ignored) {
        }
    }

    /** 通知权限请求结果：授权成功则补发待发通知；拒绝则标记已读（避免每次打开都重复请求权限） */
    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        try {
            if (requestCode != 1001) return;
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                if (pendingNoticeId > 0 && pendingNoticePrefs != null) {
                    deliverNotice(pendingNoticeTitle, pendingNoticeMessage, pendingNoticeId, pendingNoticePrefs);
                }
            } else {
                if (pendingNoticeId > 0 && pendingNoticePrefs != null) {
                    pendingNoticePrefs.edit().putInt("last_notice_id", pendingNoticeId).apply();
                }
            }
            pendingNoticeTitle = null;
            pendingNoticeMessage = null;
            pendingNoticeId = 0;
            pendingNoticePrefs = null;
        } catch (Exception ignored) {
        }
    }

    private void showUpdateDialog(final String latestTag, final SharedPreferences prefs) {
        try {
            new AlertDialog.Builder(this)
                .setTitle("发现新版本 v" + latestTag)
                .setMessage("检测到芥菜种教会 App 有新版本，是否前往下载更新？")
                .setPositiveButton("立即更新", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface d, int w) {
                        try {
                            Intent i = new Intent(Intent.ACTION_VIEW,
                                Uri.parse("https://github.com/harpsvials/mustardseed-app/releases/download/v" + latestTag + "/app-release.apk"));
                            startActivity(i);
                        } catch (Exception e) {
                            prefs.edit().putString("ignored_version", latestTag).apply();
                        }
                    }
                })
                .setNegativeButton("以后再说", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface d, int w) {
                        prefs.edit().putString("ignored_version", latestTag).apply();
                    }
                })
                .setCancelable(true)
                .setOnCancelListener(new DialogInterface.OnCancelListener() {
                    @Override
                    public void onCancel(DialogInterface d) {
                        prefs.edit().putString("ignored_version", latestTag).apply();
                    }
                })
                .show();
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
                /* 放宽判断：有活动网络即视为在线（避免受限/共享网络缺 INTERNET 能力被误判离线）；
                   真正的请求失败由 httpGet 的异常捕获兜底 */
                return caps != null;
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
