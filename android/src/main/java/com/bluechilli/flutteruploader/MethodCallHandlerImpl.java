package com.bluechilli.flutteruploader;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import androidx.work.BackoffPolicy;
import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;
import androidx.work.WorkRequest;
import com.bluechilli.flutteruploader.plugin.StatusListener;
import com.google.gson.Gson;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class MethodCallHandlerImpl implements MethodCallHandler {

  /** The generic {@link WorkManager} tag which matches any upload. */
  public static final String FLUTTER_UPLOAD_WORK_TAG = "flutter_upload_task";

  private final Context context;

  private final int connectionTimeout;

  @NonNull private final StatusListener statusListener;

  private final Executor workManagerExecutor = Executors.newSingleThreadExecutor();
  private final Executor mainExecutor;

  private static final List<String> VALID_HTTP_METHODS = Arrays.asList("POST", "PUT", "PATCH");

  MethodCallHandlerImpl(Context context, int timeout, @NonNull StatusListener listener) {
    mainExecutor = ContextCompat.getMainExecutor(context);
    this.context = context;
    this.connectionTimeout = timeout;
    this.statusListener = listener;
  }

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
      case "clearUploads":
        clearUploads(call, result);
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

  private void enqueue(MethodCall call, MethodChannel.Result result) {
    String url = call.argument("url");
    String method = call.argument("method");
    List<Map<String, String>> files = call.argument("files");
    Map<String, String> parameters = call.argument("data");
    Map<String, String> headers = call.argument("headers");
    String tag = call.argument("tag");
    Boolean allowCellular = call.argument("allowCellular");
    if (allowCellular == null) {
      result.error("invalid_flag", "allowCellular must be set", null);
      return;
    }

    if (method == null) {
      method = "POST";
    }

    if (files == null || files.isEmpty()) {
      result.error("invalid_call", "Invalid call parameters passed", null);
      return;
    }

    if (!VALID_HTTP_METHODS.contains(method.toUpperCase())) {
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
                url,
                method,
                items,
                headers,
                parameters,
                connectionTimeout,
                false,
                tag,
                allowCellular));

    WorkManager.getInstance(context)
        .enqueue(request)
        .getResult()
        .addListener(
            () -> {
              String taskId = request.getId().toString();
              mainExecutor.execute(
                  () -> {
                    result.success(taskId);
                    statusListener.onUpdateProgress(taskId, UploadStatus.ENQUEUED, 0);
                  });
            },
            workManagerExecutor);
  }

  private void enqueueBinary(MethodCall call, MethodChannel.Result result) {
    String url = call.argument("url");
    String method = call.argument("method");
    String path = call.argument("path");
    Map<String, String> headers = call.argument("headers");
    String tag = call.argument("tag");
    Boolean allowCellular = call.argument("allowCellular");

    if (allowCellular == null) {
      result.error("invalid_flag", "allowCellular must be set", null);
      return;
    }

    if (method == null) {
      method = "POST";
    }

    if (path == null) {
      result.error("invalid_call", "Invalid call parameters passed", null);
      return;
    }

    if (!VALID_HTTP_METHODS.contains(method.toUpperCase())) {
      result.error("invalid_method", "Method must be either POST | PUT | PATCH", null);
      return;
    }

    WorkRequest request =
        buildRequest(
            new UploadTask(
                url,
                method,
                Collections.singletonList(new FileItem(path)),
                headers,
                Collections.emptyMap(),
                connectionTimeout,
                true,
                tag,
                allowCellular));

    WorkManager.getInstance(context)
        .enqueue(request)
        .getResult()
        .addListener(
            () -> {
              String taskId = request.getId().toString();
              mainExecutor.execute(
                  () -> {
                    result.success(taskId);
                    statusListener.onUpdateProgress(taskId, UploadStatus.ENQUEUED, 0);
                  });
            },
            workManagerExecutor);
  }

  private void cancel(MethodCall call, MethodChannel.Result result) {
    String taskId = call.argument("taskId");
    WorkManager.getInstance(context)
        .cancelWorkById(UUID.fromString(taskId))
        .getResult()
        .addListener(() -> mainExecutor.execute(() -> result.success(null)), workManagerExecutor);
  }

  private void cancelAll(MethodCall call, MethodChannel.Result result) {
    WorkManager.getInstance(context)
        .cancelAllWorkByTag(FLUTTER_UPLOAD_WORK_TAG)
        .getResult()
        .addListener(() -> mainExecutor.execute(() -> result.success(null)), workManagerExecutor);
  }

  private void clearUploads(MethodCall call, MethodChannel.Result result) {
    WorkManager.getInstance(context)
        .pruneWork()
        .getResult()
        .addListener(
            () -> {
              statusListener.onWorkPruned();
              mainExecutor.execute(() -> result.success(null));
            },
            workManagerExecutor);
  }

  private WorkRequest buildRequest(UploadTask task) {
    Gson gson = new Gson();

    Data.Builder dataBuilder =
        new Data.Builder()
            .putString(UploadWorker.ARG_URL, task.getURL())
            .putString(UploadWorker.ARG_METHOD, task.getMethod())
            .putInt(UploadWorker.ARG_REQUEST_TIMEOUT, task.getTimeout())
            .putBoolean(UploadWorker.ARG_BINARY_UPLOAD, task.isBinaryUpload())
            .putString(UploadWorker.ARG_UPLOAD_REQUEST_TAG, task.getTag());

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

    Constraints constraints =
        new Constraints.Builder()
            .setRequiredNetworkType(
                task.isAllowCellular() ? NetworkType.CONNECTED : NetworkType.UNMETERED)
            .build();
    return new OneTimeWorkRequest.Builder(UploadWorker.class)
        .setConstraints(constraints)
        .addTag(FLUTTER_UPLOAD_WORK_TAG)
        .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 5, TimeUnit.SECONDS)
        .setInputData(dataBuilder.build())
        .build();
  }
}
