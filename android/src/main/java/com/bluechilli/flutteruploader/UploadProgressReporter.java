package com.bluechilli.flutteruploader;

import androidx.annotation.MainThread;
import androidx.lifecycle.LiveData;

public class UploadProgressReporter extends LiveData<UploadProgress> {
    private static UploadProgressReporter _instance;


    @MainThread
    public static UploadProgressReporter getInstance() {
        if (_instance == null) {
            _instance = new UploadProgressReporter();
        }
        return _instance;

    }

    void notifyProgress(UploadProgress progress) {
        postValue(progress);
    }

}
