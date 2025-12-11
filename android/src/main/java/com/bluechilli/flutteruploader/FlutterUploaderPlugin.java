package com.bluechilli.flutteruploader;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.LiveData;
import androidx.work.WorkInfo;
import androidx.work.WorkManager;

import com.bluechilli.flutteruploader.plugin.CachingStreamHandler;
import com.bluechilli.flutteruploader.plugin.StatusListener;
import com.bluechilli.flutteruploader.plugin.UploadObserver;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static com.bluechilli.flutteruploader.MethodCallHandlerImpl.FLUTTER_UPLOAD_WORK_TAG;

/** FlutterUploaderPlugin - Fully migrated to Flutter Android v2 embedding */
public class FlutterUploaderPlugin implements FlutterPlugin, StatusListener {

  private static final String CHANNEL_NAME = "flutter_uploader";
  private static final String PROGRESS_EVENT_CHANNEL_NAME = "flutter_uploader/events/progress";
  private static final String RESULT_EVENT_CHANNEL_NAME = "flutter_uploader/events/result";

  private @Nullable MethodChannel methodChannel;
  private @Nullable MethodCallHandlerImpl methodCallHandler;
  private @Nullable UploadObserver uploadObserver;
  private @Nullable LiveData<List<WorkInfo>> workInfoLiveData;

  private @Nullable EventChannel progressEventChannel;
  private final CachingStreamHandler<Map<String, Object>> progressStreamHandler =
      new CachingStreamHandler<>();

  private @Nullable EventChannel resultEventChannel;
  private final CachingStreamHandler<Map<String, Object>> resultStreamHandler =
      new CachingStreamHandler<>();

  // ---------- FlutterPlugin Lifecycle ----------

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    startListening(binding.getApplicationContext(), binding.getBinaryMessenger());
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    stopListening();
  }

  // ---------- Setup & Teardown ----------

  private void startListening(Context context, BinaryMessenger messenger) {
    final int timeout = FlutterUploaderInitializer.getConnectionTimeout(context);

    // Method channel
    methodChannel = new MethodChannel(messenger, CHANNEL_NAME);
    methodCallHandler = new MethodCallHandlerImpl(context, timeout, this);
    methodChannel.setMethodCallHandler(methodCallHandler);

    // Observe WorkManager uploads
    uploadObserver = new UploadObserver(this);
    workInfoLiveData = WorkManager.getInstance(context)
        .getWorkInfosByTagLiveData(FLUTTER_UPLOAD_WORK_TAG);
    workInfoLiveData.observeForever(uploadObserver);

    // Progress event channel
    progressEventChannel = new EventChannel(messenger, PROGRESS_EVENT_CHANNEL_NAME);
    progressEventChannel.setStreamHandler(progressStreamHandler);

    // Result event channel
    resultEventChannel = new EventChannel(messenger, RESULT_EVENT_CHANNEL_NAME);
    resultEventChannel.setStreamHandler(resultStreamHandler);
  }

  private void stopListening() {
    // Method channel
    if (methodChannel != null) {
      methodChannel.setMethodCallHandler(null);
      methodChannel = null;
    }
    methodCallHandler = null;

    // WorkManager observer
    if (uploadObserver != null && workInfoLiveData != null) {
      workInfoLiveData.removeObserver(uploadObserver);
      workInfoLiveData = null;
      uploadObserver = null;
    }

    // Event channels
    if (progressEventChannel != null) {
      progressEventChannel.setStreamHandler(null);
      progressEventChannel = null;
    }
    if (resultEventChannel != null) {
      resultEventChannel.setStreamHandler(null);
      resultEventChannel = null;
    }

    // Clear cached events
    progressStreamHandler.clear();
    resultStreamHandler.clear();
  }

  // ---------- StatusListener Callbacks ----------

  @Override
  public void onEnqueued(String id) {
    Map<String, Object> args = new HashMap<>();
    args.put("taskId", id);
    args.put("status", UploadStatus.ENQUEUED);
    resultStreamHandler.add(id, args);
  }

  @Override
  public void onUpdateProgress(String id, int status, int progress) {
    Map<String, Object> args = new HashMap<>();
    args.put("taskId", id);
    args.put("status", status);
    args.put("progress", progress);
    progressStreamHandler.add(id, args);
  }

  @Override
  public void onFailed(
      String id,
      int status,
      int statusCode,
      String code,
      String message,
      @Nullable String[] details) {

    Map<String, Object> args = new HashMap<>();
    args.put("taskId", id);
    args.put("status", status);
    args.put("statusCode", statusCode);
    args.put("code", code);
    args.put("message", message);
    args.put("details", details != null
        ? new ArrayList<>(Arrays.asList(details))
        : Collections.<String>emptyList());

    resultStreamHandler.add(id, args);
  }

  @Override
  public void onCompleted(
      String id,
      int status,
      int statusCode,
      String response,
      @Nullable Map<String, String> headers) {

    Map<String, Object> args = new HashMap<>();
    args.put("taskId", id);
    args.put("status", status);
    args.put("statusCode", statusCode);
    args.put("message", response);
    args.put("headers", headers != null ? headers : Collections.emptyMap());

    resultStreamHandler.add(id, args);
  }

  @Override
  public void onWorkPruned() {
    progressStreamHandler.clear();
    resultStreamHandler.clear();
  }
}