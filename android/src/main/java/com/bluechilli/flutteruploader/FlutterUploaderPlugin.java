package com.bluechilli.flutteruploader;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.bluechilli.flutteruploader.plugin.StatusListener;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

/** FlutterUploaderPlugin */
public class FlutterUploaderPlugin implements FlutterPlugin, ActivityAware, StatusListener {

  private static final String CHANNEL_NAME = "flutter_uploader";
  private MethodChannel channel;
  private MethodCallHandlerImpl methodCallHandler;

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

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity();
  }

  @Override
  public void onDetachedFromActivity() {
    methodCallHandler.stopObservers();
  }

  private void onAttachedToActivity() {
    methodCallHandler.startObservers();
  }

  private void startListening(Context context, BinaryMessenger messenger) {
    final int timeout = FlutterUploaderInitializer.getConnectionTimeout(context);
    channel = new MethodChannel(messenger, CHANNEL_NAME);
    methodCallHandler = new MethodCallHandlerImpl(context, timeout, this);

    channel.setMethodCallHandler(methodCallHandler);
  }

  private void stopListening() {
    channel.setMethodCallHandler(null);
    methodCallHandler = null;
  }

  @Override
  public void onUpdateProgress(String tag, String id, int status, int progress) {
    Map<String, Object> args = new HashMap<>();
    args.put("task_id", id);
    args.put("status", status);
    args.put("progress", progress);
    args.put("tag", tag);
    channel.invokeMethod("updateProgress", args);
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
    channel.invokeMethod("uploadFailed", args);
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
    channel.invokeMethod("uploadCompleted", args);
  }
}
