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

  private EventChannel resultEventChannel;
  @Nullable private EventSink resultEventSink;

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
  public void onUpdateProgress(String tag, String id, int status, int progress) {
    final Map<String, Object> args = new HashMap<>();
    args.put("task_id", id);
    args.put("status", status);
    args.put("progress", progress);
    args.put("tag", tag);

    if (progressEventSink != null) {
      progressEventSink.success(args);
    }
  }

  @Override
  public void onFailed(
      String tag,
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
        details != null ? new ArrayList<>(Arrays.asList(details)) : Collections.emptyList());
    args.put("tag", tag);

    if (resultEventSink != null) {
      resultEventSink.success(args);
    }
  }

  @Override
  public void onCompleted(
      String tag, String id, int status, String response, @Nullable Map<String, String> headers) {
    Map<String, Object> args = new HashMap<>();
    args.put("task_id", id);
    args.put("status", status);
    args.put("statusCode", 200);
    args.put("message", response);
    args.put("headers", headers != null ? headers : Collections.emptyMap());
    args.put("tag", tag);

    if (resultEventSink != null) {
      resultEventSink.success(args);
    }
  }
}
