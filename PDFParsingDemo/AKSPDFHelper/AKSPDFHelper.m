//
//  AKSPDFHelper.m
//
//  Created by Sorin Nistor on 4/7/11.
//  Copyright 2011 iPDFdev.com. All rights reserved.
//

#import "AKSPDFHelper.h"

@implementation PDFGraphicsState

@synthesize currentTransformationMatrix;

- (id)init {
    self = [super init];
    if (self) {
        currentTransformationMatrix = CGAffineTransformMake(1, 0, 0, 1, 0, 0);
    }
    
    return self;
}

- (id)initWithGraphicState:(PDFGraphicsState *)gs {
    self = [super init];
    if (self) {
        self.currentTransformationMatrix = gs.currentTransformationMatrix;
    }
    
    return self;
}

@end


@implementation AKSPDFHelper

@synthesize operationFinishedBlock;

- (id)initWithContentStream:(CGPDFContentStreamRef)cs {
    self = [super init];
    if (self) {
        graphicsStates = [[NSMutableArray alloc] init];
        imagesInfo = [[NSMutableArray alloc] init];
        contentStream = cs;
        CGPDFContentStreamRetain(contentStream);
    }
    return self;
} 

- (void)dealloc {
    CGPDFContentStreamRelease(contentStream);
}

- (NSMutableArray *)graphicsStates {
    return graphicsStates;
}

- (NSMutableArray *)imagesInfo {
    return imagesInfo;
}

- (void)scanContentStream:(CGAffineTransform)initialCTM {
    PDFGraphicsState *gs = [[PDFGraphicsState alloc] init];
    gs.currentTransformationMatrix = initialCTM;
    [graphicsStates addObject: gs];
    
    CGPDFOperatorTableRef operatorTable = CGPDFOperatorTableCreate();
    CGPDFOperatorTableSetCallback(operatorTable, "q", &op_q);
    CGPDFOperatorTableSetCallback(operatorTable, "Q", &op_Q);
    CGPDFOperatorTableSetCallback(operatorTable, "cm", &op_cm);
    CGPDFOperatorTableSetCallback(operatorTable, "Do", &op_Do);
    
    CGPDFScannerRef contentStreamScanner = CGPDFScannerCreate(contentStream, operatorTable, (__bridge void *)(self));
    CGPDFScannerScan(contentStreamScanner);
    
    CGPDFScannerRelease(contentStreamScanner);
    CGPDFOperatorTableRelease(operatorTable);
    
    [graphicsStates removeAllObjects];
}

static void op_q(CGPDFScannerRef s, void *info) {
    AKSPDFHelper *csp = (__bridge AKSPDFHelper *)info;
    
    // Operator q saves the current graphic state on the stack.
    // Make of copy of the current graphic state (last object in the graphicStates array) and put it on the stack.
    PDFGraphicsState *currentGS = [csp.graphicsStates lastObject];
    PDFGraphicsState *newGS = [[PDFGraphicsState alloc] initWithGraphicState: currentGS];
    [csp.graphicsStates addObject: newGS];
}

static void op_Q(CGPDFScannerRef s, void *info) {
    // Operator Q restores the previous graphic state.
    // The current graphic state is removed from the stack, the previous one becomes current
    AKSPDFHelper *csp = (__bridge AKSPDFHelper *)info;
    [csp.graphicsStates removeLastObject];
}

static void op_cm(CGPDFScannerRef s, void *info) {
    CGPDFReal a = -1, b = -1, c = -1, d = -1, tx = -1, ty = -1;
    
    if (!CGPDFScannerPopNumber(s, &ty)) {
        return;
    }

    if (!CGPDFScannerPopNumber(s, &tx)) {
        return;
    }

    if (!CGPDFScannerPopNumber(s, &d)) {
        return;
    }

    if (!CGPDFScannerPopNumber(s, &c)) {
        return;
    }

    if (!CGPDFScannerPopNumber(s, &b)) {
        return;
    }

    if (!CGPDFScannerPopNumber(s, &a)) {
        return;
    }
    
    // Operator cm multiplies the current transformation matrix with the matrix specifies as parameter.
    CGAffineTransform ctm = CGAffineTransformMake(a, b, c, d, tx, ty);
    AKSPDFHelper *csp = (__bridge AKSPDFHelper *)info;
    PDFGraphicsState *gs = [csp.graphicsStates lastObject];
    gs.currentTransformationMatrix = CGAffineTransformConcat(ctm, gs.currentTransformationMatrix);
}




CGFloat *decodeValuesFromImgDictionary(CGPDFDictionaryRef dict, CGColorSpaceRef cgColorSpace, NSInteger bitsPerComponent) {
    CGFloat *decodeValues = NULL;
    CGPDFArrayRef decodeArray = NULL;
    
    if (CGPDFDictionaryGetArray(dict, "Decode", &decodeArray)) {
        size_t count = CGPDFArrayGetCount(decodeArray);
        decodeValues = malloc(sizeof(CGFloat) * count);
        CGPDFReal realValue;
        int i;
        for (i = 0; i < count; i++) {
            CGPDFArrayGetNumber(decodeArray, i, &realValue);
            decodeValues[i] = realValue;
        }
    } else {
        size_t n;
        switch (CGColorSpaceGetModel(cgColorSpace)) {
            case kCGColorSpaceModelMonochrome:
                decodeValues = malloc(sizeof(CGFloat) * 2);
                decodeValues[0] = 0.0;
                decodeValues[1] = 1.0;
                break;
            case kCGColorSpaceModelRGB:
                decodeValues = malloc(sizeof(CGFloat) * 6);
                for (int i = 0; i < 6; i++) {
                    decodeValues[i] = i % 2 == 0 ? 0 : 1;
                }
                break;
            case kCGColorSpaceModelCMYK:
                decodeValues = malloc(sizeof(CGFloat) * 8);
                for (int i = 0; i < 8; i++) {
                    decodeValues[i] = i % 2 == 0 ? 0.0 :
                    1.0;
                }
                break;
            case kCGColorSpaceModelLab:
                // ????
                break;
            case kCGColorSpaceModelDeviceN:
                n =
                CGColorSpaceGetNumberOfComponents(cgColorSpace) * 2;
                decodeValues = malloc(sizeof(CGFloat) * (n *
                                                         2));
                for (int i = 0; i < n; i++) {
                    decodeValues[i] = i % 2 == 0 ? 0.0 :
                    1.0;
                }
                break;
            case kCGColorSpaceModelIndexed:
                decodeValues = malloc(sizeof(CGFloat) * 2);
                decodeValues[0] = 0.0;
                decodeValues[1] = pow(2.0,
                                      (double)bitsPerComponent) - 1;
                break;
            default:
                break;
        }
    }
    
    return (CGFloat *)decodeValues;
}


UIImage *getImgRef(CGPDFStreamRef myStream) {
    CGPDFArrayRef colorSpaceArray = NULL;
    CGPDFStreamRef dataStream;
    CGPDFDataFormat format;
    CGPDFDictionaryRef dict;
    CGPDFInteger width, height, bps, spp;
    CGPDFBoolean interpolation = 0;
    //  NSString *colorSpace = nil;
    CGColorSpaceRef cgColorSpace;
    const char *name = NULL, *colorSpaceName = NULL, *renderingIntentName = NULL;
    CFDataRef imageDataPtr = NULL;
    CGImageRef cgImage;
    //maskImage = NULL,
    CGImageRef sourceImage = NULL;
    CGDataProviderRef dataProvider;
    CGColorRenderingIntent renderingIntent;
    CGFloat *decodeValues = NULL;
    UIImage *image;
    
    if (myStream == NULL)
        return nil;
    
    dataStream = myStream;
    dict = CGPDFStreamGetDictionary(dataStream);
    
    // obtain the basic image information
    if (!CGPDFDictionaryGetName(dict, "Subtype", &name))
        return nil;
    
    if (strcmp(name, "Image") != 0)
        return nil;
    
    if (!CGPDFDictionaryGetInteger(dict, "Width", &width))
        return nil;
    
    if (!CGPDFDictionaryGetInteger(dict, "Height", &height))
        return nil;
    
    if (!CGPDFDictionaryGetInteger(dict, "BitsPerComponent", &bps))
        return nil;
    
    if (!CGPDFDictionaryGetBoolean(dict, "Interpolate", &interpolation))
        interpolation = NO;
    
    if (!CGPDFDictionaryGetName(dict, "Intent", &renderingIntentName))
        renderingIntent = kCGRenderingIntentDefault;
    else{
        renderingIntent = kCGRenderingIntentDefault;
        //      renderingIntent = renderingIntentFromName(renderingIntentName);
    }
    
    imageDataPtr = CGPDFStreamCopyData(dataStream, &format);
    dataProvider = CGDataProviderCreateWithCFData(imageDataPtr);
    CFRelease(imageDataPtr);
    
    if (CGPDFDictionaryGetArray(dict, "ColorSpace", &colorSpaceArray)) {
        cgColorSpace = CGColorSpaceCreateDeviceRGB();
        //      cgColorSpace = colorSpaceFromPDFArray(colorSpaceArray);
        spp = CGColorSpaceGetNumberOfComponents(cgColorSpace);
    } else if (CGPDFDictionaryGetName(dict, "ColorSpace", &colorSpaceName)) {
        if (strcmp(colorSpaceName, "DeviceRGB") == 0) {
            cgColorSpace = CGColorSpaceCreateDeviceRGB();
            //          CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
            spp = 3;
        } else if (strcmp(colorSpaceName, "DeviceCMYK") == 0) {
            cgColorSpace = CGColorSpaceCreateDeviceCMYK();
            //          CGColorSpaceCreateWithName(kCGColorSpaceGenericCMYK);
            spp = 4;
        } else if (strcmp(colorSpaceName, "DeviceGray") == 0) {
            cgColorSpace = CGColorSpaceCreateDeviceGray();
            //          CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
            spp = 1;
        } else if (bps == 1) { // if there's no colorspace entry, there's still one we can infer from bps
            cgColorSpace = CGColorSpaceCreateDeviceGray();
            //          colorSpace = NSDeviceBlackColorSpace;
            spp = 1;
        }
    }
    
    decodeValues = decodeValuesFromImgDictionary(dict, cgColorSpace, bps);
    
    int rowBits = bps * spp * width;
    int rowBytes = rowBits / 8;
    // pdf image row lengths are padded to byte-alignment
    if (rowBits % 8 != 0)
        ++rowBytes;
    
    //  maskImage = SMaskImageFromImageDictionary(dict);
    
    if (format == CGPDFDataFormatRaw)
    {
        sourceImage = CGImageCreate(width, height, bps, bps * spp, rowBytes, cgColorSpace, 0, dataProvider, decodeValues, interpolation, renderingIntent);
        CGDataProviderRelease(dataProvider);
        cgImage = sourceImage;
        //      if (maskImage != NULL) {
        //          cgImage = CGImageCreateWithMask(sourceImage, maskImage);
        //          CGImageRelease(sourceImage);
        //          CGImageRelease(maskImage);
        //      } else {
        //          cgImage = sourceImage;
        //      }
    } else {
        if (format == CGPDFDataFormatJPEGEncoded){ // JPEG data requires a CGImage; AppKit can't decode it {
            sourceImage =
            CGImageCreateWithJPEGDataProvider(dataProvider,decodeValues,interpolation,renderingIntent);
            CGDataProviderRelease(dataProvider);
            cgImage = sourceImage;
            //          if (maskImage != NULL) {
            //              cgImage = CGImageCreateWithMask(sourceImage,maskImage);
            //              CGImageRelease(sourceImage);
            //              CGImageRelease(maskImage);
            //          } else {
            //              cgImage = sourceImage;
            //          }
        }
        // note that we could have handled JPEG with ImageIO as well
        else if (format == CGPDFDataFormatJPEG2000) { // JPEG2000 requires ImageIO {
            CFDictionaryRef dictionary = CFDictionaryCreate(NULL, NULL, NULL, 0, NULL, NULL);
            sourceImage=
            CGImageCreateWithJPEGDataProvider(dataProvider, decodeValues, interpolation, renderingIntent);
            
            
            //          CGImageSourceRef cgImageSource = CGImageSourceCreateWithDataProvider(dataProvider, dictionary);
            CGDataProviderRelease(dataProvider);
            
            cgImage=sourceImage;
            
            //          cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, dictionary);
            CFRelease(dictionary);
        } else // some format we don't know about or an error in the PDF
            return nil;
    }
    image=[UIImage imageWithCGImage:cgImage];
    return image;
}

static void op_Do(CGPDFScannerRef s, void *info) {
    const char *imageLabel;
    
    if (!CGPDFScannerPopName(s, &imageLabel)) {
        return;
    }

    AKSPDFHelper *csp = (__bridge AKSPDFHelper *)info;
    PDFGraphicsState *gs = [csp.graphicsStates lastObject];
    CGAffineTransform ctm = gs.currentTransformationMatrix;
    
    CGPDFContentStreamRef cs = CGPDFScannerGetContentStream(s);
    CGPDFObjectRef imageObject = CGPDFContentStreamGetResource(cs, "XObject", imageLabel);
    CGPDFStreamRef xObjectStream;
    if (CGPDFObjectGetValue(imageObject, kCGPDFObjectTypeStream, &xObjectStream)) {
        CGPDFDictionaryRef xObjectDictionary = CGPDFStreamGetDictionary(xObjectStream);
        
        const char *subtype;
        CGPDFDictionaryGetName(xObjectDictionary, "Subtype", &subtype);
        if (strcmp(subtype, "Image") == 0) {
            UIImage * image = getImgRef(xObjectStream);
            if (image) {
                [csp.imagesInfo addObject: image];
            }
        }
        else {
            if (strcmp(subtype, "Form") == 0) {
                CGPDFArrayRef matrixArray;
                // Form XObject may have their own matrix that is concatenated with the current transformation matrix
                // before the form XObject is drawn.
                if (CGPDFDictionaryGetArray(xObjectDictionary, "Matrix", &matrixArray)) {
                    if (CGPDFArrayGetCount(matrixArray) == 6) {
                        CGPDFReal m11 = -1, m12 = -1, m21 = -1, m22 = -1, tx = -1, ty = -1;
                        if (CGPDFArrayGetNumber(matrixArray, 0, &m11) &&
                            CGPDFArrayGetNumber(matrixArray, 1, &m12) &&
                            CGPDFArrayGetNumber(matrixArray, 2, &m21) &&
                            CGPDFArrayGetNumber(matrixArray, 3, &m22) &&
                            CGPDFArrayGetNumber(matrixArray, 4, &tx) &&
                            CGPDFArrayGetNumber(matrixArray, 5, &ty)) {
                            CGAffineTransform matrix = CGAffineTransformMake(m11, m12, m21, m22, tx, ty);
                            ctm = CGAffineTransformConcat(ctm, matrix);
                        }
                    }
                }
                CGPDFDictionaryRef formXObjectResourcesDictionary;
                CGPDFDictionaryGetDictionary(xObjectDictionary, "Resources", &formXObjectResourcesDictionary);
                CGPDFContentStreamRef formXObjectContentStream = 
                    CGPDFContentStreamCreateWithStream(xObjectStream, formXObjectResourcesDictionary, cs);
                AKSPDFHelper *formXObjectCSP = 
                    [[AKSPDFHelper alloc] initWithContentStream: formXObjectContentStream];
                [formXObjectCSP scanContentStream: ctm];
                
                [csp.imagesInfo addObjectsFromArray: formXObjectCSP.imagesInfo];
                
            }
        }
    }
    
}

- (long)getPageCountForPDFDocWithPath:(NSString*)filePath{
    NSURL *documentPathUrl = [NSURL fileURLWithPath:filePath];
    if (documentPathUrl) {
        CGPDFDocumentRef document = CGPDFDocumentCreateWithURL((CFURLRef)documentPathUrl);
        return CGPDFDocumentGetNumberOfPages(document);
    }
    return 0;
}

- (void)getTextAndImagesOnPage:(int)pageNo ForPDFDocWithPath:(NSString*)filePath didFinished:(operationFinishedBlock)finishedBlock{
    NSURL *documentPathUrl = [NSURL fileURLWithPath:filePath];
    if (documentPathUrl) {
        CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef)documentPathUrl);
        long noOfPages = CGPDFDocumentGetNumberOfPages(pdf);
        if (pageNo<=noOfPages) {
            CGPDFPageRef page = CGPDFDocumentGetPage(pdf, pageNo);
            CGPDFPageRetain(page);
            contentStream = CGPDFContentStreamCreateWithPage(page);
            graphicsStates = [[NSMutableArray alloc] init];
            imagesInfo = [[NSMutableArray alloc] init];
            CGPDFContentStreamRetain(contentStream);
            //scanning for images
            [self scanContentStream: CGAffineTransformMake(1, 0, 0, 1, 0, 0)];
            MFDocumentManager* object = [[[MFDocumentManager alloc] init]initWithFileUrl:documentPathUrl];
            NSString * text = [object wholeTextForPage:pageNo];
            finishedBlock(text,imagesInfo);
        }else{
            finishedBlock(nil,nil);
        }
    }else{
        finishedBlock(nil,nil);
    }
}

@end
