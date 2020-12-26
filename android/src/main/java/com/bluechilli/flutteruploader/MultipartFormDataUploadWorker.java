package com.bluechilli.flutteruploader;

import android.content.Context;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.work.WorkerParameters;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import java.io.File;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import okhttp3.MediaType;
import okhttp3.MultipartBody;
import okhttp3.RequestBody;

public class MultipartFormDataUploadWorker extends UploadWorker {
  private static final String TAG = "MultipartFormDataUpload";

  public MultipartFormDataUploadWorker(
      @NonNull Context appContext, @NonNull WorkerParameters workerParams) {
    super(appContext, workerParams);
  }

  @Override
  @Nullable
  RequestBody buildRequestBody() {
    final Gson gson = new Gson();

    String parametersJson = getInputData().getString(ARG_DATA);
    String filesJson = getInputData().getString(ARG_FILES);

    final Type mapStringStringType = new TypeToken<Map<String, String>>() {}.getType();
    final Type listFileItemType = new TypeToken<List<FileItem>>() {}.getType();

    Map<String, String> parameters = new HashMap<>();
    List<FileItem> files = new ArrayList<>();

    if (parametersJson != null) {
      parameters = gson.fromJson(parametersJson, mapStringStringType);
    }

    if (filesJson != null) {
      files = gson.fromJson(filesJson, listFileItemType);
    }

    MultipartBody.Builder formRequestBuilder = prepareRequest(parameters, null);
    int fileExistsCount = 0;
    for (FileItem item : files) {
      File file = new File(item.getPath());

      if (file.exists() && file.isFile()) {
        fileExistsCount++;
        String mimeType = MimeTypeDetector.detect(item.getPath());
        MediaType contentType = MediaType.parse(mimeType);
        RequestBody fileBody = RequestBody.create(file, contentType);
        formRequestBuilder.addFormDataPart(item.getFieldname(), file.getName(), fileBody);
      } else {
        Log.w(TAG, "File does not exists -> file:" + item.getPath());
      }
    }

    if (fileExistsCount == 0 && parameters.isEmpty()) {
      return null;
    }

    return formRequestBuilder.build();
  }

  private MultipartBody.Builder prepareRequest(Map<String, String> parameters, String boundary) {
    MultipartBody.Builder requestBodyBuilder =
        boundary != null && !boundary.isEmpty()
            ? new MultipartBody.Builder(boundary)
            : new MultipartBody.Builder();

    requestBodyBuilder.setType(MultipartBody.FORM);

    if (parameters == null) return requestBodyBuilder;

    for (String key : parameters.keySet()) {
      String parameter = parameters.get(key);
      if (parameter != null) {
        requestBodyBuilder.addFormDataPart(key, parameter);
      }
    }

    return requestBodyBuilder;
  }
}
