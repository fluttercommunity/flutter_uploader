package com.bluechilli.flutteruploaderexample;

import androidx.annotation.NonNull;
import androidx.work.Configuration;
import io.flutter.app.FlutterApplication;
import java.util.concurrent.Executors;

public class ExampleApplication extends FlutterApplication implements Configuration.Provider {

  // Example on how to configure WorkManager.
  // For more information, follow
  // https://developer.android.com/topic/libraries/architecture/workmanager/advanced/custom-configuration
  @NonNull
  @Override
  public Configuration getWorkManagerConfiguration() {
    return new Configuration.Builder()
        .setMinimumLoggingLevel(android.util.Log.INFO)
        .setExecutor(Executors.newFixedThreadPool(10))
        .build();
  }
}
