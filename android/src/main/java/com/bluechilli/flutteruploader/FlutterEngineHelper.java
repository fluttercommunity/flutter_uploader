package com.bluechilli.flutteruploader;

import android.content.Context;
import androidx.annotation.Nullable;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.view.FlutterCallbackInformation;
import io.flutter.view.FlutterMain;

public class FlutterEngineHelper {
  @Nullable private static FlutterEngine engine;

  public static void start(Context context) {
    long callbackHandle = SharedPreferenceHelper.getCallbackHandle(context);

    if (callbackHandle != -1L && engine == null) {
      engine = new FlutterEngine(context);
      FlutterMain.ensureInitializationComplete(context, null);

      FlutterCallbackInformation callbackInfo =
          FlutterCallbackInformation.lookupCallbackInformation(callbackHandle);
      String dartBundlePath = FlutterMain.findAppBundlePath();

      engine
          .getDartExecutor()
          .executeDartCallback(
              new DartExecutor.DartCallback(context.getAssets(), dartBundlePath, callbackInfo));
    }
  }

  //  private void stopEngine() {
  //    Log.d(TAG, "Destroying worker engine.");
  //
  //    if (engine != null) {
  //      try {
  //        engine.destroy();
  //      } catch (Throwable e) {
  //        Log.e(TAG, "Can not destroy engine", e);
  //      }
  //      engine = null;
  //    }
  //  }
}
