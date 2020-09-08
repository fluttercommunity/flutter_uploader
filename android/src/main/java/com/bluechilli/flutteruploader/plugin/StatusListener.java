package com.bluechilli.flutteruploader.plugin;

import androidx.annotation.Nullable;
import java.util.Map;

public interface StatusListener {
  void onEnqueued(String id);

  void onUpdateProgress(String id, int status, int progress);

  void onFailed(
      String id,
      int status,
      int statusCode,
      String code,
      String message,
      @Nullable String[] details);

  void onCompleted(
      String id,
      int status,
      int statusCode,
      String response,
      @Nullable Map<String, String> headers);

  void onCleared();
}
