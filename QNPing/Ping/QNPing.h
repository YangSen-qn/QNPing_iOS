//
//  QNPing.h
//  QNPing
//
//  Created by yangsen on 2020/6/16.
//  Copyright © 2020 yangsen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QNPingDelegate;

@interface QNPingOption : NSObject

// 发送时间间隔 单位:秒  默认:1
@property(nonatomic, assign)int interval;
// 检测超时时间 单位：秒 默认:1
@property(nonatomic, assign)int timeout;
// ping 次数  0:不限制  默认:0
@property(nonatomic, assign)int count;
// 预发送数据, 默认:64bytes
@property(nonatomic, strong)NSData *preload;
// ping类型 1:ipv4  2:ipv6  0:不限制，ipv4/ipv6  默认:0
@property(nonatomic, assign)int pingType;

@end


@interface QNPing : NSObject

@property(nonatomic, strong, readonly)NSDate *startDate;
@property(nonatomic,   copy, readonly)NSString *address;
@property(nonatomic, strong, readonly)NSString *currentPingIP;

@property(nonatomic, weak)id <QNPingDelegate> delegate;

+ (instancetype)ping:(NSString *)address config:(void(^)(QNPingOption *option))config;

- (void)startPing;
- (void)stopPing;

@end


@protocol QNPingDelegate <NSObject>

@optional
- (void)ping:(QNPing *)ping didStart:(uint16_t)dataBytesLength;
- (void)ping:(QNPing *)ping timeout:(uint16_t)sequenceNumber;
/// 收到icmp包的响应，spendTime：发送到接受花费时间，单位[秒]
- (void)ping:(QNPing *)ping receivePacket:(uint16_t)sequenceNumber spendTime:(int)spendTime dataBytesLength:(uint16_t)dataBytesLength;
- (void)ping:(QNPing *)ping completeWithSentPacketsCount:(uint16_t)sendPacketsCount receivedPacketsCount:(uint16_t)receivedPacketsCount;

@end

NS_ASSUME_NONNULL_END
