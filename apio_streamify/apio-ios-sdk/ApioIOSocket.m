//
//  ApioIOSocket.m
//
/*
 The MIT License (MIT)
 
 Copyright (c) 2015 Matteo Pio Napolitano
 matteopio.napolitano@oncreate.it
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "ApioIOSocket.h"

@interface ApioIOSocket () {
    NSString *_host;
    NSString *_port;
    SIOSocket *_socket;
}

@end

@implementation ApioIOSocket

- (id)init
{
    self = [super init];
    if (self) {
        NSString *hostString = [[_host stringByAppendingString:@":"] stringByAppendingString:_port];
        [SIOSocket socketWithHost: hostString response: ^(SIOSocket *socket) {
            _socket = socket;
            
            __weak typeof(self) weakSelf = self;
            _socket.onDisconnect = ^{
                [weakSelf.delegate onSocketDisconnected];
            };
            
            _socket.onError = ^(NSDictionary* error){
                [weakSelf.delegate onSocketError:error];
            };
            
            _socket.onReconnect = ^(NSInteger numberOfAttempts){
                [weakSelf.delegate onSocketReconnect];
            };
            
            _socket.onReconnectionAttempt = ^(NSInteger numberOfAttempts){
                // do nothing
            };
            
            _socket.onReconnectionError = ^(NSDictionary *errorInfo){
                [weakSelf.delegate onSocketDisconnected];
            };
            
            HTTPClient *client = [[HTTPClient alloc] init];
            NSString *payload = [hostString stringByAppendingString:@"/apio/objects"];
            NSURL *url = [NSURL URLWithString: payload];
            [client connect:url
                     method:@"GET"
                beforeStart:^{}
           duringConnection:^{}
              afterComplete:^{
                  NSDictionary *responsedata = [client responsedata];
                  if (responsedata != nil) {
                      dispatch_async(dispatch_get_main_queue(), ^{
                          [self.delegate onSocketReady:responsedata];
                          NSLog(@"[ApioIOSocket] The server.io socket is now ready!");
                          
                          // activating APIO callbacks
                          [_socket on:@"apio_server_update" callback:^(NSArray *args) {
                              NSLog(@"[ApioIOSocket] Event receiver listening..");
                              [self.delegate onEventReceived:args];
                          }];
                      });
                  }
                  else {
                      dispatch_async(dispatch_get_main_queue(), ^{
                          [self.delegate onSocketConnectionFailed];
                          NSLog(@"[ApioIOSocket] Error getting initial state configuration!");
                      });
                  }
              }];
        }];
    }
    return self;
}

- (id)initWithHost:(NSString*)host andPort:(NSString*)port
{
    _host = host;
    _port = port;
    return [self init];
}

- (void)emit:(NSString*)event
{
    [self emit:event data:nil];
}

- (void)emit:(NSString*)event data:(NSDictionary *)data
{
    [_socket emit:event args:data];
}

- (void)close
{
    [_socket close];
}

@end