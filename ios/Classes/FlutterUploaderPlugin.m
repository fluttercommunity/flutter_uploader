#import "FlutterUploaderPlugin.h"

#if __has_include(<flutter_uploader/flutter_uploader-Swift.h>)
#import <flutter_uploader/flutter_uploader-Swift.h>
#else
#import "flutter_uploader-Swift.h"
#endif

@implementation FlutterUploaderPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterUploaderPlugin registerWithRegistrar:registrar];
}
@end
