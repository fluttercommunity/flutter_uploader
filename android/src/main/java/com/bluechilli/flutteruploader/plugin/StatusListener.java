package com.bluechilli.flutteruploader.plugin;

import androidx.annotation.Nullable;
import java.util.Map;

public interface StatusListener {
  void onUpdateProgress(String tag, String id, int status, int progress);

  void onFailed(
      String tag,
      String id,
      int status,
      int statusCode,
      String code,
      String message,
      @Nullable String[] details);

  void onCompleted(
      String tag, String id, int status, String response, @Nullable Map<String, String> headers);
}
