//
//  PixelUtil.h
//  LZ4Decompression
//
//  Created by Mo DeJong on 6/29/18.
//  Copyright © 2018 HelpURock. All rights reserved.
//

#ifndef PixelUtil_h
#define PixelUtil_h

// 0 = 0, -1 = 1, 1 = 2, -2 = 3, 2 = 4, -3 = 5, 3 = 6

static inline
uint32_t
pixelpack_num_neg_to_offset(int32_t value) {
  if (value == 0) {
    return value;
  } else if (value < 0) {
    return (value * -2) - 1;
  } else {
    return value * 2;
  }
}

static inline
int32_t
pixelpack_offset_to_num_neg(uint32_t value) {
  if (value == 0) {
    return value;
  } else if ((value & 0x1) != 0) {
    // odd numbers are negative values
    return ((int)value + 1) / -2;
  } else {
    return value / 2;
  }
}

static inline
int8_t
pixelpack_offset_uint8_to_int8(uint8_t value)
{
  int offset = (int) value;
  int iVal = pixelpack_offset_to_num_neg(offset);
  assert(iVal >= -128);
  assert(iVal <= 127);
  int8_t sVal = (int8_t) iVal;
  return sVal;
}

static inline
uint8_t
pixelpack_int8_to_offset_uint8(int8_t value)
{
  int iVal = (int) value;
  int offset = pixelpack_num_neg_to_offset(iVal);
  assert(offset >= 0);
  assert(offset <= 255);
  uint8_t offset8 = offset;
#if defined(DEBUG)
  {
    // Validate reverse operation, it must regenerate value
    int8_t decoded = pixelpack_offset_uint8_to_int8(offset8);
    assert(decoded == value);
  }
#endif // DEBUG
  return offset8;
}

#endif /* PixelUtil_h */
