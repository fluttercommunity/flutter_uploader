package com.bluechilli.flutteruploaderexample;

import android.os.Bundle;
import com.bluechilli.flutteruploader.FlutterUploaderPlugin;
import dev.flutter.plugins.e2e.E2EPlugin;
import io.flutter.app.FlutterActivity;

public class EmbeddingV1Activity extends FlutterActivity {

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    FlutterUploaderPlugin.registerWith(registrarFor("com.bluechilli.flutteruploader"));
    E2EPlugin.registerWith(registrarFor("dev.flutter.plugins.e2e.E2EPlugin"));
  }
}
