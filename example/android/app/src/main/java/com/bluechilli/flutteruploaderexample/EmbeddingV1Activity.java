package com.bluechilli.flutteruploaderexample;

import android.os.Bundle;
import com.bluechilli.flutteruploader.FlutterUploaderPlugin;
import io.flutter.app.FlutterActivity;

public class EmbeddingV1Activity extends FlutterActivity {

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    FlutterUploaderPlugin.registerWith(registrarFor("com.bluechilli.flutteruploader"));
  }
}
