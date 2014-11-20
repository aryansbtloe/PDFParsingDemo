//
//  AKSPDFHelper.h
//
//  Created by Sorin Nistor on 4/7/11.
//  Copyright 2011 iPDFdev.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MFDocumentManager.h"

@interface PDFGraphicsState : NSObject {
    CGAffineTransform currentTransformationMatrix;
}

@property (readwrite, assign) CGAffineTransform currentTransformationMatrix;

- (id)init;
- (id)initWithGraphicState:(PDFGraphicsState *)gs;

@end

typedef void (^operationFinishedBlock)(NSString * text,NSMutableArray * images);

@interface AKSPDFHelper : NSObject {
    NSMutableArray *graphicsStates;
    NSMutableArray *imagesInfo;
    CGPDFContentStreamRef contentStream;
}

@property (nonatomic, copy) operationFinishedBlock operationFinishedBlock;

- (id)initWithContentStream:(CGPDFContentStreamRef)cs;
- (void)dealloc;
- (NSMutableArray *)graphicsStates;
- (NSMutableArray *)imagesInfo;
- (void)scanContentStream:(CGAffineTransform)initialCTM;
- (long)getPageCountForPDFDocWithPath:(NSString*)filePath;
- (void)getTextAndImagesOnPage:(int)pageNo ForPDFDocWithPath:(NSString*)filePath didFinished:(operationFinishedBlock)finishedBlock;


static void op_q(CGPDFScannerRef s, void *info);
static void op_Q(CGPDFScannerRef s, void *info);
static void op_cm(CGPDFScannerRef s, void *info);
static void op_Do(CGPDFScannerRef s, void *info);

@end
