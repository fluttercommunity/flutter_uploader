package com.bluechilli.flutteruploader;

import java.util.Map;

public class FileItem {

  private String fieldname;
  private String path;

  public FileItem(String fieldname, String path) {
    this.fieldname = fieldname;
    this.path = path;
  }

  public static FileItem fromJson(Map<String, String> map) {
    return new FileItem(map.get("fieldname"), map.get("path"));
  }

  public String getFieldname() {
    return fieldname;
  }

  public String getPath() {
    return path;
  }
}
