package com.bluechilli.flutteruploader;

public interface CountProgressListener {

  void OnProgress(String taskId, long bytesWritten, long contentLength);

  void OnError(String taskId, String code, String message);
}
