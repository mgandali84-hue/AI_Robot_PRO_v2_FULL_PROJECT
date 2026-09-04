package com.airobot.pro;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.graphics.Path;
import android.view.accessibility.AccessibilityEvent;

public class RobotAccessibilityService extends AccessibilityService {
    private static RobotAccessibilityService instance;

    public static RobotAccessibilityService getInstance() { return instance; }

    @Override protected void onServiceConnected() {
        super.onServiceConnected();
        instance = this;
    }

    @Override public void onAccessibilityEvent(AccessibilityEvent event) {}
    @Override public void onInterrupt() {}
    @Override public boolean onUnbind(android.content.Intent intent) {
        instance = null;
        return super.onUnbind(intent);
    }

    public boolean home() { return performGlobalAction(GLOBAL_ACTION_HOME); }
    public boolean back() { return performGlobalAction(GLOBAL_ACTION_BACK); }
    public boolean recents() { return performGlobalAction(GLOBAL_ACTION_RECENTS); }
    public boolean notifications() { return performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS); }
}
