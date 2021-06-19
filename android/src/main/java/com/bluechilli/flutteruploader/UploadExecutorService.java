package com.bluechilli.flutteruploader;

import android.content.Context;
import android.util.Log;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import com.bluechilli.flutteruploader.FlutterUploaderInitializer;

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