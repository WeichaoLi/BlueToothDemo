//
//  ViewController.m
//  BlueToothDemo
//
//  Created by 李伟超 on 15/6/24.
//  Copyright (c) 2015年 linrunsoft. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

static NSString * const kServiceUUID = @"671E84AF-21D5-4B0C-8E2D-FB7758A4A9FB";
static NSString * const kCharacteristicUUID = @"54FBAB7A-BFDA-4873-9E0E-F1D13A7A7B27";

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>{
    CBCentralManager *_blueToothManager;
    CBPeripheralManager *_peripheralManager;
}

@property (nonatomic, retain) NSMutableArray            *peripherals;
@property (weak, nonatomic) IBOutlet UITextView *log;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _log.text = nil;
}

- (IBAction)scanThePeripheralDevice:(id)sender {
    if (!_blueToothManager) {
        dispatch_queue_t queue = dispatch_queue_create("coreBluetooth", DISPATCH_QUEUE_SERIAL);
        _blueToothManager = [[CBCentralManager alloc] initWithDelegate:self queue:queue];
    }
//    NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:
//                         [NSNumber numberWithBool:true], CBCentralManagerScanOptionAllowDuplicatesKey,
//                         @"myIdentifier" ,CBCentralManagerOptionRestoreIdentifierKey,nil];
//    [_blueToothManager scanForPeripheralsWithServices:nil options:dic];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - 属性
-(NSMutableArray *)peripherals{
    if(!_peripherals){
        _peripherals=[NSMutableArray array];
    }
    return _peripherals;
}

#pragma mark - 私有方法
/**
 *  记录日志
 *
 *  @param info 日志信息
 */
-(void)writeToLog:(NSString *)info{
    NSLog(@"%@",info);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.log.text=[NSString stringWithFormat:@"%@\r\n%@",self.log.text,info];
    });
    
}

#pragma mark -
#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBPeripheralManagerStatePoweredOn:
            [self writeToLog:@"BLE已打开."];
            //扫描外围设备
            //            [central scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kServiceUUID]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
            
            //    NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:
            //                         [NSNumber numberWithBool:true], CBCentralManagerScanOptionAllowDuplicatesKey,
            //                         @"myIdentifier" ,CBCentralManagerOptionRestoreIdentifierKey,nil];
            //    [_blueToothManager scanForPeripheralsWithServices:nil options:dic];
            
            [central scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
            break;
            
        default:
            [self writeToLog:@"此设备不支持BLE或未打开蓝牙功能，无法作为外围设备."];
            break;
    }
}

/**
 *  发现外围设备
 *
 *  @param central           中心设备
 *  @param peripheral        外围设备
 *  @param advertisementData 特征数据
 *  @param RSSI              信号质量（信号强度）
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    [self writeToLog:@"发现外围设备..."];
    //停止扫描
    [_blueToothManager stopScan];
    //连接外围设备
    if (peripheral) {
        //添加保存外围设备，注意如果这里不保存外围设备（或者说peripheral没有一个强引用，无法到达连接成功（或失败）的代理方法，因为在此方法调用完就会被销毁
        if(![self.peripherals containsObject:peripheral]){
            [self.peripherals addObject:peripheral];
        }
        [self writeToLog:@"开始连接外围设备..."];
        [_blueToothManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self writeToLog:@"连接外围设备成功!"];
    //设置外围设备的代理为当前视图控制器
    peripheral.delegate=self;
    //外围设备开始寻找服务
    [peripheral discoverServices:@[[CBUUID UUIDWithString:kServiceUUID]]];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self writeToLog:@"连接外围设备失败!"];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self writeToLog:@"断开链接"];
}

#pragma mark - CBPeripheralDelegate

//外围设备寻找到服务后
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    [self writeToLog:@"已发现可用服务..."];
    if(error){
        [self writeToLog:[NSString stringWithFormat:@"外围设备寻找服务过程中发生错误，错误信息：%@",error.localizedDescription]];
    }
    //遍历查找到的服务
    CBUUID *serviceUUID=[CBUUID UUIDWithString:kServiceUUID];
    CBUUID *characteristicUUID=[CBUUID UUIDWithString:kCharacteristicUUID];
    for (CBService *service in peripheral.services) {
        if([service.UUID isEqual:serviceUUID]){
            //外围设备查找指定服务中的特征
            [peripheral discoverCharacteristics:@[characteristicUUID] forService:service];
        }
    }
}

//更新特征值后（调用readValueForCharacteristic:方法或者外围设备在订阅后更新特征值都会调用此代理方法）
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        [self writeToLog:[NSString stringWithFormat:@"更新特征值时发生错误，错误信息：%@",error.localizedDescription]];
        return;
    }
    if (characteristic.value) {
        NSString *value=[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        [self writeToLog:[NSString stringWithFormat:@"读取到特征值：%@",value]];
    }else{
        [self writeToLog:@"未发现特征值."];
    }
}

@end
