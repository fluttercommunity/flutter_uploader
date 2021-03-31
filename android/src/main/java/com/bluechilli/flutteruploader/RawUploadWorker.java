package com.bluechilli.flutteruploader;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.work.WorkerParameters;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import java.io.File;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;
import okhttp3.MediaType;
import okhttp3.RequestBody;

public class RawUploadWorker extends UploadWorker {

  public RawUploadWorker(@NonNull Context appContext, @NonNull WorkerParameters workerParams) {
    super(appContext, workerParams);
  }

  @Nullable
  @Override
  RequestBody buildRequestBody() {
    final Gson gson = new Gson();

    String filesJson = getInputData().getString(ARG_FILES);

    final Type listFileItemType = new TypeToken<List<FileItem>>() {}.getType();

    List<FileItem> files = new ArrayList<>();

    if (filesJson != null) {
      files = gson.fromJson(filesJson, listFileItemType);
    }

    final FileItem item = files.get(0);
    File file = new File(item.getPath());

    if (!file.exists()) {
      return null;
    }

    String mimeType = MimeTypeDetector.detect(item.getPath());
    MediaType contentType = MediaType.parse(mimeType);
    return RequestBody.create(file, contentType);
  }
}
