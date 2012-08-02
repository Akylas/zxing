//
//  EAN8Reader.mm
//  ZXingWidget
//
//  Created by Romain Pechayre on 6/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "EAN8Reader.h"
#import <zxing/oned/EAN8Reader.h>
#include <zxing/DecodeHints.h>

@implementation EAN8Reader

- (id) init {
  zxing::oned::EAN8Reader *reader = new zxing::oned::EAN8Reader();
  return [super initWithReader:reader];
}
@end
