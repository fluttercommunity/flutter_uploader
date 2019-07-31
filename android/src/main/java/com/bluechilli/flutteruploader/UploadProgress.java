package com.bluechilli.flutteruploader;

public class UploadProgress {

    private String _taskId;
    private int _status;
    private int _progress;


    public UploadProgress(String taskId, int status, int progress) {
        this._taskId = taskId;
        this._status = status;
        this._progress = progress;
    }

    public int getProgress() {
        return _progress;
    }

    public int getStatus() {
        return _status;
    }

    public String getTaskId() {
        return _taskId;
    }


}
