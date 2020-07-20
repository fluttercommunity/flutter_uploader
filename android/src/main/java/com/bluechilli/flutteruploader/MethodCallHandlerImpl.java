package com.bluechilli.flutteruploader;

import android.content.Context;
import android.text.TextUtils;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.Observer;
import androidx.work.BackoffPolicy;
import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkInfo;
import androidx.work.WorkInfo.State;
import androidx.work.WorkManager;
import androidx.work.WorkRequest;
import com.bluechilli.flutteruploader.plugin.StatusListener;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import java.io.BufferedReader;
import java.io.FileReader;
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

public class MethodCallHandlerImpl implements MethodCallHandler {

  /** Plugin registration. */
  private static final String TAG = "flutter_upload_task";

  private final Context context;
  private int connectionTimeout;

  @NonNull private final StatusListener statusListener;

  private Map<String, Boolean> completedTasks = new HashMap<>();
  private Map<String, String> tasks = new HashMap<>();
  private Gson gson = new Gson();
  private int taskIdKey = 0;

  private static final List<String> VALID_HTTP_METHODS = Arrays.asList("POST", "PUT", "PATCH");

  MethodCallHandlerImpl(Context context, int timeout, @NonNull StatusListener listener) {
    this.context = context;
    this.connectionTimeout = timeout;
    this.statusListener = listener;
  }

  static class UploadObserver implements Observer<List<WorkInfo>> {
    private final WeakReference<MethodCallHandlerImpl> plugin;

    UploadObserver(MethodCallHandlerImpl plugin) {
      this.plugin = new WeakReference<>(plugin);
    }

    @Override
    public void onChanged(List<WorkInfo> workInfoList) {
      MethodCallHandlerImpl plugin = this.plugin.get();

      if (plugin == null) {
        return;
      }

      for (WorkInfo info : workInfoList) {
        String id = info.getId().toString();
        final String tag = plugin.tasks.get(id);

        if (info.getState() == State.RUNNING) {
          Data progress = info.getProgress();
          Log.d(TAG, "progress update: " + progress.toString());
          Log.d(TAG, "progress update tag: " + info.getTags());
          plugin.statusListener.onUpdateProgress(
              null,
              info.getId().toString(),
              progress.getInt("status", -1),
              progress.getInt("progress", -1));
        }

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

                plugin.statusListener.onFailed(
                    tag, id, failedStatus, statusCode, code, errorMessage, details);
                break;
              case CANCELLED:
                plugin.statusListener.onFailed(
                    tag,
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
                String headerJson = outputData.getString(UploadWorker.EXTRA_HEADERS);
                if (headerJson != null) {
                  headers = plugin.gson.fromJson(headerJson, type);
                }

                String response = extractResponse(outputData);
                plugin.statusListener.onCompleted(tag, id, status, response, headers);
                break;
            }
          }
        }
      }
    }

    String extractResponse(Data outputData) {
      String response = outputData.getString(UploadWorker.EXTRA_RESPONSE);
      if (TextUtils.isEmpty(response)) {
        String responseFile = outputData.getString(UploadWorker.EXTRA_RESPONSE_FILE);
        if (!TextUtils.isEmpty(responseFile)) {
          StringBuilder buffer = new StringBuilder();

          try (BufferedReader br = new BufferedReader(new FileReader(responseFile))) {
            String st;
            while ((st = br.readLine()) != null) {
              buffer.append(st);
            }
            response = buffer.toString();

          } catch (Throwable ignored) {
            response = "";
          }
        }
      }

      return response;
    }
  }

  @Nullable private UploadObserver uploadObserver;

  @Override
  public void onMethodCall(MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "setBackgroundHandler":
        setBackgroundHandler(call, result);
        break;
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

  void setBackgroundHandler(MethodCall call, MethodChannel.Result result) {
    Long callbackHandle = call.argument("callbackHandle");
    if (callbackHandle != null) {
      SharedPreferenceHelper.saveCallbackDispatcherHandleKey(context, callbackHandle);
    }

    result.success(null);
  }

  void startObservers() {
    uploadObserver = new UploadObserver(this);
    WorkManager.getInstance(context).getWorkInfosByTagLiveData(TAG).observeForever(uploadObserver);
  }

  void stopObservers() {
    if (uploadObserver != null) {
      WorkManager.getInstance(context)
          .getWorkInfosByTagLiveData(TAG)
          .removeObserver(uploadObserver);
      uploadObserver = null;
    }
  }

  private void enqueue(MethodCall call, MethodChannel.Result result) {
    String url = call.argument("url");
    String method = call.argument("method");
    List<Map<String, String>> files = call.argument("files");
    Map<String, String> parameters = call.argument("data");
    Map<String, String> headers = call.argument("headers");
    Boolean showNotification = call.argument("show_notification");
    String tag = call.argument("tag");

    if (method == null) {
      method = "POST";
    }

    if (showNotification == null) {
      showNotification = false;
    }

    if (tag == null || files == null || files.isEmpty()) {
      result.error("invalid_call", "Invalid call parameters passed", null);
      return;
    }

    if (!VALID_HTTP_METHODS.contains(method.toUpperCase())) {
      result.error("invalid_method", "Method must be either POST | PUT | PATCH", null);
      return;
    }

    taskIdKey++;

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
    WorkManager.getInstance(context).enqueue(request);
    String taskId = request.getId().toString();
    if (!tasks.containsKey(taskId)) {
      tasks.put(taskId, tag);
    }
    result.success(taskId);
    statusListener.onUpdateProgress(tag, taskId, UploadStatus.ENQUEUED, 0);
  }

  private void enqueueBinary(MethodCall call, MethodChannel.Result result) {
    String url = call.argument("url");
    String method = call.argument("method");
    Map<String, String> files = call.argument("file");
    Map<String, String> headers = call.argument("headers");
    Boolean showNotification = call.argument("show_notification");
    String tag = call.argument("tag");

    if (method == null) {
      method = "POST";
    }

    if (showNotification == null) {
      showNotification = false;
    }

    if (tag == null || files == null || files.isEmpty()) {
      result.error("invalid_call", "Invalid call parameters passed", null);
      return;
    }

    if (!VALID_HTTP_METHODS.contains(method.toUpperCase())) {
      result.error("invalid_method", "Method must be either POST | PUT | PATCH", null);
      return;
    }

    taskIdKey++;

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
    WorkManager.getInstance(context).enqueue(request);
    String taskId = request.getId().toString();

    if (!tasks.containsKey(taskId)) {
      tasks.put(taskId, tag);
    }

    result.success(taskId);
    statusListener.onUpdateProgress(tag, taskId, UploadStatus.ENQUEUED, 0);
  }

  private void cancel(MethodCall call, MethodChannel.Result result) {
    String taskId = call.argument("task_id");
    WorkManager.getInstance(context).cancelWorkById(UUID.fromString(taskId));
    result.success(null);
  }

  private void cancelAll(MethodCall call, MethodChannel.Result result) {
    WorkManager.getInstance(context).cancelAllWorkByTag(TAG);
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
}
