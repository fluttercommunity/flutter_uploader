package com.bluechilli.flutteruploader.plugin;

import android.text.TextUtils;
import androidx.lifecycle.Observer;
import androidx.work.Data;
import androidx.work.WorkInfo;
import com.bluechilli.flutteruploader.UploadStatus;
import com.bluechilli.flutteruploader.UploadWorker;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import java.io.BufferedReader;
import java.io.FileReader;
import java.lang.ref.WeakReference;
import java.lang.reflect.Type;
import java.util.List;
import java.util.Map;

public class UploadObserver implements Observer<List<WorkInfo>> {
  private final WeakReference<StatusListener> listener;
  private final Gson gson = new Gson();

  public UploadObserver(StatusListener listener) {
    this.listener = new WeakReference<>(listener);
  }

  @Override
  public void onChanged(List<WorkInfo> workInfoList) {
    StatusListener plugin = this.listener.get();

    if (plugin == null) {
      return;
    }

    for (WorkInfo info : workInfoList) {
      String id = info.getId().toString();

      switch (info.getState()) {
        case RUNNING:
          {
            Data progress = info.getProgress();

            plugin.onUpdateProgress(
                info.getId().toString(),
                progress.getInt("status", -1),
                progress.getInt("progress", -1));
          }
          break;
        case FAILED:
          {
            final Data outputData = info.getOutputData();
            int failedStatus = outputData.getInt(UploadWorker.EXTRA_STATUS, UploadStatus.FAILED);
            int statusCode = outputData.getInt(UploadWorker.EXTRA_STATUS_CODE, 500);
            String code = outputData.getString(UploadWorker.EXTRA_ERROR_CODE);
            String errorMessage = outputData.getString(UploadWorker.EXTRA_ERROR_MESSAGE);
            String[] details = outputData.getStringArray(UploadWorker.EXTRA_ERROR_DETAILS);

            plugin.onFailed(id, failedStatus, statusCode, code, errorMessage, details);
          }
          break;
        case CANCELLED:
          plugin.onFailed(id, UploadStatus.CANCELED, 500, "flutter_upload_cancelled", null, null);
          break;
        case SUCCEEDED:
          {
            final Data outputData = info.getOutputData();
            int status = outputData.getInt(UploadWorker.EXTRA_STATUS, UploadStatus.COMPLETE);
            int statusCode = outputData.getInt(UploadWorker.EXTRA_STATUS_CODE, 500);
            Map<String, String> headers = null;
            Type type = new TypeToken<Map<String, String>>() {}.getType();
            String headerJson = outputData.getString(UploadWorker.EXTRA_HEADERS);
            if (headerJson != null) {
              headers = gson.fromJson(headerJson, type);
            }

            String response = extractResponse(outputData);
            plugin.onCompleted(id, status, statusCode, response, headers);
          }
          break;
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
