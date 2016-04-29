//
//  ViewController.m
//  PlayWeathr
//
//  Created by Hannah Carney on 5/13/15.
//  Copyright (c) 2015 Hannah Carney. All rights reserved.
//

#import "ViewController.h"
#import "ViewManager.h"
#import "NSString+SBJSON.h"
#import <LBBlurredImage/UIImageView+LBBlurredImage.h>

@interface ViewController ()

@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) UIImage *backgroundFromFlickr;
@property (nonatomic, strong) UIImageView *blurredImageView;
@property (nonatomic, strong) UIImage *blurredImage;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) CGFloat screenHeight;

@property (nonatomic, strong) NSDateFormatter *dailyFormatter;

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)searchFlickrPhotos:(NSString *)text;

@end

NSString *const FlickrAPIKey = @"9eb9449f0e7fd4350dc97be3d6a3b4fe";

@implementation ViewController

- (id)init {
    if (self = [super init]) {
        _dailyFormatter = [[NSDateFormatter alloc] init];
        _dailyFormatter.dateFormat = @"EEEE";

        
        // Initialize our arrays
        photoTitles = [[NSMutableArray alloc] init];
        photoURLsLargeImage = [[NSMutableArray alloc] init];
    
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    [[RACObserve([ViewManager sharedManager], currentCondition)
      deliverOn:RACScheduler.mainThreadScheduler]
     subscribeNext:^(ViewCondition *newCondition) {
         if (newCondition.locationName != nil) {
          [self searchFlickrPhotos: ([newCondition.locationName stringByReplacingOccurrencesOfString:@" " withString:@""])];
            NSLog(@"Location name = %@", newCondition.locationName);
         }
     }
     
     ];
    
    [[RACObserve([ViewManager sharedManager], dailyForecast)
      deliverOn:RACScheduler.mainThreadScheduler]
     subscribeNext:^(NSArray *newForecast) {
     }];
    
    
    [[ViewManager sharedManager] findCurrentLocation];
     }

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    CGRect bounds = self.view.bounds;
    
    self.backgroundImageView.frame = bounds;
    self.blurredImageView.frame = bounds;
    self.tableView.frame = bounds;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MIN([[ViewManager sharedManager].dailyForecast count], 7) + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"CellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (! cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];
    cell.textLabel.textColor = [UIColor whiteColor];
    
    if(indexPath.section == 0) {
        if(indexPath.row == 0) {
            [self configureHeaderCell:cell title:@"Daily Forecast"];
        }
        else {
            ViewCondition *weather = [ViewManager sharedManager].dailyForecast[indexPath.row - 1];
            [self configureDailyCell:cell weather:weather];
        }
    }
    
    return cell;
}

- (void)configureHeaderCell:(UITableViewCell *)cell title:(NSString *)title {
    cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:18];
    cell.textLabel.text = title;
    cell.detailTextLabel.text = @"";
    cell.imageView.image = nil;
}

- (void)configureDailyCell:(UITableViewCell *)cell weather:(ViewCondition *)weather {
    cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:18];
    cell.detailTextLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:18];
    cell.textLabel.text = [self.dailyFormatter stringFromDate:weather.date];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f° / %.0f°",
                                 weather.tempHigh.floatValue,
                                 weather.tempLow.floatValue];
    cell.detailTextLabel.textColor = [UIColor whiteColor];
    cell.imageView.image = [UIImage imageNamed:[weather imageName]];
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Store incoming data into a string
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSLog(@"jsonString: %@", jsonString);
    
    // Create a dictionary from the JSON string
    NSDictionary *results = [jsonString JSONValue];
    
    // Build an array from the dictionary for easy access to each entry
    NSArray *photos = [[results objectForKey:@"photos"] objectForKey:@"photo"];
    
    // Loop through each entry in the dictionary...
    for (NSDictionary *photo in photos)
    {
        // Build the URL to where the image is stored (see the Flickr API)
        // In the format https://farmX.static.flickr.com/server/id/secret
        NSString *photoURLString = [NSString stringWithFormat:@"https://farm%@.static.flickr.com/%@/%@_%@.jpg", [photo objectForKey:@"farm"], [photo objectForKey:@"server"], [photo objectForKey:@"id"], [photo objectForKey:@"secret"]];
        [photoURLsLargeImage addObject:[NSURL URLWithString:photoURLString]];
        
        NSLog(@"photoURLsLargeImage: %@\n\n", photoURLString);
        
        NSData * imageData = [[NSData alloc] initWithContentsOfURL: [NSURL URLWithString: (photoURLString)]];
        self.backgroundFromFlickr = [UIImage imageWithData: imageData];
        [imageData release];
        [self replaceBackground];
    }
}

-(void)searchFlickrPhotos:(NSString *)text
{
    // Build the string to call the Flickr API
    NSString *urlString = [NSString stringWithFormat:@"https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=%@&tags=%@&in_gallery=true@&per_page=1&format=json&nojsoncallback=1", FlickrAPIKey, text];
    
    // Create NSURL string from formatted string
    NSURL *url = [NSURL URLWithString:urlString];
    
    // Setup and start async download
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL: url];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *connection = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
        if (url == nil)
        {
            [self defaultBackground];
        }
        NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        NSLog(@"jsonString: %@", jsonString);
        
        // Create a dictionary from the JSON string
        NSDictionary *results = [jsonString JSONValue];
        
        // Build an array from the dictionary for easy access to each entry
        NSArray *photos = [[results objectForKey:@"photos"] objectForKey:@"photo"];
        
        // Loop through each entry in the dictionary...
        for (NSDictionary *photo in photos)
        {
            // Build the URL to where the image is stored (see the Flickr API)
            // In the format https://farmX.static.flickr.com/server/id/secret
            NSString *photoURLString = [NSString stringWithFormat:@"https://farm%@.static.flickr.com/%@/%@_%@.jpg", [photo objectForKey:@"farm"], [photo objectForKey:@"server"], [photo objectForKey:@"id"], [photo objectForKey:@"secret"]];
            [photoURLsLargeImage addObject:[NSURL URLWithString:photoURLString]];
            
            NSLog(@"photoURLsLargeImage: %@\n\n", photoURLString);
            
            NSData * imageData = [[NSData alloc] initWithContentsOfURL: [NSURL URLWithString: (photoURLString)]];
            self.backgroundFromFlickr = [UIImage imageWithData: imageData];
            [imageData release];
            [self replaceBackground];

        }
    }];
    [connection resume];

  }


#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger cellCount = [self tableView:tableView numberOfRowsInSection:indexPath.section];
    return self.screenHeight / (CGFloat)cellCount;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat height = scrollView.bounds.size.height;
    CGFloat position = MAX(scrollView.contentOffset.y, 0.0);
    
    CGFloat percent = MIN(position / height, 1.0);
    
    self.blurredImageView.alpha = percent;
}

- (void) defaultBackground {
    UIImage *background = [UIImage imageNamed:@"bg"];
    self.backgroundImageView = [[UIImageView alloc] initWithImage:background];
    self.backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    [self.view addSubview: self.backgroundImageView];
    
    self.blurredImageView = [[UIImageView alloc] init];
    self.blurredImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.blurredImageView.alpha = 0;
    [self.blurredImageView setImageToBlur:background blurRadius:10 completionBlock:nil];
    [self.view addSubview:self.blurredImageView];
    
    [self appSetup];
}

- (void)replaceBackground {
    
    self.backgroundImageView = [[UIImageView alloc] initWithImage:self.backgroundFromFlickr];
    self.backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    [self.view addSubview: self.backgroundImageView];
    
    self.blurredImageView = [[UIImageView alloc] init];
    self.blurredImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.blurredImageView.alpha = 0;
    [self.blurredImageView setImageToBlur:self.backgroundFromFlickr blurRadius:10 completionBlock:nil];
    [self.view addSubview:self.blurredImageView];
    
    [self appSetup];
}

- (void)appSetup {
    
    self.tableView = [[UITableView alloc] init];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorColor = [UIColor colorWithWhite:1 alpha:0.2];
    self.tableView.pagingEnabled = YES;
    [self.view addSubview:self.tableView];
    
    CGRect headerFrame = [UIScreen mainScreen].bounds;
    
    CGFloat inset = 20;
    
    CGFloat temperatureHeight = 150;
    CGFloat hiloHeight = 40;
    CGFloat iconHeight = 30;
    
    CGRect temperatureFrame = CGRectMake(inset,
                                         headerFrame.size.height - (temperatureHeight + hiloHeight),
                                         headerFrame.size.width - (3 * inset),
                                         temperatureHeight);
    
    CGRect iconFrame = CGRectMake(inset,
                                  temperatureFrame.origin.y - iconHeight,
                                  iconHeight,
                                  iconHeight);
    
    CGRect conditionsFrame = iconFrame;
    conditionsFrame.size.width = self.view.bounds.size.width - (((2 * inset) + iconHeight) + 10);
    conditionsFrame.origin.x = iconFrame.origin.x + (iconHeight + 10);
    
    UIView *header = [[UIView alloc] initWithFrame:headerFrame];
    header.backgroundColor = [UIColor clearColor];
    self.tableView.tableHeaderView = header;
    
    // top
    UILabel *cityLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, self.view.bounds.size.width, 30)];
    cityLabel.backgroundColor = [UIColor clearColor];
    cityLabel.textColor = [UIColor whiteColor];
    cityLabel.text = @"Loading...";
    cityLabel.font = [UIFont fontWithName:@"HelveticaNeue-UltraLight-Bold" size:18];
    cityLabel.textAlignment = NSTextAlignmentCenter;
    [header addSubview:cityLabel];
    
    
    // bottom left
    UILabel *temperatureLabel = [[UILabel alloc] initWithFrame:temperatureFrame];
    temperatureLabel.backgroundColor = [UIColor clearColor];
    temperatureLabel.textColor = [UIColor whiteColor];
    temperatureLabel.text = @"0°";
    temperatureLabel.font = [UIFont fontWithName:@"HelveticaNeue-UltraLight" size:120];
    [header addSubview:temperatureLabel];
    
    
    // bottom right
    UILabel *celciusLabel = [[UILabel alloc] initWithFrame:temperatureFrame];
    celciusLabel.backgroundColor = [UIColor clearColor];
    celciusLabel.textColor = [UIColor whiteColor];
    celciusLabel.font = [UIFont fontWithName:@"HelveticaNeue-UltraLight" size:75];
    celciusLabel.textAlignment = NSTextAlignmentRight;
    [header addSubview:celciusLabel];
    
    // bottom left
    UILabel *conditionsLabel = [[UILabel alloc] initWithFrame:conditionsFrame];
    conditionsLabel.backgroundColor = [UIColor clearColor];
    conditionsLabel.font = [UIFont fontWithName:@"HelveticaNeue-UltraLight" size:24];
    conditionsLabel.textColor = [UIColor whiteColor];
    [header addSubview: conditionsLabel];
    
    // bottom left
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:iconFrame];
    [iconView setTintColor:[UIColor blackColor]];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.backgroundColor = [UIColor clearColor];
    [header addSubview:iconView];
        
    [[RACObserve([ViewManager sharedManager], currentCondition)
      deliverOn:RACScheduler.mainThreadScheduler]
     subscribeNext:^(ViewCondition *newCondition) {
         temperatureLabel.text = [NSString stringWithFormat:@"%.0f°",newCondition.temperature.floatValue];
         celciusLabel.text = [NSString stringWithFormat:@"C"];
         conditionsLabel.text = [newCondition.condition capitalizedString];
         cityLabel.text = [newCondition.locationName capitalizedString];
         iconView.image = [UIImage imageNamed:[newCondition imageName]];
     }];
}

@end