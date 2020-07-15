package com.bluechilli.flutteruploader.plugin;

import java.util.Map;

public interface StatusListener {
  void onUpdateProgress(String id, int status, int progress);

  void onFailed(
      String id, int status, int statusCode, String code, String message, String[] details);

  void onCompleted(String id, int status, String response, Map<String, Object> headers);
}
