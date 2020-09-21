package com.bluechilli.flutteruploader;

import android.content.Context;
import android.content.SharedPreferences;

public class SharedPreferenceHelper {
  private static final String SHARED_PREFS_FILE_NAME = "flutter_uploader_plugin";
  private static final String CALLBACK_DISPATCHER_HANDLE_KEY =
      "com.bluechilli.flutteruploader.CALLBACK_DISPATCHER_HANDLE_KEY";

  public static SharedPreferences get(Context context) {
    return context.getSharedPreferences(SHARED_PREFS_FILE_NAME, Context.MODE_PRIVATE);
  }

  public static void saveCallbackDispatcherHandleKey(Context context, Long callbackHandle) {
    get(context).edit().putLong(CALLBACK_DISPATCHER_HANDLE_KEY, callbackHandle).apply();
  }

  public static Long getCallbackHandle(Context context) {
    return get(context).getLong(CALLBACK_DISPATCHER_HANDLE_KEY, -1L);
  }

  public static boolean hasCallbackHandle(Context context) {
    return get(context).contains(CALLBACK_DISPATCHER_HANDLE_KEY);
  }
}
