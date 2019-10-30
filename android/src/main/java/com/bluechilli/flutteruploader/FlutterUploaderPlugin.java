package com.bluechilli.flutteruploader;

import android.app.Activity;
import android.app.Application;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.Observer;
import androidx.work.BackoffPolicy;
import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkInfo;
import androidx.work.WorkManager;
import androidx.work.WorkRequest;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.lang.ref.WeakReference;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

/** FlutterUploaderPlugin */
public class FlutterUploaderPlugin
    implements MethodCallHandler, Application.ActivityLifecycleCallbacks {
  /** Plugin registration. */
  private static final String TAG = "flutter_upload_task";

  private static final String CHANNEL_NAME = "flutter_uploader";

  private final MethodChannel channel;
  private final Registrar register;
  private int connectionTimeout = 3600;
  private Map<String, Boolean> completedTasks = new HashMap<>();
  private Map<String, String> tasks = new HashMap<>();
  private Gson gson = new Gson();
  private int taskIdKey = 0;
  private final String[] validHttpMethods = new String[] {"POST", "PUT", "PATCH"};

  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), CHANNEL_NAME);
    final FlutterUploaderPlugin plugin = new FlutterUploaderPlugin(registrar, channel);
    channel.setMethodCallHandler(plugin);

    if (registrar.activity() != null) {
      registrar.activity().getApplication().registerActivityLifecycleCallbacks(plugin);
    }
  }

  private FlutterUploaderPlugin(Registrar registrar, MethodChannel channel) {
    this.channel = channel;
    this.register = registrar;
    this.connectionTimeout = FlutterUploaderInitializer.getConnectionTimeout(registrar.context());
  }

  static class UploadProgressObserver implements Observer<UploadProgress> {

    private final WeakReference<FlutterUploaderPlugin> plugin;

    UploadProgressObserver(FlutterUploaderPlugin plugin) {
      this.plugin = new WeakReference<>(plugin);
    }

    @Override
    public void onChanged(UploadProgress uploadProgress) {
      FlutterUploaderPlugin plugin = this.plugin.get();

      if (plugin == null) {
        return;
      }

      String id = uploadProgress.getTaskId();
      int progress = uploadProgress.getProgress();
      int status = uploadProgress.getStatus();
      plugin.sendUpdateProgress(id, status, progress);
    }
  }

  @Nullable private UploadProgressObserver uploadProgressObserver;

  static class UploadCompletedObserver implements Observer<List<WorkInfo>> {
    private final WeakReference<FlutterUploaderPlugin> plugin;

    UploadCompletedObserver(FlutterUploaderPlugin plugin) {
      this.plugin = new WeakReference<>(plugin);
    }

    @Override
    public void onChanged(List<WorkInfo> workInfoList) {
      FlutterUploaderPlugin plugin = this.plugin.get();

      if (plugin == null) {
        return;
      }

      for (WorkInfo info : workInfoList) {
        String id = info.getId().toString();
        if (!plugin.completedTasks.containsKey(id)) {
          if (info.getState().isFinished()) {
            plugin.completedTasks.put(id, true);
            Data outputData = info.getOutputData();

            switch (info.getState()) {
              case FAILED:
                int failedStatus =
                    outputData.getInt(UploadWorker.EXTRA_STATUS, UploadStatus.FAILED);
                int statusCode = outputData.getInt(UploadWorker.EXTRA_STATUS_CODE, 500);
                String code = outputData.getString(UploadWorker.EXTRA_ERROR_CODE);
                String errorMessage = outputData.getString(UploadWorker.EXTRA_ERROR_MESSAGE);
                String[] details = outputData.getStringArray(UploadWorker.EXTRA_ERROR_DETAILS);
                plugin.sendFailed(id, failedStatus, statusCode, code, errorMessage, details);
                break;
              case CANCELLED:
                plugin.sendFailed(
                    id,
                    UploadStatus.CANCELED,
                    500,
                    "flutter_upload_cancelled",
                    "upload has been cancelled",
                    null);
                break;
              case SUCCEEDED:
                int status = outputData.getInt(UploadWorker.EXTRA_STATUS, UploadStatus.COMPLETE);
                Map<String, String> headers = null;
                Type type = new TypeToken<Map<String, String>>() {}.getType();
                String headerJson = info.getOutputData().getString(UploadWorker.EXTRA_HEADERS);
                if (headerJson != null) {
                  headers = plugin.gson.fromJson(headerJson, type);
                }

                String response = info.getOutputData().getString(UploadWorker.EXTRA_RESPONSE);
                plugin.sendCompleted(id, status, response, headers);
                break;
            }
          }
        }
      }
    }
  }

  @Nullable private UploadCompletedObserver uploadCompletedObserver;

  @Override
  public void onMethodCall(MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "enqueue":
        enqueue(call, result);
        break;
      case "enqueueBinary":
        enqueueBinary(call, result);
        break;
      case "cancel":
        cancel(call, result);
        break;
      case "cancelAll":
        cancelAll(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  @Override
  public void onActivityCreated(Activity activity, Bundle savedInstanceState) {}

  @Override
  public void onActivityStarted(Activity activity) {
    if (activity == register.activity()) {
      uploadProgressObserver = new UploadProgressObserver(this);
      UploadProgressReporter.getInstance().observeForever(uploadProgressObserver);

      uploadCompletedObserver = new UploadCompletedObserver(this);
      WorkManager.getInstance(register.context())
          .getWorkInfosByTagLiveData(TAG)
          .observeForever(uploadCompletedObserver);
    }
  }

  @Override
  public void onActivityResumed(Activity activity) {}

  @Override
  public void onActivityPaused(Activity activity) {}

  @Override
  public void onActivityStopped(Activity activity) {
    if (activity == register.activity()) {
      if (uploadProgressObserver != null) {
        UploadProgressReporter.getInstance().removeObserver(uploadProgressObserver);
        uploadProgressObserver = null;
      }

      if (uploadCompletedObserver != null) {
        WorkManager.getInstance(register.context())
            .getWorkInfosByTagLiveData(TAG)
            .removeObserver(uploadCompletedObserver);
        uploadCompletedObserver = null;
      }
    }
  }

  @Override
  public void onActivitySaveInstanceState(Activity activity, Bundle outState) {}

  @Override
  public void onActivityDestroyed(Activity activity) {
    if (activity == register.activity()) {
      activity.getApplication().unregisterActivityLifecycleCallbacks(this);
    }
  }

  private void enqueue(MethodCall call, MethodChannel.Result result) {
    taskIdKey++;
    String url = call.argument("url");
    String method = call.argument("method");
    List<Map<String, String>> files = call.argument("files");
    Map<String, String> parameters = call.argument("data");
    Map<String, String> headers = call.argument("headers");
    boolean showNotification = call.argument("show_notification");
    String tag = call.argument("tag");

    List<String> methods = Arrays.asList(validHttpMethods);

    if (method == null) {
      method = "POST";
    }

    if (!methods.contains(method.toUpperCase())) {
      result.error("invalid_method", "Method must be either POST | PUT | PATCH", null);
      return;
    }

    List<FileItem> items = new ArrayList<>();

    for (Map<String, String> file : files) {
      items.add(FileItem.fromJson(file));
    }

    WorkRequest request =
        buildRequest(
            new UploadTask(
                taskIdKey,
                url,
                method,
                items,
                headers,
                parameters,
                connectionTimeout,
                showNotification,
                false,
                tag));
    WorkManager.getInstance(register.context()).enqueue(request);
    String taskId = request.getId().toString();
    if (!tasks.containsKey(taskId)) {
      tasks.put(taskId, tag);
    }
    result.success(taskId);
    sendUpdateProgress(taskId, UploadStatus.ENQUEUED, 0);
  }

  private void enqueueBinary(MethodCall call, MethodChannel.Result result) {
    taskIdKey++;
    String url = call.argument("url");
    String method = call.argument("method");
    Map<String, String> files = call.argument("file");
    Map<String, String> headers = call.argument("headers");
    boolean showNotification = call.argument("show_notification");
    String tag = call.argument("tag");

    List<String> methods = Arrays.asList(validHttpMethods);

    if (method == null) {
      method = "POST";
    }

    if (!methods.contains(method.toUpperCase())) {
      result.error("invalid_method", "Method must be either POST | PUT | PATCH", null);
      return;
    }

    WorkRequest request =
        buildRequest(
            new UploadTask(
                taskIdKey,
                url,
                method,
                Collections.singletonList(FileItem.fromJson(files)),
                headers,
                Collections.emptyMap(),
                connectionTimeout,
                showNotification,
                true,
                tag));
    WorkManager.getInstance(register.context()).enqueue(request);
    String taskId = request.getId().toString();

    if (!tasks.containsKey(taskId)) {
      tasks.put(taskId, tag);
    }

    result.success(taskId);
    sendUpdateProgress(taskId, UploadStatus.ENQUEUED, 0);
  }

  private void cancel(MethodCall call, MethodChannel.Result result) {
    String taskId = call.argument("task_id");
    WorkManager.getInstance(register.context()).cancelWorkById(UUID.fromString(taskId));
    result.success(null);
  }

  private void cancelAll(MethodCall call, MethodChannel.Result result) {
    WorkManager.getInstance(register.context()).cancelAllWorkByTag(TAG);
    result.success(null);
  }

  private WorkRequest buildRequest(UploadTask task) {
    Gson gson = new Gson();

    Data.Builder dataBuilder =
        new Data.Builder()
            .putString(UploadWorker.ARG_URL, task.getURL())
            .putString(UploadWorker.ARG_METHOD, task.getMethod())
            .putInt(UploadWorker.ARG_REQUEST_TIMEOUT, task.getTimeout())
            .putBoolean(UploadWorker.ARG_SHOW_NOTIFICATION, task.canShowNotification())
            .putBoolean(UploadWorker.ARG_BINARY_UPLOAD, task.isBinaryUpload())
            .putString(UploadWorker.ARG_UPLOAD_REQUEST_TAG, task.getTag())
            .putInt(UploadWorker.ARG_ID, task.getId());

    List<FileItem> files = task.getFiles();

    String fileItemsJson = gson.toJson(files);
    dataBuilder.putString(UploadWorker.ARG_FILES, fileItemsJson);

    if (task.getHeaders() != null) {
      String headersJson = gson.toJson(task.getHeaders());
      dataBuilder.putString(UploadWorker.ARG_HEADERS, headersJson);
    }

    if (task.getParameters() != null) {
      String parametersJson = gson.toJson(task.getParameters());
      dataBuilder.putString(UploadWorker.ARG_DATA, parametersJson);
    }

    return new OneTimeWorkRequest.Builder(UploadWorker.class)
        .setConstraints(
            new Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
        .addTag(TAG)
        .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 5, TimeUnit.SECONDS)
        .setInputData(dataBuilder.build())
        .build();
  }

  private void sendUpdateProgress(String id, int status, int progress) {
    String tag = tasks.get(id);
    Map<String, Object> args = new HashMap<>();
    args.put("task_id", id);
    args.put("status", status);
    args.put("progress", progress);
    args.put("tag", tag);
    channel.invokeMethod("updateProgress", args);
  }

  private void sendFailed(
      String id, int status, int statusCode, String code, String message, String[] details) {

    String tag = tasks.get(id);
    Map<String, Object> args = new HashMap<>();
    args.put("task_id", id);
    args.put("status", status);
    args.put("statusCode", statusCode);
    args.put("code", code);
    args.put("message", message);
    args.put("details", details != null ? new ArrayList<>(Arrays.asList(details)) : null);
    args.put("tag", tag);
    channel.invokeMethod("uploadFailed", args);
  }

  private void sendCompleted(String id, int status, String response, Map headers) {
    String tag = tasks.get(id);
    Map<String, Object> args = new HashMap<>();
    args.put("task_id", id);
    args.put("status", status);
    args.put("statusCode", 200);
    args.put("message", response);
    args.put("headers", headers);
    args.put("tag", tag);
    channel.invokeMethod("uploadCompleted", args);
  }
}
