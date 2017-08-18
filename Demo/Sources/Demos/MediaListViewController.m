//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MediaListViewController.h"

#import <SRGDataProvider/SRGDataProvider.h>

@interface MediaListViewController ()

@property (nonatomic) SRGDataProvider *dataProvider;
@property (nonatomic, weak) SRGRequest *request;

@property (nonatomic) NSArray<SRGMedia *>*medias;

@end

@implementation MediaListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self reloadData];
}

- (void)reloadData {
    [self.request cancel];
    
    self.title = [self pageTitle];
    
    if (self.mediaListType != MediaListUnknown) {
        
        SRGDataProviderBusinessUnitIdentifier businessUnitIdentifier = nil;
        switch (self.mediaListType) {
            case MediaListLivecenterSRF:
                businessUnitIdentifier = SRGDataProviderBusinessUnitIdentifierSRF;
                break;
            case MediaListLivecenterRTS:
                businessUnitIdentifier = SRGDataProviderBusinessUnitIdentifierRTS;
                break;
            case MediaListLivecenterRSI:
                businessUnitIdentifier = SRGDataProviderBusinessUnitIdentifierRSI;
                break;
            default:
                break;
        }
        self.dataProvider = [[SRGDataProvider alloc] initWithServiceURL:SRGIntegrationLayerProductionServiceURL() businessUnitIdentifier:businessUnitIdentifier];
        SRGRequest *request =  [self.dataProvider liveCenterVideosWithCompletionBlock:^(NSArray<SRGMedia *> * _Nullable medias, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSError * _Nullable error) {
            self.medias = medias;
            [self.tableView reloadData];
        }];
        [request resume];
        self.request = request;
    }
}

- (NSString *)pageTitle
{
    NSString *title = nil;
    switch (self.mediaListType) {
        case MediaListLivecenterSRF:
            title = @"SRF Live center";
            break;
            
        case MediaListLivecenterRTS:
            title = @"RTS Live center";
            break;
            
        case MediaListLivecenterRSI:
            title = @"RSI Live center";
            break;
            
        default:
            title = @"Unknown";
            break;
    }
    
    return title;
}

#pragma mark UITableViewDataSource protocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.medias.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:@"MediaListCell" forIndexPath:indexPath];
}

#pragma mark UITableViewDelegate protocol

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.textLabel.text = self.medias[indexPath.row].title;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.demosViewController openModalPlayerWithURNString:self.medias[indexPath.row].URN.URNString chaptersOnly:NO];
}

@end
