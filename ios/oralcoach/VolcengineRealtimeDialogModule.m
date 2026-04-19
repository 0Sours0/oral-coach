#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <SpeechEngineToB/SpeechEngine.h>

@interface VolcengineRealtimeDialogModule : RCTEventEmitter <RCTBridgeModule, SpeechEngineDelegate>

@property (nonatomic, strong) SpeechEngine *engine;
@property (nonatomic, assign) BOOL hasListeners;
@property (nonatomic, assign) BOOL configured;
@property (nonatomic, strong) NSDictionary *lastConfig;

@end

@implementation VolcengineRealtimeDialogModule

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[
    @"engine_started",
    @"engine_stopped",
    @"asr_info",
    @"asr_response",
    @"asr_ended",
    @"chat_response",
    @"chat_ended",
    @"error"
  ];
}

- (void)startObserving
{
  self.hasListeners = YES;
}

- (void)stopObserving
{
  self.hasListeners = NO;
}

- (void)emitEvent:(NSString *)name body:(NSDictionary *)body
{
  if (!self.hasListeners) {
    return;
  }

  [self sendEventWithName:name body:body];
}

- (NSString *)stringFromData:(NSData *)data
{
  if (data == nil) {
    return @"";
  }

  NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  return string ?: @"";
}

- (id)jsonObjectFromData:(NSData *)data
{
  if (data == nil) {
    return nil;
  }

  return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

- (NSString *)asrTextFromData:(NSData *)data
{
  id json = [self jsonObjectFromData:data];
  if (![json isKindOfClass:[NSDictionary class]]) {
    return @"";
  }

  NSArray *results = ((NSDictionary *)json)[@"results"];
  if (![results isKindOfClass:[NSArray class]] || results.count == 0) {
    return @"";
  }

  id firstResult = results.firstObject;
  if (![firstResult isKindOfClass:[NSDictionary class]]) {
    return @"";
  }

  NSString *text = ((NSDictionary *)firstResult)[@"text"];
  return [text isKindOfClass:[NSString class]] ? text : @"";
}

- (NSString *)chatTextFromData:(NSData *)data
{
  id json = [self jsonObjectFromData:data];
  if (![json isKindOfClass:[NSDictionary class]]) {
    return @"";
  }

  NSString *content = ((NSDictionary *)json)[@"content"];
  return [content isKindOfClass:[NSString class]] ? content : @"";
}

- (NSString *)textForMessageType:(SEMessageType)type data:(NSData *)data
{
  switch (type) {
    case SEEventASRResponse:
      return [self asrTextFromData:data];
    case SEEventChatResponse:
      return [self chatTextFromData:data];
    default:
      return [self stringFromData:data];
  }
}

- (NSString *)jsonStringFromObject:(id)object
{
  if (object == nil) {
    return @"";
  }

  NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
  if (data == nil) {
    return @"";
  }

  return [self stringFromData:data];
}

- (void)ensureEngineWithConfig:(NSDictionary *)config
{
  if (self.engine == nil) {
    [SpeechEngine prepareEnvironment];
    self.engine = [[SpeechEngine alloc] init];
    [self.engine createEngineWithDelegate:self];
  }

  self.lastConfig = config;

  NSString *appID = config[@"appId"];
  NSString *appKey = config[@"appKey"];
  NSString *token = config[@"token"];
  NSString *resourceId = config[@"resourceId"];
  NSString *uid = config[@"uid"];
  NSString *dialogAddress = config[@"dialogAddress"];
  NSString *dialogUri = config[@"dialogUri"];
  NSString *requestHeaders = config[@"requestHeaders"];
  NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
  NSString *aecModelPath = [[NSBundle mainBundle] pathForResource:@"aec" ofType:@"model"];

  if (appID.length > 0) {
    [self.engine setStringParam:appID forKey:SE_PARAMS_KEY_APP_ID_STRING];
  }
  if (appKey.length > 0) {
    [self.engine setStringParam:appKey forKey:SE_PARAMS_KEY_APP_KEY_STRING];
  }
  if (token.length > 0) {
    [self.engine setStringParam:token forKey:SE_PARAMS_KEY_APP_TOKEN_STRING];
  }
  if (resourceId.length > 0) {
    [self.engine setStringParam:resourceId forKey:SE_PARAMS_KEY_RESOURCE_ID_STRING];
  }
  if (uid.length > 0) {
    [self.engine setStringParam:uid forKey:SE_PARAMS_KEY_UID_STRING];
  }
  if (dialogAddress.length > 0) {
    [self.engine setStringParam:dialogAddress forKey:SE_PARAMS_KEY_DIALOG_ADDRESS_STRING];
  }
  if (dialogUri.length > 0) {
    [self.engine setStringParam:dialogUri forKey:SE_PARAMS_KEY_DIALOG_URI_STRING];
  }
  [self.engine setStringParam:documentsPath ?: @"" forKey:SE_PARAMS_KEY_DEBUG_PATH_STRING];
  [self.engine setStringParam:SE_LOG_LEVEL_TRACE forKey:SE_PARAMS_KEY_LOG_LEVEL_STRING];
  [self.engine setStringParam:SE_RECORDER_TYPE_RECORDER forKey:SE_PARAMS_KEY_RECORDER_TYPE_STRING];
  [self.engine setBoolParam:YES forKey:SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_BOOL];
  [self.engine setBoolParam:NO forKey:SE_PARAMS_KEY_DIALOG_ENABLE_RECORDER_AUDIO_CALLBACK_BOOL];
  [self.engine setBoolParam:NO forKey:SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_AUDIO_CALLBACK_BOOL];
  [self.engine setBoolParam:NO forKey:SE_PARAMS_KEY_DIALOG_ENABLE_DECODER_AUDIO_CALLBACK_BOOL];
  [self.engine setStringParam:requestHeaders ?: @"" forKey:SE_PARAMS_KEY_REQUEST_HEADERS_STRING];
  [self.engine setBoolParam:YES forKey:SE_PARAMS_KEY_ENABLE_AEC_BOOL];
  if (aecModelPath.length > 0) {
    [self.engine setStringParam:aecModelPath forKey:SE_PARAMS_KEY_AEC_MODEL_PATH_STRING];
  }
  [self.engine setStringParam:SE_DIALOG_ENGINE forKey:SE_PARAMS_KEY_ENGINE_NAME_STRING];
}

RCT_REMAP_METHOD(configure,
                 configure:(NSDictionary *)config
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    [self ensureEngineWithConfig:config];
    [self.engine initEngine];
    self.configured = YES;
    resolve(@YES);
  } @catch (NSException *exception) {
    reject(@"volcengine_configure_failed", exception.reason, nil);
  }
}

RCT_REMAP_METHOD(startSession,
                 startSession:(NSDictionary *)options
                 startResolver:(RCTPromiseResolveBlock)resolve
                 startRejecter:(RCTPromiseRejectBlock)reject)
{
  if (!self.configured) {
    reject(@"volcengine_not_configured", @"Volcengine realtime dialog is not configured", nil);
    return;
  }

  @try {
    NSString *botName = options[@"botName"] ?: @"English Coach";
    NSMutableDictionary *dialog = [NSMutableDictionary dictionaryWithDictionary:@{ @"bot_name": botName }];
    if ([options[@"extra"] isKindOfClass:[NSDictionary class]]) {
      [dialog addEntriesFromDictionary:options[@"extra"]];
    }

    NSString *payload = [self jsonStringFromObject:@{ @"dialog": dialog }];
    [self.engine sendDirective:SEDirectiveSyncStopEngine];
    [self.engine sendDirective:SEDirectiveStartEngine data:payload];
    resolve(@YES);
  } @catch (NSException *exception) {
    reject(@"volcengine_start_failed", exception.reason, nil);
  }
}

RCT_REMAP_METHOD(stopSession,
                 stopSessionWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (self.engine == nil) {
    resolve(@YES);
    return;
  }

  @try {
    [self.engine sendDirective:SEDirectiveSyncStopEngine];
    resolve(@YES);
  } @catch (NSException *exception) {
    reject(@"volcengine_stop_failed", exception.reason, nil);
  }
}

RCT_REMAP_METHOD(sendTextQuery,
                 sendTextQuery:(NSString *)text
                 queryResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (!self.configured) {
    reject(@"volcengine_not_configured", @"Volcengine realtime dialog is not configured", nil);
    return;
  }

  @try {
    NSString *payload = [self jsonStringFromObject:@{ @"content": text ?: @"" }];
    [self.engine sendDirective:SEDirectiveEventChatTextQuery data:payload];
    resolve(@YES);
  } @catch (NSException *exception) {
    reject(@"volcengine_text_query_failed", exception.reason, nil);
  }
}

RCT_REMAP_METHOD(sendRagText,
                 sendRagText:(NSArray *)entries
                 ragResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (!self.configured) {
    reject(@"volcengine_not_configured", @"Volcengine realtime dialog is not configured", nil);
    return;
  }

  @try {
    NSString *externalRag = [self jsonStringFromObject:entries ?: @[]];
    NSString *payload = [self jsonStringFromObject:@{ @"external_rag": externalRag ?: @"[]" }];
    [self.engine sendDirective:SEDirectiveEventChatRagText data:payload];
    resolve(@YES);
  } @catch (NSException *exception) {
    reject(@"volcengine_rag_text_failed", exception.reason, nil);
  }
}

RCT_REMAP_METHOD(destroy,
                 destroyWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (self.engine == nil) {
    resolve(@YES);
    return;
  }

  @try {
    [self.engine sendDirective:SEDirectiveSyncStopEngine];
    [self.engine destroyEngine];
    self.engine = nil;
    self.configured = NO;
    resolve(@YES);
  } @catch (NSException *exception) {
    reject(@"volcengine_destroy_failed", exception.reason, nil);
  }
}

- (void)onMessageWithType:(SEMessageType)type andData:(NSData *)data
{
  NSString *raw = [self stringFromData:data];
  NSString *text = [self textForMessageType:type data:data];
  NSDictionary *payload = @{
    @"type": @(type),
    @"rawData": raw ?: @"",
    @"text": text ?: @""
  };

  switch (type) {
    case SEEngineStart:
      [self emitEvent:@"engine_started" body:payload];
      break;
    case SEEngineStop:
      [self emitEvent:@"engine_stopped" body:payload];
      break;
    case SEEngineError:
    case SEEventSessionFailed:
      [self emitEvent:@"error" body:payload];
      break;
    case SEEventASRInfo:
      [self emitEvent:@"asr_info" body:payload];
      break;
    case SEEventASRResponse:
      [self emitEvent:@"asr_response" body:payload];
      break;
    case SEEventASREnded:
      [self emitEvent:@"asr_ended" body:payload];
      break;
    case SEEventChatResponse:
      [self emitEvent:@"chat_response" body:payload];
      break;
    case SEEventChatEnded:
      [self emitEvent:@"chat_ended" body:payload];
      break;
    default:
      break;
  }
}

@end
