package com.bluechilli.flutteruploader;

import android.app.Activity;
import android.app.Application;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.util.Log;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.lang.reflect.Array;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

import androidx.lifecycle.Observer;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import androidx.work.BackoffPolicy;
import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkInfo;
import androidx.work.WorkManager;
import androidx.work.WorkRequest;
import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/** FlutterUploaderPlugin */
public class FlutterUploaderPlugin implements MethodCallHandler, Application.ActivityLifecycleCallbacks {
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
    this.connectionTimeout =  FlutterUploaderInitializer.getConnectionTimeout(registrar.context());
  }

  private final BroadcastReceiver updateProcessEventReceiver = new BroadcastReceiver() {
    @Override
    public void onReceive(Context context, Intent intent) {
      String id = intent.getStringExtra(UploadWorker.EXTRA_ID);
      int progress = intent.getIntExtra(UploadWorker.EXTRA_PROGRESS, 0);
      int status = intent.getIntExtra(UploadWorker.EXTRA_STATUS, UploadStatus.UNDEFINED);
      sendUpdateProgress(id, status, progress);
    }
  };

  private final Observer<List<WorkInfo>> completedEventObserver = new Observer<List<WorkInfo>>() {
    @Override
    public void onChanged(List<WorkInfo> workInfoList) {
      for(WorkInfo info : workInfoList) {
        String id = info.getId().toString();
        if(!completedTasks.containsKey(id)) {
          if(info.getState().isFinished()) {
            completedTasks.put(id, true);
            int status = info.getOutputData().getInt(UploadWorker.EXTRA_STATUS, UploadStatus.COMPLETE);
            switch(info.getState()) {
              case FAILED:
                  int statusCode = info.getOutputData().getInt(UploadWorker.EXTRA_STATUS_CODE, 200);
                  String code = info.getOutputData().getString(UploadWorker.EXTRA_ERROR_CODE);
                  String errorMessage = info.getOutputData().getString(UploadWorker.EXTRA_ERROR_MESSAGE);
                  String[] details = info.getOutputData().getStringArray(UploadWorker.EXTRA_ERROR_DETAILS);
                  sendFailed(id, status, statusCode, code, errorMessage, details);
                break;
              case CANCELLED:
                  sendFailed(id, UploadStatus.CANCELED, 500, "flutter_upload_cancelled", "upload has been cancelled", null);
              break;
              default:
                Map<String, String> headers = null;
                Type type = new TypeToken<Map<String, String>>(){}.getType();
                String headerJson = info.getOutputData().getString(UploadWorker.EXTRA_HEADERS);
                if(headerJson != null) {
                  headers = gson.fromJson(headerJson, type);
                }

                String response = info.getOutputData().getString(UploadWorker.EXTRA_RESPONSE);
                sendCompleted(id, status, response, headers);
                break;
            }

          }
        }
      }
    }
  };


  @Override
  public void onMethodCall(MethodCall call, Result result) {
    if (call.method.equals("enqueue")) {
      enqueue(call, result);
    } else if (call.method.equals("cancel")) {
      cancel(call, result);
    } else if (call.method.equals("cancelAll")) {
      cancelAll(call, result);
    } else {
      result.notImplemented();
    }
  }

  @Override
  public void onActivityCreated(Activity activity, Bundle savedInstanceState) {

  }

  @Override
  public void onActivityStarted(Activity activity) {
    if (activity instanceof FlutterActivity) {
      LocalBroadcastManager.getInstance(register.context()).registerReceiver(updateProcessEventReceiver,
              new IntentFilter(UploadWorker.UPDATE_PROCESS_EVENT));
      WorkManager.getInstance().getWorkInfosByTagLiveData(TAG)
              .observeForever(completedEventObserver);
    }
  }

  @Override
  public void onActivityResumed(Activity activity) {

  }

  @Override
  public void onActivityPaused(Activity activity) {

  }


  @Override
  public void onActivityStopped(Activity activity) {
    if (activity instanceof FlutterActivity) {
      LocalBroadcastManager.getInstance(register.context()).unregisterReceiver(updateProcessEventReceiver);
      WorkManager.getInstance().getWorkInfosByTagLiveData(TAG)
              .removeObserver(completedEventObserver);
    }
  }

  @Override
  public void onActivitySaveInstanceState(Activity activity, Bundle outState) {

  }

  @Override
  public void onActivityDestroyed(Activity activity) {
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

    if(method == null) {
      method = "POST";
    }

    if(!methods.contains(method.toUpperCase())) {
      result.error("invalid_method", "Method must be either POST | PUT | PATCH", null);
      return;
    }

    List<FileItem> items = new ArrayList<>();

    for(Map<String, String> file : files) {
      items.add(FileItem.fromJson(file));
    }

    WorkRequest request = buildRequest(new UploadTask(taskIdKey, url, method, items, headers, parameters, connectionTimeout, showNotification, tag));
    WorkManager.getInstance().enqueue(request);
    String taskId = request.getId().toString();
    if(!tasks.containsKey(taskId)) {
      tasks.put(taskId, tag);
    }
    result.success(taskId);
    sendUpdateProgress(taskId, UploadStatus.ENQUEUED, 0);
  }

  private void cancel(MethodCall call, MethodChannel.Result result) {
    String taskId = call.argument("task_id");
    WorkManager.getInstance().cancelWorkById(UUID.fromString(taskId));
    result.success(null);
  }

  private void cancelAll(MethodCall call, MethodChannel.Result result) {
    WorkManager.getInstance().cancelAllWorkByTag(TAG);
    result.success(null);
  }

  private WorkRequest buildRequest(UploadTask task) {

    Gson gson = new Gson();

    Data.Builder dataBuilder = new Data.Builder()
            .putString(UploadWorker.ARG_URL, task.getURL())
            .putString(UploadWorker.ARG_METHOD, task.getMethod())
            .putInt(UploadWorker.ARG_REQUEST_TIMEOUT, task.getTimeout())
            .putBoolean(UploadWorker.ARG_SHOW_NOTIFICATION, task.canShowNotification())
            .putString(UploadWorker.ARG_UPLOAD_REQUEST_TAG, task.getTag())
            .putInt(UploadWorker.ARG_ID, task.getId());

    List<FileItem> files = task.getFiles();

    String fileItemsJson = gson.toJson(files);
    dataBuilder.putString(UploadWorker.ARG_FILES, fileItemsJson);

    if(task.getHeaders() != null) {
      String headersJson = gson.toJson(task.getHeaders());
      dataBuilder.putString(UploadWorker.ARG_HEADERS, headersJson);
    }

    if(task.getParameters() != null) {
      String parametersJson = gson.toJson(task.getParameters());
      dataBuilder.putString(UploadWorker.ARG_DATA, parametersJson);
    }


    WorkRequest request = new OneTimeWorkRequest.Builder(UploadWorker.class)
            .setConstraints(new Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .setRequiresStorageNotLow(true)
                    .build())
            .addTag(TAG)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 5, TimeUnit.SECONDS)
            .setInputData(dataBuilder.build()
            )
            .build();
    return request;
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

  private void sendFailed(String id, int status, int statusCode, String code, String message, String[] details) {
    String tag = tasks.get(id);
    Map<String, Object> args = new HashMap<>();
    args.put("task_id", id);
    args.put("status", status);
    args.put("statusCode", statusCode);
    args.put("code", code);
    args.put("message", message);
    args.put("details", details);
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
