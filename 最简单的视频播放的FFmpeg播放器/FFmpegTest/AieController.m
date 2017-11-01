//
//  AieController.m
//  SFFmpegIOSDecoder
//
//  Created by fenglixin on 2017/6/14.
//  Copyright © 2017年 Lei Xiaohua. All rights reserved.
//

#import "AieController.h"
#import "Aie1Controller.h"


@interface AieController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView * aTableView;
@property (nonatomic, strong) NSArray * titleArray;

@end

@implementation AieController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _titleArray = @[@"最简单的视频播放"];
    
    _aTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - 64) style:UITableViewStylePlain];
    _aTableView.dataSource = self;
    _aTableView.delegate = self;
    [self.view addSubview:_aTableView];
}

#pragma mark - UITableViewDelegate, UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _titleArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:@"Cell"];
    }
    cell.detailTextLabel.text = _titleArray[indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0)
    {
        Aie1Controller * ctl = [[Aie1Controller alloc] init];
        [self.navigationController pushViewController:ctl animated:YES];
    }
   

}

@end
