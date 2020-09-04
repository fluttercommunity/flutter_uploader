package com.bluechilli.flutteruploader;

import android.content.Context;
import android.util.Log;
import android.webkit.URLUtil;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.concurrent.futures.CallbackToFutureAdapter;
import androidx.work.Data;
import androidx.work.ListenableWorker;
import androidx.work.WorkerParameters;
import com.google.common.util.concurrent.ListenableFuture;
import com.google.gson.Gson;
import com.google.gson.JsonIOException;
import com.google.gson.reflect.TypeToken;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.reflect.Type;
import java.net.ProtocolException;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import okhttp3.Call;
import okhttp3.Headers;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okhttp3.ResponseBody;

public abstract class UploadWorker extends ListenableWorker implements CountProgressListener {
  public static final String ARG_URL = "url";
  public static final String ARG_METHOD = "method";
  public static final String ARG_HEADERS = "headers";
  public static final String ARG_DATA = "data";
  public static final String ARG_FILES = "files";
  public static final String ARG_REQUEST_TIMEOUT = "requestTimeout";
  public static final String ARG_UPLOAD_REQUEST_TAG = "tag";
  public static final String EXTRA_STATUS_CODE = "statusCode";
  public static final String EXTRA_STATUS = "status";
  public static final String EXTRA_ERROR_MESSAGE = "errorMessage";
  public static final String EXTRA_ERROR_CODE = "errorCode";
  public static final String EXTRA_ERROR_DETAILS = "errorDetails";
  public static final String EXTRA_RESPONSE = "response";
  public static final String EXTRA_RESPONSE_FILE = "response_file";
  public static final String EXTRA_ID = "id";
  public static final String EXTRA_HEADERS = "headers";
  private static final String TAG = UploadWorker.class.getSimpleName();
  private static final int UPDATE_STEP = 0;
  private static final int DEFAULT_ERROR_STATUS_CODE = 500;

  private String tag;
  private Call call;
  private boolean isCancelled = false;

  public UploadWorker(@NonNull Context appContext, @NonNull WorkerParameters workerParams) {
    super(appContext, workerParams);
  }

  private Executor backgroundExecutor = Executors.newSingleThreadExecutor();

  @NonNull
  @Override
  public ListenableFuture<Result> startWork() {
    FlutterEngineHelper.start(getApplicationContext());

    return CallbackToFutureAdapter.getFuture(
        completer -> {
          backgroundExecutor.execute(
              () -> {
                try {
                  final Result result = doWorkInternal();
                  completer.set(result);
                } catch (Throwable e) {
                  completer.setException(e);
                } finally {
                  // Do not destroy the engine at this very moment.
                  // Keep it running in the background for just a little while.
                  //                  stopEngine();
                }
              });

          return getId().toString();
        });
  }

  @NonNull
  private Result doWorkInternal() {
    String url = getInputData().getString(ARG_URL);
    String method = getInputData().getString(ARG_METHOD);
    int timeout = getInputData().getInt(ARG_REQUEST_TIMEOUT, 3600);
    String headersJson = getInputData().getString(ARG_HEADERS);
    tag = getInputData().getString(ARG_UPLOAD_REQUEST_TAG);

    if (tag == null) {
      tag = getId().toString();
    }

    int statusCode = 200;

    try {
      Map<String, String> headers = null;
      final Gson gson = new Gson();
      final Type mapStringStringType = new TypeToken<Map<String, String>>() {}.getType();

      if (headersJson != null) {
        headers = gson.fromJson(headersJson, mapStringStringType);
      }

      final RequestBody innerRequestBody = buildRequestBody();

      if (innerRequestBody == null) {
        return Result.failure(
            createOutputErrorData(
                UploadStatus.FAILED,
                DEFAULT_ERROR_STATUS_CODE,
                "invalid_parameters",
                "There are no items to upload",
                null));
      }

      RequestBody requestBody = new CountingRequestBody(innerRequestBody, getId().toString(), this);
      Request.Builder requestBuilder = new Request.Builder();

      if (headers != null) {
        for (String key : headers.keySet()) {
          String header = headers.get(key);
          if (header != null && !header.isEmpty()) {
            requestBuilder = requestBuilder.addHeader(key, header);
          }
        }
      }

      if (!URLUtil.isValidUrl(url)) {
        return Result.failure(
            createOutputErrorData(
                UploadStatus.FAILED,
                DEFAULT_ERROR_STATUS_CODE,
                "invalid_url",
                "url is not a valid url",
                null));
      }

      requestBuilder.addHeader("Accept", "application/json; charset=utf-8");

      Request request;

      switch (method.toUpperCase()) {
        case "PUT":
          request = requestBuilder.url(url).put(requestBody).build();
          break;
        case "PATCH":
          request = requestBuilder.url(url).patch(requestBody).build();
          break;
        default:
          request = requestBuilder.url(url).post(requestBody).build();
          break;
      }

      Log.d(TAG, "Start uploading for " + tag);

      OkHttpClient client =
          new OkHttpClient.Builder()
              .connectTimeout((long) timeout, TimeUnit.SECONDS)
              .writeTimeout((long) timeout, TimeUnit.SECONDS)
              .readTimeout((long) timeout, TimeUnit.SECONDS)
              .build();

      call = client.newCall(request);
      Response response = call.execute();
      statusCode = response.code();
      Headers rheaders = response.headers();
      Map<String, String> outputHeaders = new HashMap<>();

      boolean hasJsonResponse = true;

      String responseContentType = rheaders.get("content-type");

      ResponseBody body = response.body();

      hasJsonResponse =
          responseContentType != null && responseContentType.contains("json") && body != null;

      for (String name : rheaders.names()) {
        String value = rheaders.get(name);
        if (value != null) {
          outputHeaders.put(name, value);
        } else {
          outputHeaders.put(name, "");
        }
      }

      String responseHeaders = gson.toJson(outputHeaders);
      String responseString = "";
      if (body != null) {
        responseString = body.string();
      }

      if (!response.isSuccessful()) {
        return Result.failure(
            createOutputErrorData(
                UploadStatus.FAILED, statusCode, "upload_error", responseString, null));
      }

      Data.Builder builder =
          new Data.Builder()
              .putString(EXTRA_ID, getId().toString())
              .putInt(EXTRA_STATUS, UploadStatus.COMPLETE)
              .putInt(EXTRA_STATUS_CODE, statusCode)
              .putString(EXTRA_HEADERS, responseHeaders);

      if (hasJsonResponse) {
        builder.putString(EXTRA_RESPONSE, responseString);
      }

      Data outputData;
      try {
        outputData = builder.build();
      } catch (IllegalStateException e) {
        if (responseString.isEmpty()) {
          // Managed to break it with an empty string.
          throw e;
        }

        Log.d(
            TAG,
            "IllegalStateException while building a outputData object. Replace response with on-disk reference.");
        builder.putString(EXTRA_RESPONSE, null);

        File responseFile = writeResponseToTemporaryFile(responseString);
        if (responseFile != null) {
          builder.putString(EXTRA_RESPONSE_FILE, responseFile.getAbsolutePath());
        }

        outputData = builder.build();
      }

      return Result.success(outputData);
    } catch (ProtocolException ex) {
      if (isCancelled) {
        return Result.failure();
      }
      return handleException(ex, "protocol");
    } catch (JsonIOException ex) {
      return handleException(ex, "json_error");
    } catch (UnknownHostException ex) {
      return handleException(ex, "unknown_host");
    } catch (IOException ex) {
      return handleException(ex, "io_error");
    } catch (Exception ex) {
      return handleException(ex, "upload error");
    } finally {
      call = null;
    }
  }

  @Nullable
  abstract RequestBody buildRequestBody();

  private File writeResponseToTemporaryFile(String body) {
    final File cacheDir = getApplicationContext().getCacheDir();
    FileOutputStream fos = null;
    try {
      File tempFile = File.createTempFile("flutter_uploader", null, cacheDir);
      fos = new FileOutputStream(tempFile);
      fos.write(body.getBytes());
      fos.close();
      return tempFile;
    } catch (Throwable e) {
      if (fos != null) {
        try {
          fos.close();
        } catch (Throwable ignored) {
        }
      }
    }

    return null;
  }

  private Result handleException(Exception ex, String code) {
    Log.e(TAG, "exception encountered", ex);

    int finalStatus = isCancelled ? UploadStatus.CANCELED : UploadStatus.FAILED;
    String finalCode = isCancelled ? "upload_cancelled" : code;

    return Result.failure(
        createOutputErrorData(
            finalStatus,
            500,
            finalCode,
            ex.toString(),
            getStacktraceAsStringList(ex.getStackTrace())));
  }

  private void sendUpdateProcessEvent(int status, int progress) {
    setProgressAsync(
        new Data.Builder().putInt("status", status).putInt("progress", progress).build());
  }

  private Data createOutputErrorData(
      int status, int statusCode, String code, String message, String[] details) {
    return new Data.Builder()
        .putInt(UploadWorker.EXTRA_STATUS_CODE, statusCode)
        .putInt(UploadWorker.EXTRA_STATUS, status)
        .putString(UploadWorker.EXTRA_ERROR_CODE, code)
        .putString(UploadWorker.EXTRA_ERROR_MESSAGE, message)
        .putStringArray(UploadWorker.EXTRA_ERROR_DETAILS, details)
        .build();
  }

  @Override
  public void OnProgress(String taskId, long bytesWritten, long contentLength) {
    if (isCancelled) {
      return;
    }

    double p = ((double) bytesWritten / (double) contentLength) * 100;
    int progress = (int) Math.round(p);

    Log.d(
        TAG,
        "taskId: "
            + getId().toString()
            + ", bytesWritten: "
            + bytesWritten
            + ", contentLength: "
            + contentLength
            + ", progress: "
            + progress);

    sendUpdateProcessEvent(UploadStatus.RUNNING, progress);
  }

  @Override
  public void onStopped() {
    super.onStopped();
    Log.d(TAG, "UploadWorker - Stopped");
    try {
      isCancelled = true;
      if (call != null && !call.isCanceled()) {
        call.cancel();
      }
    } catch (Exception ex) {
      Log.d(TAG, "Upload Request cancelled", ex);
    }
  }

  @Override
  public void OnError(String taskId, String code, String message) {
    if (isCancelled) {
      return;
    }

    Log.d(
        TAG,
        "Failed to upload - taskId: "
            + getId().toString()
            + ", code: "
            + code
            + ", error: "
            + message);
    sendUpdateProcessEvent(UploadStatus.FAILED, -1);
  }

  private String[] getStacktraceAsStringList(StackTraceElement[] stacktrace) {
    List<String> output = new ArrayList<>();

    if (stacktrace == null || stacktrace.length == 0) {
      return null;
    }

    for (StackTraceElement stackTraceElement : stacktrace) {
      output.add(stackTraceElement.toString());
    }

    return output.toArray(new String[0]);
  }
}
