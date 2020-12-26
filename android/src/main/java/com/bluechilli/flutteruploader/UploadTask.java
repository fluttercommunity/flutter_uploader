package com.bluechilli.flutteruploader;

import java.util.List;
import java.util.Map;

public class UploadTask {

  private String url;
  private String method;
  private Map<String, String> headers;
  private Map<String, String> data;
  private List<FileItem> files;
  private int requestTimeoutInSeconds;
  private String tag;

  public UploadTask(
      String url,
      String method,
      List<FileItem> files,
      Map<String, String> headers,
      Map<String, String> data,
      int requestTimeoutInSeconds,
      String tag) {
    this.url = url;
    this.method = method;
    this.files = files;
    this.headers = headers;
    this.data = data;
    this.requestTimeoutInSeconds = requestTimeoutInSeconds;
    this.tag = tag;
  }

  public String getURL() {
    return url;
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

  public String getTag() {
    return tag;
  }
}
