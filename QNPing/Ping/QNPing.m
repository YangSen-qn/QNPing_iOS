//
//  QNPing.m
//  QNPing
//
//  Created by yangsen on 2020/6/16.
//  Copyright © 2020 yangsen. All rights reserved.
//

#import "QNPing.h"
#import "QNSimplePing.h"

#include <netdb.h>
#include <sys/socket.h>

#define kQNPingMaxTime 5000

@implementation QNPingOption

- (instancetype)init{
    if (self = [super init]) {
        _interval = 1;
        _timeout = 1;
        _count = 0;
        _preload = [NSMutableData dataWithLength:56];
        _pingType = 0;
    }
    return self;
}

- (BOOL)isTimeoutForTime:(int)time{
    return self.timeout < time;
}

- (BOOL)canPing:(int)currentCount{
    if (self.count == 0) {
        return true;
    } else {
        return self.count > currentCount;
    }
}

- (NSInteger)getPingType{
    if (_pingType < 3 && _pingType > -1) {
        return _pingType;
    } else {
        return 0;
    }
}

@end


@interface QNPing()<QNSimplePingDelegate>

@property(nonatomic, strong)QNPingOption *pingOption;

@property(nonatomic,   copy)NSString *address;
@property(nonatomic, strong)NSDate *startDate;
@property(nonatomic, strong)NSString *currentPingIP;

@property(atomic, assign)int sentPacketsCount;
@property(atomic, assign)int receivedPacketsCount;

@property(nonatomic, strong)NSMutableDictionary <NSString *, NSDate *> *pingSequenceInfo;

@property(nonatomic, strong)NSTimer *pingTimer;
@property(nonatomic, strong)QNSimplePing *simplePing;

@end
@implementation QNPing

+ (instancetype)ping:(NSString *)address config:(void (^)(QNPingOption * _Nonnull))config{
    QNPingOption *pingOption = [[QNPingOption alloc] init];
    if (config) {
        config(pingOption);
    }
    QNPing *ping = [[QNPing alloc] init];
    ping.pingOption = pingOption;
    ping.address = address;
    [ping initData];
    return ping;
}

- (void)initData{
    
    if (self.address) {
        QNSimplePing *simplePing = [[QNSimplePing alloc] initWithHostName:self.address];
        simplePing.delegate = self;
        simplePing.addressStyle = [self.pingOption getPingType];
        self.simplePing = simplePing;
        
        [self createTimer];
    }
    
    _sentPacketsCount = 0;
    _receivedPacketsCount = 0;
    _pingSequenceInfo = [NSMutableDictionary dictionary];
}

- (void)startPing{
    self.startDate = [NSDate date];
    if (self.pingTimer == nil) {
        [self createTimer];
    }
    [self.simplePing start];
}

- (void)stopPing{
    [self.simplePing stop];
    [self invalidateTimer];
    if ([self.delegate respondsToSelector:@selector(ping:completeWithSentPacketsCount:receivedPacketsCount:)]) {
        [self.delegate ping:self completeWithSentPacketsCount:self.sentPacketsCount receivedPacketsCount:self.receivedPacketsCount];
    }
}

- (void)ping{
    if (self.simplePing.hostAddress) {
        NSString *sequenceKey = [NSString stringWithFormat:@"%d", self.simplePing.nextSequenceNumber];
        self.pingSequenceInfo[sequenceKey] = [NSDate date];
        [self.simplePing sendPingWithData:self.pingOption.preload];
    }
}

- (void)checkPingSequenceState{
    NSDate *currentDate = [NSDate date];
    NSArray *sequenceKeys = [self.pingSequenceInfo.allKeys copy];
    for (NSString *sequenceKey in sequenceKeys) {
        NSDate *date = self.pingSequenceInfo[sequenceKey];
        if ([self.pingOption isTimeoutForTime:[currentDate timeIntervalSinceDate:date]]) {
            self.sentPacketsCount += 1;
            [self.pingSequenceInfo removeObjectForKey:sequenceKey];
            if ([self.delegate respondsToSelector:@selector(ping:timeout:)]) {
                [self.delegate ping:self timeout:[sequenceKey intValue]];
            }
        }
    }
}

- (BOOL)hasUnreceiveResponsePing{
    return self.pingSequenceInfo.count > 0;
}


//MARK: -- timer --
- (void)createTimer{
    
    NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:self.pingOption.interval target:self selector:@selector(timeAction) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    [timer fire];
    self.pingTimer = timer;
}

- (void)invalidateTimer{
    [self.pingTimer invalidate];
    self.pingTimer = nil;
}

- (void)timeAction{
    [self checkPingSequenceState];

    if (![self.pingOption canPing:self.simplePing.nextSequenceNumber]) {
        if (![self hasUnreceiveResponsePing]) {
            [self stopPing];
        }
    } else {
        [self ping];
    }
}

//MARK: --- QNSimplePingDelegate ---
- (void)simplePing:(QNSimplePing *)pinger didStartWithAddress:(NSData *)address{
    
    self.currentPingIP = [self getAddressFromData:pinger.hostAddress];
    if ([self.delegate respondsToSelector:@selector(ping:didStart:)]) {
        [self.delegate ping:self didStart:self.pingOption.preload.length];
    }
}

- (void)simplePing:(QNSimplePing *)pinger didFailWithError:(NSError *)error{
}

- (void)simplePing:(QNSimplePing *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber{
}

- (void)simplePing:(QNSimplePing *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error{
}

- (void)simplePing:(QNSimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber{
    
    NSString *sequenceKey = [NSString stringWithFormat:@"%d", sequenceNumber];
    NSDate *date = self.pingSequenceInfo[sequenceKey];
    if (date == nil) {
        return;
    }
    
    self.sentPacketsCount += 1;
    self.receivedPacketsCount += 1;
    [self.pingSequenceInfo removeObjectForKey:sequenceKey];
    
    if ([self.delegate respondsToSelector:@selector(ping:receivePacket:spendTime:dataBytesLength:)]) {
        int spendTime = [[NSDate date] timeIntervalSinceDate:date] * 1000;
        [self.delegate ping:self receivePacket:sequenceNumber spendTime:spendTime dataBytesLength:packet.length];
    }
    
    if (![self.pingOption canPing:self.simplePing.nextSequenceNumber]) {
        if (![self hasUnreceiveResponsePing]) {
            [self stopPing];
        }
    }
}

- (void)simplePing:(QNSimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet{
}

- (NSString *)getAddressFromData:(NSData *)addressData{
    NSString *addressString = nil;
    if (addressData) {
        char addressChar[NI_MAXHOST];
        int error = getnameinfo([addressData bytes], (socklen_t)[addressData length], addressChar, sizeof(addressChar), NULL, 0, NI_NUMERICHOST);
        if (error == 0) {
            addressString = [NSString stringWithCString:addressChar encoding:NSUTF8StringEncoding];
        }
    }
    return addressString;
}

@end
