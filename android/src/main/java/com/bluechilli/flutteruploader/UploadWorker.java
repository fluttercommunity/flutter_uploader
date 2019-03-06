package com.bluechilli.flutteruploader;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.res.Resources;
import android.os.Build;
import android.util.Log;
import android.webkit.MimeTypeMap;

import com.google.gson.Gson;
import com.google.gson.JsonIOException;
import com.google.gson.reflect.TypeToken;

import java.io.File;
import java.io.IOException;
import java.lang.reflect.Type;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import androidx.work.Data;
import androidx.work.Worker;
import androidx.work.WorkerParameters;
import okhttp3.Call;
import okhttp3.Headers;
import okhttp3.MediaType;
import okhttp3.MultipartBody;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;


public class UploadWorker extends Worker implements CountProgressListener {
    public static final String UPDATE_PROCESS_EVENT = "com.bluechilli.flutteruploader.UPDATE_PROCESS_EVENT";
    public static final String COMPLETED_EVENT = "com.bluechilli.flutteruploader.COMPLETED_EVENT";
    public static final String FAILURE_EVENT = "com.bluechilli.flutteruploader.FAILURE_EVENT";

    public static final String ARG_URL = "url";
    public static final String ARG_METHOD = "method";
    public static final String ARG_HEADERS = "headers";
    public static final String ARG_DATA = "data";
    public static final String ARG_FILES = "files";
    public static final String ARG_REQUEST_TIMEOUT = "requestTimeout";
    public static final String ARG_SHOW_NOTIFICATION = "showNotification";
    public static final String ARG_UPLOAD_REQUEST_TAG = "tag";
    public static final String EXTRA_STATUS_CODE = "statusCode";
    public static final String EXTRA_STATUS = "status";
    public static final String EXTRA_ERROR_MESSAGE = "errorMessage";
    public static final String EXTRA_ERROR_CODE = "errorCode";
    public static final String EXTRA_ERROR_DETAILS = "errorDetails";
    public static final String EXTRA_RESPONSE = "response";
    public static final String EXTRA_PROGRESS = "progress";
    public static final String EXTRA_ID = "id";
    public static final String EXTRA_REQUEST_TAG = "id";
    private static final String TAG = UploadWorker.class.getSimpleName();
    private static final String CHANNEL_ID = "FLUTTER_UPLOADER_NOTIFICATION";
    private static final int UPDATE_STEP = 0;

    private NotificationCompat.Builder builder;
    private boolean showNotification;
    private String msgStarted, msgInProgress, msgCanceled, msgFailed, msgComplete;
    private int lastProgress = 0;

    public UploadWorker(@NonNull Context context, @NonNull WorkerParameters workerParams) {
        super(context, workerParams);
    }

    @NonNull
    @Override
    public Result doWork() {

        Context context = getApplicationContext();
        String url = getInputData().getString(ARG_URL);
        String method = getInputData().getString(ARG_METHOD);
        int timeout = getInputData().getInt(ARG_REQUEST_TIMEOUT, 3600);
        showNotification = getInputData().getBoolean(ARG_SHOW_NOTIFICATION, false);
        String headersJson = getInputData().getString(ARG_HEADERS);
        String parametersJson = getInputData().getString(ARG_DATA);
        String filesJson = getInputData().getString(ARG_FILES);
        String tag = getInputData().getString(ARG_UPLOAD_REQUEST_TAG);

        if(tag == null) {
            tag = getId().toString();
        }

        int statusCode = 200;
        if(method == null) method = "POST";
        Resources res = getApplicationContext().getResources();
        msgStarted = res.getString(R.string.flutter_uploader_notification_started);
        msgInProgress = res.getString(R.string.flutter_uploader_notification_in_progress);
        msgCanceled = res.getString(R.string.flutter_uploader_notification_canceled);
        msgFailed = res.getString(R.string.flutter_uploader_notification_failed);
        msgComplete = res.getString(R.string.flutter_uploader_notification_complete);


        try {
            Map<String, String> headers = null;
            Map<String, String> parameters = null;
            List<FileItem> files = new ArrayList<>();
            Gson gson = new Gson();
            Type type = new TypeToken<Map<String, String>>(){}.getType();
            Type fileItemType = new TypeToken<List<FileItem>>(){}.getType();

            if(headersJson != null) {
                headers = gson.fromJson(headersJson, type);
            }

            if(parametersJson != null) {
                parameters = gson.fromJson(parametersJson,type);
            }

            if(filesJson != null) {
                files = gson.fromJson(filesJson,fileItemType);
            }

            MultipartBody.Builder formRequestBuilder = prepareRequest(parameters, null);

            int fileExistsCount = 0;
            for(FileItem item : files) {
                File file = new File(item.getPath());
                Log.d(TAG, "attaching file: " + item.getPath());

                if(file.exists()) {
                    fileExistsCount++;
                    RequestBody fileBody = RequestBody.create(MediaType.parse(GetMimeType(item.getPath())), file);
                    formRequestBuilder.addFormDataPart(item.getFieldname(), item.getFilename(), fileBody);
                }
                else {
                    Log.d(TAG,"File does not exists -> file:" + item.getPath());
                }
            }

            if(fileExistsCount == 0) {
                return Result.failure(createOutputErrorData(UploadStatus.FAILED, statusCode, "flutter_upload_error",  "there are not files to upload", null));
            }


            RequestBody requestBody = new CountingRequestBody(formRequestBuilder.build(), getId().toString(), this);
            Request.Builder requestBuilder = new Request.Builder();

            if(headers != null) {

                for(String key : headers.keySet()) {

                    String header = headers.get(key);

                    if(header != null && !header.isEmpty()) {
                        requestBuilder = requestBuilder.addHeader(key, header);
                    }
                }

            }


            requestBuilder.addHeader("Accept", "application/json; charset=utf-8");
            requestBuilder.addHeader("Accept-Encoding", "br, gzip, deflate");
            Request request = null;

            switch(method.toUpperCase()) {
                case "PUT":
                    request = requestBuilder.url(url)
                            .put(requestBody)
                            .build();
                    break;
                case "PATCH":
                    request = requestBuilder.url(url)
                            .patch(requestBody)
                            .build();

                    break;
                default:
                    request = requestBuilder.url(url)
                            .post(requestBody)
                            .build();

                    break;
            }

            buildNotification(getApplicationContext());

            Log.d(TAG,"Start uploading for " + tag);

            OkHttpClient client = new OkHttpClient.Builder()
                    .connectTimeout((long) timeout, TimeUnit.SECONDS)
                    .writeTimeout((long) timeout, TimeUnit.SECONDS)
                    .readTimeout((long) timeout, TimeUnit.SECONDS)
                    .build();

            Call call = client.newCall(request);
            Response response = call.execute();
            String responseString = response.body().string();
            statusCode = response.code();
            Headers rheaders = response.headers();
            Map<String, String> outputHeaders = new HashMap<>();

            if(rheaders != null) {
                for(String name : rheaders.names()) {
                    outputHeaders.put(name, rheaders.get(name));
                }
            }

            Log.d(TAG, "id:" + tag + ", Response: " + responseString);

            if(!response.isSuccessful()) {
                if(showNotification) {
                   updateNotification(context, getId().toString(), tag, UploadStatus.FAILED, 100, null);
                }
                return Result.failure(createOutputErrorData(UploadStatus.FAILED, statusCode, "flutter_upload_error",  responseString, null));
            }

            Data outputData = new Data.Builder()
                    .putString(EXTRA_ID, getId().toString())
                    .putInt(EXTRA_STATUS, UploadStatus.COMPLETE)
                    .putInt(EXTRA_STATUS_CODE, statusCode)
                    .putString(EXTRA_RESPONSE, responseString)
                    .build();

            if(showNotification) {
                updateNotification(context, getId().toString(), tag, UploadStatus.COMPLETE, 100, null);
            }

            return Result.success(outputData);

        }
        catch(JsonIOException ex) {
         ex.printStackTrace();

         String stacktrace = getStacktraceAsString(ex.getStackTrace());

         if(showNotification) {
           updateNotification(context, getId().toString(), tag, UploadStatus.FAILED, 100, null);
         }

         return Result.failure(createOutputErrorData(UploadStatus.FAILED, 500, "flutter_upload_json_io",  ex.toString(), stacktrace));

        }
        catch (UnknownHostException ex) {
            ex.printStackTrace();

            String stacktrace = getStacktraceAsString(ex.getStackTrace());

            if(showNotification) {
                updateNotification(context, getId().toString(), tag, UploadStatus.FAILED, 100, null);
            }

            return Result.failure(createOutputErrorData(UploadStatus.FAILED, 500, "flutter_upload_unknown_host",  ex.toString(), stacktrace));
        }
        catch (IOException ex) {

            ex.printStackTrace();

            String stacktrace = getStacktraceAsString(ex.getStackTrace());

            if(showNotification) {
                updateNotification(context, getId().toString(), tag, UploadStatus.FAILED, 100, null);
            }

            return Result.failure(createOutputErrorData(UploadStatus.FAILED, 500, "flutter_upload_io_error",  ex.toString(), stacktrace));
        }
        catch (Exception ex) {

            ex.printStackTrace();

            String stacktrace = getStacktraceAsString(ex.getStackTrace());

            if(showNotification) {
                updateNotification(context, getId().toString(), tag, UploadStatus.FAILED, 100, null);
            }

            return Result.failure(createOutputErrorData(UploadStatus.FAILED, 500, "flutter_upload_error",  ex.toString(), stacktrace));
      }

    }

    private String GetMimeType(String url)
    {
        String type = "*/*";
        String extension = MimeTypeMap.getFileExtensionFromUrl(url);
        try
        {
            if (extension != null && !extension.isEmpty())
            {
                type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.toLowerCase());
            }
        }
        catch(Exception ex)
        {
            Log.d(TAG, "UploadWorker - GetMimeType", ex);
        }

        return type;
    }

    private MultipartBody.Builder prepareRequest(Map<String, String> parameters, String boundary)
    {

        MultipartBody.Builder requestBodyBuilder = boundary != null && !boundary.isEmpty() ?
                new MultipartBody.Builder(boundary) :  new MultipartBody.Builder();

        requestBodyBuilder.setType(MultipartBody.FORM);

        if (parameters == null) return requestBodyBuilder;

        for(String key : parameters.keySet()) {
            String parameter = parameters.get(key);
            if (parameter != null)
            {
                requestBodyBuilder.addFormDataPart(key, parameter);
            }
        }

        return requestBodyBuilder;
    }


    private void sendUpdateProcessEvent(Context context, int status, int progress) {
        Intent intent = new Intent(UPDATE_PROCESS_EVENT);
        intent.putExtra(EXTRA_ID, getId().toString());
        intent.putExtra(EXTRA_STATUS, status);
        intent.putExtra(EXTRA_PROGRESS, progress);
        LocalBroadcastManager.getInstance(context).sendBroadcast(intent);
    }



    private Data createOutputErrorData(int status, int statusCode, String code , String message, String details) {
        return new Data.Builder()
                .putInt(EXTRA_STATUS_CODE, statusCode)
                .putInt(EXTRA_STATUS, status)
                .putString(EXTRA_ERROR_CODE,  code)
                .putString(EXTRA_ERROR_MESSAGE, message)
                .putString(EXTRA_ERROR_DETAILS, details)
                .build();
    }


    @Override
    public void OnProgress(String taskId, long bytesWritten, long contentLength) {
        double p = ((double) bytesWritten / (double) contentLength) * 100;
        int progress = (int) Math.round(p);
        boolean running = isRunning(progress, lastProgress, UPDATE_STEP);
        lastProgress =  progress;
        Log.d(TAG, "taskId: " + getId().toString() + ", bytesWritten: " + bytesWritten + ", contentLength: " + contentLength + ", progress: " + progress);
        if(running) {
            Context context = getApplicationContext();
            sendUpdateProcessEvent(context, UploadStatus.RUNNING, lastProgress);
            if(showNotification) {
                updateNotification(context, taskId,"task -" + taskId, UploadStatus.RUNNING, progress, null);
            }
        }
    }

    @Override
    public void OnError(String taskId, String code, String message) {
        Log.d(TAG, "Failed to upload - taskId: " + getId().toString() + ", code: "  + code + ", error: " + message );
        sendUpdateProcessEvent(getApplicationContext(), UploadStatus.FAILED, -1);
    }


    private void buildNotification(Context context) {
        // Make a channel if necessary
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Create the NotificationChannel, but only on API 26+ because
            // the NotificationChannel class is new and not in the support library

            CharSequence name = context.getApplicationInfo().loadLabel(context.getPackageManager());
            int importance = NotificationManager.IMPORTANCE_DEFAULT;
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, name, importance);
            channel.setSound(null, null);

            // Add the channel
            NotificationManager notificationManager = context.getSystemService(NotificationManager.class);

            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }

        // Create the notification
        builder = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_upload)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT);

    }

    private void updateNotification(Context context, String primaryId, String title, int status, int progress, PendingIntent intent) {
        builder.setContentTitle(title);
        builder.setContentIntent(intent);
        boolean shouldUpdate = false;

        if (status == UploadStatus.RUNNING) {
            shouldUpdate = true;
            builder.setContentText(progress == 0 ? msgStarted : msgInProgress)
                    .setProgress(100, progress, progress == 0);
        } else if (status == UploadStatus.CANCELED) {
            shouldUpdate = true;
            builder.setContentText(msgCanceled).setProgress(0, 0, false);
        } else if (status == UploadStatus.FAILED) {
            shouldUpdate = true;
            builder.setContentText(msgFailed).setProgress(0, 0, false);
        } else if (status == UploadStatus.COMPLETE) {
            shouldUpdate = true;
            builder.setContentText(msgComplete).setProgress(0, 0, false);
        }

        // Show the notification
        if (showNotification && shouldUpdate) {
            NotificationManagerCompat.from(context).notify(primaryId,0, builder.build());
        }

    }

    private boolean isRunning(int currentProgress, int previousProgress, int step) {
        int prev = previousProgress + step;
        return (currentProgress == 0 || currentProgress > prev || currentProgress >= 100) && currentProgress != previousProgress;
    }

    private String getStacktraceAsString(StackTraceElement[] stacktraces) {

        if(stacktraces == null || (stacktraces != null && stacktraces.length == 0)) {
            return null;
        }

        StringBuilder builder = new StringBuilder();

        for(StackTraceElement stacktrace : stacktraces) {
            builder.append(stacktrace.toString() + "\n");
        }

        return builder.toString();
    }

}
