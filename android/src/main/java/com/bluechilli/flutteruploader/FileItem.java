package com.bluechilli.flutteruploader;

import java.util.Map;

public class FileItem {

  private String _fieldname;
  private String _filename;
  private String _savedDir;

  public FileItem(String fieldname, String filename, String savedDir) {
    _fieldname = fieldname;
    _filename = filename;
    _savedDir = savedDir;
  }

  public static FileItem fromJson(Map<String, String> map) {
    return new FileItem(map.get("fieldname"), map.get("filename"), map.get("savedDir"));
  }

  public String getFieldname() {
    return _fieldname;
  }

  public String getFilename() {
    return _filename;
  }

  public String getSavedDir() {
    return _savedDir;
  }

  public String getPath() {
    return getSavedDir() + "/" + getFilename();
  }
}
