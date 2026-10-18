package com.zhuzhouchurch.app;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Bundle;

import com.getcapacitor.BridgeActivity;
import com.getcapacitor.CapConfig;

public class MainActivity extends BridgeActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        // 联网时加载线上最新网站，离线时使用内置资源（离线优先混合方案）
        if (isOnline()) {
            CapConfig.Builder configBuilder = new CapConfig.Builder(getApplicationContext());
            configBuilder.setServerUrl("https://www.zhuzhouchurch.com");
            this.config = configBuilder.create();
        }
        super.onCreate(savedInstanceState);
    }

    private boolean isOnline() {
        try {
            ConnectivityManager cm = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
            NetworkInfo activeNetwork = cm.getActiveNetworkInfo();
            return activeNetwork != null && activeNetwork.isConnected();
        } catch (Exception e) {
            return false;
        }
    }
}
