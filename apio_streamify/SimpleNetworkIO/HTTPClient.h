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

#import <Foundation/Foundation.h>

@interface HTTPClient : NSObject<NSURLConnectionDelegate>
{
    // attributi privati della classe
    void (^_callprevious)();
    void (^_callduring)();
    void (^_callback)();
    NSURLConnection *_connection;
    NSMutableData *_responseobject;
}

// attributi pubblici della classe
@property (nonatomic, retain) NSString *postString;
@property (nonatomic, retain) NSData *postData;
@property (nonatomic, retain) NSDictionary* responsedata;
@property (nonatomic, retain) NSMutableURLRequest *request;
@property BOOL isObtainingConnectionTimout;

// metodi pubblici della classe
-(void) connect:(NSURL*)url
    beforeStart:(void(^)())callprevious
duringConnection:(void(^)())callduring
  afterComplete:(void(^)())callback;

-(void) connect:(NSURL*)url
         method:(NSString*)method
    beforeStart:(void(^)())callprevious
duringConnection:(void(^)())callduring
  afterComplete:(void(^)())callback;

-(void) connect:(NSURL*)url
         method:(NSString*)method
           type:(NSString*)type
    beforeStart:(void(^)())callprevious
duringConnection:(void(^)())callduring
  afterComplete:(void(^)())callback;

-(void) cancel;

@end
