package com.bluechilli.flutteruploader;

import android.net.Uri;
import java.util.List;
import java.util.Map;

public class UploadTask {

  private String url;
  private String method;
  private Map<String, String> headers;
  private Map<String, String> data;
  private List<FileItem> files;
  private int requestTimeoutInSeconds;
  private boolean binaryUpload;
  private String tag;
  private boolean allowCellular;

  public UploadTask(
      String url,
      String method,
      List<FileItem> files,
      Map<String, String> headers,
      Map<String, String> data,
      int requestTimeoutInSeconds,
      boolean binaryUpload,
      String tag,
      boolean allowCellular) {
    this.url = url;
    this.method = method;
    this.files = files;
    this.headers = headers;
    this.data = data;
    this.requestTimeoutInSeconds = requestTimeoutInSeconds;
    this.binaryUpload = binaryUpload;
    this.tag = tag;
    this.allowCellular = allowCellular;
  }

  public String getURL() {
    return url;
  }

  public Uri getUri() {
    return Uri.parse(url);
  }

  public String getMethod() {
    return method;
  }

  public List<FileItem> getFiles() {
    return files;
  }

  public Map<String, String> getHeaders() {
    return headers;
  }

  public Map<String, String> getParameters() {
    return data;
  }

  public int getTimeout() {
    return requestTimeoutInSeconds;
  }

  public boolean isBinaryUpload() {
    return binaryUpload;
  }

  public String getTag() {
    return tag;
  }

  public boolean isAllowCellular() {
    return allowCellular;
  }
}
