//
//  ViewController.h
//  PDFParsingDemo
//
//  Created by Alok Singh on 21/11/14.
//  Copyright (c) 2014 Alok Singh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AKSPDFHelper.h"

@interface ViewController : UIViewController<UIWebViewDelegate>

@property (nonatomic, retain) AKSPDFHelper *  pdfHelper;
@property(nonatomic,retain)UIWebView * webView;

@property(nonatomic,retain)NSMutableArray * imagesExtracted;
@property(nonatomic,retain)IBOutlet UIImageView * imageView;

@end

