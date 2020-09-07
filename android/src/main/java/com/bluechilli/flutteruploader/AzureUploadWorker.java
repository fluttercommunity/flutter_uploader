package com.bluechilli.flutteruploader;

import static com.bluechilli.flutteruploader.UploadWorker.EXTRA_ID;
import static com.bluechilli.flutteruploader.UploadWorker.EXTRA_STATUS;
import static com.bluechilli.flutteruploader.UploadWorker.EXTRA_STATUS_CODE;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.concurrent.futures.CallbackToFutureAdapter;
import androidx.work.Data;
import androidx.work.ListenableWorker;
import androidx.work.WorkerParameters;
import com.google.common.util.concurrent.ListenableFuture;
import com.microsoft.azure.storage.CloudStorageAccount;
import com.microsoft.azure.storage.OperationContext;
import com.microsoft.azure.storage.blob.BlobRequestOptions;
import com.microsoft.azure.storage.blob.CloudAppendBlob;
import com.microsoft.azure.storage.blob.CloudBlobClient;
import com.microsoft.azure.storage.blob.CloudBlobContainer;
import java.io.FileNotFoundException;
import java.io.InputStream;
import java.io.RandomAccessFile;
import java.nio.channels.Channels;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

public class AzureUploadWorker extends ListenableWorker {
  private static final String TAG = "AzureUploadWorker";
  /**
   * @param appContext The application {@link Context}
   * @param workerParams Parameters to setup the internal state of this worker
   */
  public AzureUploadWorker(@NonNull Context appContext, @NonNull WorkerParameters workerParams) {
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
                  Log.e(TAG, "Error while uploading to Azure", e);
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

  private Result doWorkInternal() throws Throwable {
    final String connectionString = getInputData().getString("connectionString");
    final String containerName = getInputData().getString("container");
    final String blobName = getInputData().getString("blobName");
    final String path = getInputData().getString("path");

    final SharedPreferences preferences =
        getApplicationContext().getSharedPreferences("AzureUploadWorker", Context.MODE_PRIVATE);
    final String bytesWrittenKey = "bytesWritten." + getId();

    Log.d(TAG, "bytesWrittenKey: " + bytesWrittenKey);

    int bytesWritten = preferences.getInt(bytesWrittenKey, 0);

    Log.d(TAG, "bytesWritten   : " + bytesWritten);

    final RandomAccessFile file;
    try {
      file = new RandomAccessFile(path, "r");
    } catch (FileNotFoundException e) {
      Log.e(TAG, "Source path not found: " + path, e);
      return Result.failure();
    } catch (SecurityException e) {
      Log.e(TAG, "Permission denied: " + path, e);
      return Result.failure();
    }

    CloudStorageAccount account = CloudStorageAccount.parse(connectionString);

    CloudBlobClient blobClient = account.createCloudBlobClient();

    CloudBlobContainer container = blobClient.getContainerReference(containerName);

    container.createIfNotExists();

    OperationContext opContext = new OperationContext();

    BlobRequestOptions options = new BlobRequestOptions();
    options.setTimeoutIntervalInMs(1000);

    // Create the container if it does not exist
    container.createIfNotExists(options, opContext);

    CloudAppendBlob appendBlob = container.getAppendBlobReference(blobName);
    appendBlob.createOrReplace();

    InputStream is = Channels.newInputStream(file.getChannel());

    int blockSize = 1024 * 1024; // 1 MB

    final long contentLength = file.length();

    Log.d(TAG, "file contentLength: " + contentLength);

    while (bytesWritten + blockSize < contentLength && !isStopped()) {
      Log.d(TAG, "Appending block at bytesWritten " + bytesWritten + ", blockSize: " + blockSize);

      appendBlob.append(is, blockSize);

      bytesWritten += blockSize;

      double p = ((double) bytesWritten / (double) contentLength) * 100;
      int progress = (int) Math.round(p);

      if (!isStopped()) {
        setProgressAsync(
            new Data.Builder()
                .putInt("status", UploadStatus.RUNNING)
                .putInt("progress", progress)
                .build());
      }

      preferences.edit().putInt(bytesWrittenKey, bytesWritten).apply();
    }

    preferences.edit().remove(bytesWrittenKey).apply();

    final Data.Builder output =
        new Data.Builder()
            .putString(EXTRA_ID, getId().toString())
            .putInt(EXTRA_STATUS, UploadStatus.COMPLETE)
            .putInt(EXTRA_STATUS_CODE, 200);

    return Result.success(output.build());
  }
}
