package com.bluechilli.flutteruploader;

import android.util.Log;
import android.webkit.MimeTypeMap;

public class MimeTypeDetector {
  static final String TAG = "MimeTypeDetector";

  public static String detect(String url) {
    String type = "application/octet-stream";
    String extension = MimeTypeMap.getFileExtensionFromUrl(url);
    try {
      if (extension != null && !extension.isEmpty()) {
        type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.toLowerCase());
      }
    } catch (Exception ex) {
      Log.d(TAG, "getMimeType", ex);
    }

    return type;
  }
}
