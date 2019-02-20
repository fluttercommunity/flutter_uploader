#import "FlutterUploaderPlugin.h"
#import <flutter_uploader/flutter_uploader-Swift.h>



@implementation FlutterUploaderPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterUploaderPlugin registerWithRegistrar:registrar];
}
@end
