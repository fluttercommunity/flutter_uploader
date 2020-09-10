package com.bluechilli.flutteruploader.plugin;

import androidx.annotation.Nullable;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import java.util.HashMap;
import java.util.Map;

/**
 * A StreamHandler which manages a map of unique items and caches their last status.
 *
 * @param <T>
 */
public class CachingStreamHandler<T> implements StreamHandler {
  @Nullable private EventSink eventSink;

  Map<String, T> cache = new HashMap<>();

  @Override
  public void onListen(Object arguments, EventSink events) {
    eventSink = events;

    if (!cache.isEmpty()) {
      for (T item : cache.values()) {
        events.success(item);
      }
    }
  }

  @Override
  public void onCancel(Object arguments) {
    eventSink = null;
  }

  public void add(String id, T args) {
    if (eventSink != null) {
      eventSink.success(args);
    }

    cache.put(id, args);
  }

  public void clear() {
    cache.clear();
  }
}
