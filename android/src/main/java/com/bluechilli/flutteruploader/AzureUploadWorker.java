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
import com.microsoft.azure.storage.AccessCondition;
import com.microsoft.azure.storage.CloudStorageAccount;
import com.microsoft.azure.storage.OperationContext;
import com.microsoft.azure.storage.RetryNoRetry;
import com.microsoft.azure.storage.blob.BlobRequestOptions;
import com.microsoft.azure.storage.blob.CloudAppendBlob;
import com.microsoft.azure.storage.blob.CloudBlobClient;
import com.microsoft.azure.storage.blob.CloudBlobContainer;
import io.flutter.BuildConfig;
import java.io.FileNotFoundException;
import java.io.IOException;
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
    final boolean createContainer = getInputData().getBoolean("createContainer", false);
    final String blobName = getInputData().getString("blobName");
    final String path = getInputData().getString("path");
    final int blockSize = getInputData().getInt("blockSize", 1024 * 1024) ;

    final SharedPreferences preferences =
        getApplicationContext().getSharedPreferences("AzureUploadWorker", Context.MODE_PRIVATE);
    final String bytesWrittenKey = "bytesWritten." + getId();

    //    Log.d(TAG, "bytesWrittenKey: " + bytesWrittenKey);

    long bytesWritten = preferences.getInt(bytesWrittenKey, 0);

    //    Log.d(TAG, "bytesWritten   : " + bytesWritten);

    CloudStorageAccount account = CloudStorageAccount.parse(connectionString);
    CloudBlobClient blobClient = account.createCloudBlobClient();

    final CloudBlobContainer container = blobClient.getContainerReference(containerName);

    final OperationContext opContext = new OperationContext();
//    opContext.setLogLevel(BuildConfig.DEBUG ? Log.VERBOSE : Log.WARN);
    opContext.setLogLevel(Log.WARN);

    final BlobRequestOptions options = new BlobRequestOptions();
    options.setRetryPolicyFactory(new RetryNoRetry());

    if (createContainer) {
      container.createIfNotExists(options, opContext);
    }

    final CloudAppendBlob appendBlob = container.getAppendBlobReference(blobName);

    if (bytesWritten == 0) {
      appendBlob.createOrReplace(AccessCondition.generateEmptyCondition(), options, opContext);
    }

    try (final RandomAccessFile file = new RandomAccessFile(path, "r");
        final InputStream is = Channels.newInputStream(file.getChannel())) {
      final long contentLength = file.length();

      Log.d(TAG, "file contentLength: " + contentLength + ", blockSize: " + blockSize);
      if (bytesWritten != 0) {
        if (is.skip(bytesWritten) != bytesWritten) {
          throw new IllegalArgumentException("source file length mismatch?");
        }
      }

      while (bytesWritten < contentLength && !isStopped()) {
        final long thisBlock = Math.min(contentLength - bytesWritten, blockSize);

        Log.d(TAG, "Appending block at " + bytesWritten + ", thisBlock: " + thisBlock);

        appendBlob.append(
            is, thisBlock, AccessCondition.generateEmptyCondition(), options, opContext);

        bytesWritten += thisBlock;

        double p = ((double) (bytesWritten + thisBlock) / (double) contentLength) * 100;
        int progress = (int) Math.round(p);

        if (!isStopped()) {
          setProgressAsync(
              new Data.Builder()
                  .putInt("status", UploadStatus.RUNNING)
                  .putInt("progress", progress)
                  .build());
        }

        preferences.edit().putInt(bytesWrittenKey, (int) bytesWritten).apply();
      }
    } catch (FileNotFoundException e) {
      Log.e(TAG, "Source path not found: " + path, e);
      preferences.edit().remove(bytesWrittenKey).apply();
      return Result.failure();
    } catch (IOException e) {
      return Result.retry();
    } catch (Exception e) {
      Log.e(TAG, "Unrecoverable exception: " + e);
      preferences.edit().remove(bytesWrittenKey).apply();
      return Result.failure();
    }

    final Data.Builder output =
        new Data.Builder()
            .putString(EXTRA_ID, getId().toString())
            .putInt(EXTRA_STATUS, UploadStatus.COMPLETE)
            .putInt(EXTRA_STATUS_CODE, 200);

    return Result.success(output.build());
  }
}
