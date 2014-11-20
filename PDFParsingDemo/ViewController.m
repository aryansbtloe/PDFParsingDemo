//
//  ViewController.m
//  PDFParsingDemo
//
//  Created by Alok Singh on 21/11/14.
//  Copyright (c) 2014 Alok Singh. All rights reserved.
//

#import "ViewController.h"
#import "AKSPDFHelper.h"

@interface ViewController ()

@end

@implementation ViewController

@synthesize pdfHelper;
@synthesize webView;
@synthesize imageView;
@synthesize imagesExtracted;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self showExtractedImages];
    [self testTextAndImagesExtractionPDF];
    [self testTextAndImagesExtractionDOCX];
}

- (void)testTextAndImagesExtractionPDF{
    int samplePDFNo = 1;
    NSLog(@"\n\n\nWORKING WITH PDF: sample%d.pdf\n\n",samplePDFNo);
    NSString *documentPathString = [[NSBundle mainBundle]pathForResource:[NSString stringWithFormat:@"sample%d",samplePDFNo] ofType:@"pdf"];
    pdfHelper = [[AKSPDFHelper alloc]init];
    [pdfHelper getTextAndImagesOnPage:1 ForPDFDocWithPath:documentPathString didFinished:^(NSString *text, NSMutableArray *images) {
        NSLog(@"TEXT EXTRACTED FROM PDF: %@\n",text);
        NSLog(@"IMAGES EXTRACTED COUNT FROM PDF: %lu",(unsigned long)[images count]);
        imagesExtracted = images;
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self testTextAndImagesExtractionPDF];
    });
}

- (void)testTextAndImagesExtractionDOCX{
    webView =  [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle]pathForResource:@"sample" ofType:@"docx"]]];
    [webView loadRequest:request];
    webView.delegate = self;
    [self.view addSubview:webView];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView{
    NSString *scriptForText = @"document.documentElement.innerText";
    NSString *text = [webView stringByEvaluatingJavaScriptFromString:scriptForText];
    NSLog(@"\n\nTEXT EXTRACTED FROM DOC: %@\n\n",text);
}

- (void)showExtractedImages{
    static int counter = -1;
    counter++;
    if (imagesExtracted.count>0) {
    if (counter>=imagesExtracted.count) {
        counter = 0;
    }
    [imageView setImage:[imagesExtracted objectAtIndex:counter]];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self showExtractedImages];
    });
}

@end
