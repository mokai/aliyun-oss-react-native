//
//  RNAliyunOSS+UPLOAD.m
//  aliyun-oss-rn-sdk
//  Created by 罗章 on 2018/5/8.

#import "RNAliyunOSS+UPLOAD.h"

@implementation RNAliyunOSS (UPLOAD)

/**
 Asynchronous uploading
 */
RCT_REMAP_METHOD(asyncUpload, asyncUploadWithBucketName:(NSString *)bucketName objectKey:(NSString *)objectKey filepath:(NSString *)filepath options:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){
    
    [self beginUploadingWithFilepath:filepath resultBlock:^(NSData *data) {
        OSSPutObjectRequest *put = [OSSPutObjectRequest new];
        //required fields
        put.bucketName = bucketName;
        put.objectKey = objectKey;
        put.uploadingData = data;
        
        // 设置Content-Type，可选
        //        put.contentType = @"application/octet-stream";
        //        // 设置MD5校验，可选
        //        put.contentMd5 = [OSSUtil base64Md5ForFilePath:@"<filePath>"]; // 如果是文件路径
        
        //optional fields
        put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
            NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
            
            // Only send events if anyone is listening
            if (self.hasListeners) {
                [self sendEventWithName:@"uploadProgress" body:@{@"objectKey": objectKey, @"bytesSent":[NSString stringWithFormat:@"%lld",bytesSent],
                                                                 @"currentSize": [NSString stringWithFormat:@"%lld",totalByteSent],
                                                                 @"totalSize": [NSString stringWithFormat:@"%lld",totalBytesExpectedToSend]}];
            }
        };
        
        OSSTask *putTask = [self.client putObject:put];
        
        [putTask continueWithBlock:^id(OSSTask *task) {
            
            if (!task.error) {
                NSLog(@"upload object success!");
                resolve(task.description);
            } else {
                NSLog(@"upload object failed, error: %@" , task.error);
                reject(@"Error", @"Upload failed", task.error);
            }
            return nil;
        }];
        
    }];
}


/**
 Asynchronously ResumableUpload
 */
RCT_REMAP_METHOD(asyncResumableUpload, asyncResumableUploadWithBucketName:(NSString *)bucketName objectKey:(NSString *)objectKey filepath:(NSString *)filepath options:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){
    
    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = bucketName;
    resumableUpload.objectKey = objectKey;
    resumableUpload.partSize = 1024 * 1024;
    
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        
        // Only send events if anyone is listening
        if (self.hasListeners) {
            [self sendEventWithName:@"uploadProgress" body:@{@"objectKey": objectKey, @"bytesSent":[NSString stringWithFormat:@"%lld",bytesSent],
                                                             @"currentSize": [NSString stringWithFormat:@"%lld",totalByteSent],
                                                             @"totalSize": [NSString stringWithFormat:@"%lld",totalBytesExpectedToSend]}];
        }
    };
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:filepath];
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;//记录断点的文件路径
    OSSTask * resumeTask = [self.client resumableUpload:resumableUpload];
    [resumeTask continueWithBlock:^id(OSSTask *task) {
        if (task.error) {
            NSLog(@"error: %@", task.error);
            if ([task.error.domain isEqualToString:OSSClientErrorDomain] && task.error.code == OSSClientErrorCodeCannotResumeUpload) {
                // 该任务无法续传，需要获取新的uploadId重新上传
            }
            reject(@"Error", @"Upload failed", task.error);
        } else {
            NSLog(@"Upload file success");
            resolve(task.description);
        }
        return nil;
    }];
}


@end
