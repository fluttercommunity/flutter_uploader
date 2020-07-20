package com.bluechilli.flutteruploader;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.bluechilli.flutteruploader.plugin.StatusListener;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;
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

  private EventChannel progressEventChannel;
  @Nullable private EventSink progressEventSink;
  List<Map<String, Object>> cachedProgress = new ArrayList<>();

  private EventChannel resultEventChannel;
  @Nullable private EventSink resultEventSink;
  List<Map<String, Object>> cachedResults = new ArrayList<>();

  public static void registerWith(Registrar registrar) {
    final FlutterUploaderPlugin plugin = new FlutterUploaderPlugin();
    plugin.startListening(registrar.context(), registrar.messenger());
  }

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    startListening(binding.getApplicationContext(), binding.getBinaryMessenger());
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    stopListening();
  }

  private void startListening(Context context, BinaryMessenger messenger) {
    final int timeout = FlutterUploaderInitializer.getConnectionTimeout(context);

    channel = new MethodChannel(messenger, CHANNEL_NAME);
    methodCallHandler = new MethodCallHandlerImpl(context, timeout, this);
    methodCallHandler.startObservers();
    channel.setMethodCallHandler(methodCallHandler);

    progressEventChannel = new EventChannel(messenger, PROGRESS_EVENT_CHANNEL_NAME);
    progressEventChannel.setStreamHandler(
        new StreamHandler() {
          @Override
          public void onListen(Object arguments, EventSink events) {
            progressEventSink = events;
            if (!cachedProgress.isEmpty()) {
              for (Map<String, Object> item : cachedProgress) {
                events.success(item);
              }
              cachedProgress.clear();
            }
          }

          @Override
          public void onCancel(Object arguments) {
            progressEventSink = null;
          }
        });

    resultEventChannel = new EventChannel(messenger, RESULT_EVENT_CHANNEL_NAME);
    resultEventChannel.setStreamHandler(
        new StreamHandler() {
          @Override
          public void onListen(Object arguments, EventSink events) {
            resultEventSink = events;
            if (!cachedResults.isEmpty()) {
              for (Map<String, Object> item : cachedResults) {
                events.success(item);
              }
              cachedResults.clear();
            }
          }

          @Override
          public void onCancel(Object arguments) {
            resultEventSink = null;
          }
        });
  }

  private void stopListening() {
    channel.setMethodCallHandler(null);
    channel = null;

    methodCallHandler.stopObservers();
    methodCallHandler = null;

    progressEventChannel.setStreamHandler(null);
    progressEventChannel = null;

    resultEventChannel.setStreamHandler(null);
    resultEventChannel = null;
  }

  @Override
  public void onUpdateProgress(String id, int status, int progress) {
    final Map<String, Object> args = new HashMap<>();
    args.put("task_id", id);
    args.put("status", status);
    args.put("progress", progress);

    if (progressEventSink != null) {
      progressEventSink.success(args);
    } else {
      cachedProgress.add(args);
    }
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
    args.put("task_id", id);
    args.put("status", status);
    args.put("statusCode", statusCode);
    args.put("code", code);
    args.put("message", message);
    args.put(
        "details",
        details != null ? new ArrayList<>(Arrays.asList(details)) : Collections.<String>emptyList());

    if (resultEventSink != null) {
      resultEventSink.success(args);
    } else {
      cachedResults.add(args);
    }
  }

  @Override
  public void onCompleted(
      String id, int status, int statusCode, String response, @Nullable Map<String, String> headers) {
    Map<String, Object> args = new HashMap<>();
    args.put("task_id", id);
    args.put("status", status);
    args.put("statusCode", statusCode);
    args.put("message", response);
    args.put("headers", headers != null ? headers : Collections.<String, Object>emptyMap());

    if (resultEventSink != null) {
      resultEventSink.success(args);
    } else {
      cachedResults.add(args);
    }
  }
}
