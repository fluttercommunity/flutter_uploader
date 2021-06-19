package com.bluechilli.flutteruploader;

import android.content.Context;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class UploadExecutorService {
  private static ExecutorService executorService = null;

  public static ExecutorService getExecutorService(Context context) {
    if (executorService == null) {
      final int max = FlutterUploaderInitializer.getMaxConcurrentTaskMetadata(context);
      executorService = Executors.newFixedThreadPool(max);
    }
    return executorService;
  }
}
