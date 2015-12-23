//
//  EAN13Reader.mm
//  ZXingWidget

#import "EAN13Reader.h"
#import <zxing/oned/EAN13Reader.h>
#include <zxing/DecodeHints.h>

@implementation EAN13Reader

- (id) init {
  zxing::oned::EAN13Reader *reader = new zxing::oned::EAN13Reader();
  return [super initWithReader:reader];
}
@end
