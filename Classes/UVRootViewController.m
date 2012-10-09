//
//  UVWelcomeViewController.m
//  UserVoice
//
//  Created by UserVoice on 12/15/09.
//  Copyright 2009 UserVoice Inc. All rights reserved.
//

#import "UVRootViewController.h"
#import "UVClientConfig.h"
#import "UVToken.h"
#import "UVSession.h"
#import "UVUser.h"
#import "UVWelcomeViewController.h"
#import "UVNewSuggestionViewController.h"
#import "UVSuggestionListViewController.h"
#import "UVNewTicketViewController.h"
#import "UVNetworkUtils.h"
#import "UVSuggestion.h"
#import "UVConfig.h"
#import "NSError+UVExtras.h"
#import "UVStyleSheet.h"
#import "VenioActivityView.h"
#import "ErrorHandler.h"
#import "VNavigationController.h"
#include <QuartzCore/QuartzCore.h>

@implementation UVRootViewController

@synthesize viewToLoad;

- (id)init {
    if (self = [super init]) {
        self.viewToLoad = @"welcome";
    }
    return self;
}

- (id)initWithViewToLoad:(NSString *)theViewToLoad {
    if (self = [super init]) {
        self.viewToLoad = theViewToLoad;
    }
    return self;
}

- (void)didReceiveError:(NSError *)error {
    if ([error isAuthError]) {
        if ([UVToken exists]) {
            [[UVSession currentSession].currentToken remove];
            [UVToken getRequestTokenWithDelegate:self];
        } else {
            ErrorHandler *handler = [[ErrorHandler alloc] init];
            [handler handle:error superView:self.view];
//            [[[[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"UserVoice", nil)
//                                         message:NSLocalizedStringFromTable(@"This application didn't configure UserVoice properly", @"UserVoice", nil)
//                                        delegate:self
//                               cancelButtonTitle:nil
//                               otherButtonTitles:NSLocalizedStringFromTable(@"OK", @"UserVoice", nil), nil] autorelease] show];
        }
    } else {
        [super didReceiveError:error];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    [self dismissUserVoice];
}

- (void)pushNextView {
    [VenioActivityView removeViewAnimated:YES];
    UVSession *session = [UVSession currentSession];
    if ((![UVToken exists] || session.user) && session.clientConfig && [self.navigationController.viewControllers count] == 1) {
//        CATransition* transition = [CATransition animation];
//        transition.duration = 0.3;
//        transition.type = kCATransitionFade;
//        [self.navigationController.view.layer addAnimation:transition forKey:kCATransition];

        UIViewController *welcomeViewController = [[[UVWelcomeViewController alloc] init] autorelease];
        welcomeViewController.navigationItem.leftBarButtonItem = self.navigationItem.leftBarButtonItem;
        self.navigationController.navigationBarHidden = NO;

        [((VNavigationController *)self.navigationController) setRootViewController:welcomeViewController];
        
        if (self.viewToLoad == @"welcome") {
            // do nothing
        } else if (self.viewToLoad == @"suggestions") {
            UIViewController *suggestionListViewController = [[[UVSuggestionListViewController alloc] initWithForum:[UVSession currentSession].clientConfig.forum] autorelease];
            
            [self.navigationController pushViewController:suggestionListViewController animated:NO];
        } else if (self.viewToLoad == @"new_ticket") {

            UIViewController *newTicketViewController = [[[UVNewTicketViewController alloc] init] autorelease];

            [self.navigationController pushViewController:newTicketViewController animated:NO];
        }
    }
}

// Initialization: request token -> client config -> user -> persist the access token -> user's suggestions -> next view
// If we don't have either a configured user, or a persisted token (which is therefore an access token) then we go straight from the client config to the next view
- (void)didRetrieveRequestToken:(UVToken *)token {
    // should be storing all tokens and checking on type
    [UVSession currentSession].currentToken = token;
    [UVClientConfig getWithDelegate:self];
}

- (void)didRetrieveClientConfig:(UVClientConfig *)clientConfig {
    // check if we have a sso token and if so exchange it for an access token and user
    if ([UVSession currentSession].config.ssoToken != nil) {
        [UVUser findOrCreateWithSsoToken:[UVSession currentSession].config.ssoToken delegate:self];
    } else if ([UVSession currentSession].config.email != nil) {
        [UVUser findOrCreateWithGUID:[UVSession currentSession].config.guid andEmail:[UVSession currentSession].config.email andName:[UVSession currentSession].config.displayName andDelegate:self];
    } else if ([UVToken exists]) {
        [UVUser retrieveCurrentUser:self];
    } else {
        [self pushNextView];
    }
}

- (void)didCreateUser:(UVUser *)theUser {
    [UVSession currentSession].user = theUser;
    [[UVSession currentSession].currentToken persist];
    [self pushNextView];
}

- (void)didRetrieveCurrentUser:(UVUser *)theUser {
    [UVSession currentSession].user = theUser;
    [[UVSession currentSession].currentToken persist];
    [UVSuggestion getWithForumAndUser:[UVSession currentSession].clientConfig.forum
                                 user:theUser delegate:self];
}

- (void) didRetrieveUserSuggestions:(NSArray *) theSuggestions {
    UVUser *user = [UVSession currentSession].user;
    [user didLoadSuggestions:theSuggestions];
    [self pushNextView];
}

#pragma mark ===== Basic View Methods =====

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
    [super loadView];
//    [self showExitButton];

    CGRect frame = [self contentFrame];
    UIView *contentView = [[UIView alloc] initWithFrame:frame];
    CGFloat screenWidth = [UVClientConfig getScreenWidth];
//    CGFloat screenHeight = [UVClientConfig getScreenHeight];

//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        contentView.backgroundColor = [UVStyleSheet backgroundColor];
//    else
//        contentView.backgroundColor = [UIColor groupTableViewBackgroundColor];

    UILabel *splashLabel2 = [[UILabel alloc] initWithFrame:CGRectMake(0, frame.size.height/2, screenWidth, 20)];
    splashLabel2.backgroundColor = [UIColor clearColor];
    splashLabel2.font = [UIFont systemFontOfSize:15];
    splashLabel2.textColor = [UIColor darkGrayColor];
    splashLabel2.textAlignment = UITextAlignmentCenter;
    splashLabel2.text = NSLocalizedStringFromTable(@"Connecting to UserVoice", @"UserVoice", nil);
    [contentView addSubview:splashLabel2];
    [splashLabel2 release];

//    UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
//    if ([activity respondsToSelector:@selector(setColor:)]) {
//        [activity setColor:[UIColor grayColor]];
//    } else {
//        [activity release];
//        activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
//    }
//    activity.center = CGPointMake(screenWidth/2, (screenHeight/ 2) - 60);
//    [contentView addSubview:activity];
//    [activity startAnimating];
//    [activity release];
    [VenioActivityView activityViewForView:contentView];

    self.view = contentView;
    [contentView release];
}

- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"View will appear (RootView)");

//    UIImage *navBarImage = [UIImage imageNamed:@"navBar.png"];
//    UINavigationBar *navBar = [self.navigationController navigationBar];
//    [navBar setBackgroundImage:navBarImage forBarMetrics:UIBarMetricsDefault];
//    
    
    if (![UVNetworkUtils hasInternetAccess]) {
        UIImageView *serverErrorImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"uv_error_connection.png"]];
        self.navigationController.navigationBarHidden = NO;
        serverErrorImage.frame = self.view.frame;
        serverErrorImage.contentMode = UIViewContentModeCenter;
        serverErrorImage.backgroundColor = [UIColor colorWithRed:0.78f green:0.80f blue:0.83f alpha:1.0f];
        serverErrorImage.clipsToBounds = YES;
        [self.view addSubview:serverErrorImage];
        [serverErrorImage release];
    } else if (![UVToken exists]) {
        NSLog(@"No access token");
        [UVToken getRequestTokenWithDelegate:self];
    } else if (![[UVSession currentSession] clientConfig]) {
        NSLog(@"No client config");
        [UVSession currentSession].currentToken = [[[UVToken alloc] initWithExisting] autorelease];

        // get config and current user
        [UVClientConfig getWithDelegate:self];
    } else if (![UVSession currentSession].user) {
        NSLog(@"No user");
        // just get user
        [UVSession currentSession].currentToken = [[[UVToken alloc] initWithExisting] autorelease];
        [UVUser retrieveCurrentUser:self];
    } else {
        NSLog(@"Already loaded");
        // We already have a client config, because the user already logged in before during
        // this session. Skip straight to the welcome view.
        [self pushNextView];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    // Re-enable the navigation bar
    self.navigationController.navigationBarHidden = NO;
}

- (void)dealloc {
    self.viewToLoad = nil;
    [super dealloc];
}

@end
