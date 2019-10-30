package com.bluechilli.flutteruploader;

import androidx.annotation.NonNull;
import java.io.IOException;
import okhttp3.MediaType;
import okhttp3.RequestBody;
import okio.Buffer;
import okio.BufferedSink;
import okio.ForwardingSink;
import okio.Okio;
import okio.Sink;

public class CountingRequestBody extends RequestBody {

  protected final RequestBody _body;
  protected final CountProgressListener _listener;
  protected final String _taskId;
  protected CountingSink _countingSink;

  public CountingRequestBody(RequestBody body, String taskId, CountProgressListener listener) {
    _body = body;
    _taskId = taskId;
    _listener = listener;
  }

  @Override
  public MediaType contentType() {
    return _body.contentType();
  }

  @Override
  public long contentLength() throws IOException {
    return _body.contentLength();
  }

  @Override
  public void writeTo(@NonNull BufferedSink sink) throws IOException {
    try {
      _countingSink = new CountingSink(this, sink);
      BufferedSink bufferedSink = Okio.buffer(_countingSink);
      _body.writeTo(bufferedSink);

      bufferedSink.flush();
    } catch (IOException ex) {
      sendError(ex);
    }
  }

  public void sendProgress(long bytesWritten, long totalContentLength) {
    if (_listener != null) {
      _listener.OnProgress(_taskId, bytesWritten, totalContentLength);
    }
  }

  public void sendError(Exception ex) {
    if (_listener != null) {
      _listener.OnError(_taskId, "upload_task_error", ex.toString());
    }
  }

  protected class CountingSink extends ForwardingSink {
    private long _bytesWritten;
    private final CountingRequestBody _parent;

    public CountingSink(CountingRequestBody parent, Sink sink) {
      super(sink);
      _parent = parent;
    }

    @Override
    public void write(@NonNull Buffer source, long byteCount) throws IOException {
      try {
        super.write(source, byteCount);

        _bytesWritten += byteCount;

        if (_parent != null) {

          _parent.sendProgress(_bytesWritten, _parent.contentLength());
        }
      } catch (IOException ex) {
        if (_parent != null) {
          _parent.sendError(ex);
        }
      }
    }
  }
}
