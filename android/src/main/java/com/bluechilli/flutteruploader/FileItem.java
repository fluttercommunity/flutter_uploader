package com.bluechilli.flutteruploader;

import java.util.Map;

public class FileItem {

  private String fieldname;
  private String path;

  public FileItem(String path) {
    this.path = path;
  }

  public FileItem(String path, String fieldname) {
    this.fieldname = fieldname;
    this.path = path;
  }

  public static FileItem fromJson(Map<String, String> map) {
    return new FileItem(map.get("path"), map.get("fieldname"));
  }

  public String getFieldname() {
    return fieldname;
  }

  public String getPath() {
    return path;
  }
}
