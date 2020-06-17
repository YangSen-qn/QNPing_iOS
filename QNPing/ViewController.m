//
//  ViewController.m
//  QNPing
//
//  Created by yangsen on 2020/6/16.
//  Copyright © 2020 yangsen. All rights reserved.
//

#import "ViewController.h"
#import "QNPing.h"

@interface ViewController ()<QNPingDelegate>

@property(nonatomic, strong)NSMutableArray  *pingList;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
}
- (IBAction)startAction:(UIButton *)sender {
    [self stopAction:sender];
    
    if (_pingList == nil) {
        _pingList = [NSMutableArray array];
    }
    
    for (int i=0; i<1; i++) {
        NSString *address = nil;
        if (i%3 == 0) {
            address = @"up.qiniu.com";
        } else if (i%3 == 1) {
            address = @"124.160.148.59";
        } else {
            address = @"101.67.18.144";
            address = @"124.160.115.113";
        }
        QNPing *ping = [QNPing ping:address config:^(QNPingOption * _Nonnull option) {
            option.count = 2;
            option.interval = 2;
        }];
        ping.delegate = self;
        [ping startPing];
        [_pingList addObject:ping];
    }
}

- (IBAction)stopAction:(UIButton *)sender {
    for (QNPing *ping in _pingList) {
        [ping stopPing];
    }
    _pingList = nil;
}


- (void)ping:(QNPing *)ping didStart:(uint16_t)dataBytesLength{
    NSLog(@"Ping %@ (%@): %d data bytes", ping.address, ping.currentPingIP, dataBytesLength);
}

- (void)ping:(QNPing *)ping timeout:(uint16_t)sequenceNumber{
    NSLog(@"Request timeout for icmp_seq %d", sequenceNumber);
}


- (void)ping:(QNPing *)ping receivePacket:(uint16_t)sequenceNumber spendTime:(int)spendTime dataBytesLength:(uint16_t)dataBytesLength{
    NSLog(@"%d bytes from %@: icmp_seq=%d time=%d ms", dataBytesLength, ping.address, sequenceNumber, spendTime);
}

- (void)ping:(QNPing *)ping completeWithSentPacketsCount:(uint16_t)sendPacketsCount receivedPacketsCount:(uint16_t)receivedPacketsCount{
    NSLog(@"%d packets transmitted, %d packets received, %.1f%@ packet loss", sendPacketsCount, receivedPacketsCount, (sendPacketsCount - receivedPacketsCount) * 100.0 / sendPacketsCount, @"%");
}

@end
