package com.bluechilli.flutteruploader;

import android.content.Context;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.concurrent.futures.CallbackToFutureAdapter;
import androidx.work.ListenableWorker;
import androidx.work.WorkerParameters;
import com.google.common.util.concurrent.ListenableFuture;
import com.microsoft.azure.storage.CloudStorageAccount;
import com.microsoft.azure.storage.OperationContext;
import com.microsoft.azure.storage.blob.BlobRequestOptions;
import com.microsoft.azure.storage.blob.CloudAppendBlob;
import com.microsoft.azure.storage.blob.CloudBlobClient;
import com.microsoft.azure.storage.blob.CloudBlobContainer;
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
    final String path = getInputData().getString("path");

    CloudStorageAccount account = CloudStorageAccount.parse(connectionString);

    CloudBlobClient blobClient = account.createCloudBlobClient();

    CloudBlobContainer container = blobClient.getContainerReference(containerName);

    container.createIfNotExists();

    OperationContext opContext = new OperationContext();

    BlobRequestOptions options = new BlobRequestOptions();
    options.setTimeoutIntervalInMs(1000);

    // Create the container if it does not exist
    container.createIfNotExists(options, opContext);

    CloudAppendBlob appendBlob = container.getAppendBlobReference("AppendBlob");
    appendBlob.createOrReplace();

    appendBlob.appendText("sample contents");

    return Result.success();
  }
}
