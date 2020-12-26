package com.bluechilli.flutteruploader;

import static com.bluechilli.flutteruploader.MethodCallHandlerImpl.FLUTTER_UPLOAD_WORK_TAG;

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
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** FlutterUploaderPlugin */
public class FlutterUploaderPlugin implements FlutterPlugin, StatusListener {

  private static final String CHANNEL_NAME = "flutter_uploader";
  private static final String PROGRESS_EVENT_CHANNEL_NAME = "flutter_uploader/events/progress";
  private static final String RESULT_EVENT_CHANNEL_NAME = "flutter_uploader/events/result";

  private MethodChannel channel;
  private MethodCallHandlerImpl methodCallHandler;
  private UploadObserver uploadObserver;

  private EventChannel progressEventChannel;
  private final CachingStreamHandler<Map<String, Object>> progressStreamHandler =
      new CachingStreamHandler<>();

  private EventChannel resultEventChannel;
  private final CachingStreamHandler<Map<String, Object>> resultStreamHandler =
      new CachingStreamHandler<>();
  private LiveData<List<WorkInfo>> workInfoLiveData;

  public static void registerWith(Registrar registrar) {
    final FlutterUploaderPlugin plugin = new FlutterUploaderPlugin();
    plugin.startListening(registrar.context(), registrar.messenger());
    registrar.addViewDestroyListener(
        view -> {
          plugin.stopListening(registrar.context());
          return false;
        });
  }

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    startListening(binding.getApplicationContext(), binding.getBinaryMessenger());
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    stopListening(binding.getApplicationContext());
  }

  private void startListening(Context context, BinaryMessenger messenger) {
    channel = new MethodChannel(messenger, CHANNEL_NAME);
    methodCallHandler = new MethodCallHandlerImpl(context, this);

    uploadObserver = new UploadObserver(this);
    workInfoLiveData =
        WorkManager.getInstance(context).getWorkInfosByTagLiveData(FLUTTER_UPLOAD_WORK_TAG);
    workInfoLiveData.observeForever(uploadObserver);

    channel.setMethodCallHandler(methodCallHandler);

    progressEventChannel = new EventChannel(messenger, PROGRESS_EVENT_CHANNEL_NAME);
    progressEventChannel.setStreamHandler(progressStreamHandler);

    resultEventChannel = new EventChannel(messenger, RESULT_EVENT_CHANNEL_NAME);
    resultEventChannel.setStreamHandler(resultStreamHandler);
  }

  private void stopListening(Context context) {
    channel.setMethodCallHandler(null);
    channel = null;

    if (uploadObserver != null) {
      workInfoLiveData.removeObserver(uploadObserver);
      workInfoLiveData = null;
      uploadObserver = null;
    }

    methodCallHandler = null;

    progressEventChannel.setStreamHandler(null);
    progressEventChannel = null;

    resultEventChannel.setStreamHandler(null);
    resultEventChannel = null;

    progressStreamHandler.clear();
    resultStreamHandler.clear();
  }

  @Override
  public void onEnqueued(String id) {
    Map<String, Object> args = new HashMap<>();
    args.put("taskId", id);
    args.put("status", UploadStatus.ENQUEUED);

    resultStreamHandler.add(id, args);
  }

  @Override
  public void onUpdateProgress(String id, int status, int progress) {
    final Map<String, Object> args = new HashMap<>();
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
    args.put(
        "details",
        details != null
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
    args.put("headers", headers != null ? headers : Collections.<String, Object>emptyMap());

    resultStreamHandler.add(id, args);
  }

  @Override
  public void onPaused(String id) {
    Map<String, Object> args = new HashMap<>();
    args.put("taskId", id);
    args.put("status", UploadStatus.PAUSED);

    resultStreamHandler.add(id, args);
  }

  @Override
  public void onWorkPruned() {
    progressStreamHandler.clear();
    resultStreamHandler.clear();
  }
}
