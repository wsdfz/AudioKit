//
//  AKLowPassFilter.h
//  AudioKit
//
//  Auto-generated on 12/25/14.
//  Copyright (c) 2014 Aurelius Prochazka. All rights reserved.
//

#import "AKAudio.h"
#import "AKParameter+Operation.h"

/** A first-order recursive low-pass filter with variable frequency response.

 More detailed description from http://www.csounds.com/manual/html/tone.html
 */

@interface AKLowPassFilter : AKAudio
/// Instantiates the low pass filter with all values
/// @param audioSource The control to be filtered [Default Value: ]
/// @param halfPowerPoint The response curve's half-power point, in Hertz. Half power is defined as peak power / root 2. Updated at Control-rate. [Default Value: 1000]
- (instancetype)initWithAudioSource:(AKParameter *)audioSource
                     halfPowerPoint:(AKParameter *)halfPowerPoint;

/// Instantiates the low pass filter with default values
/// @param audioSource The control to be filtered
- (instancetype)initWithAudioSource:(AKParameter *)audioSource;

/// Instantiates the low pass filter with default values
/// @param audioSource The control to be filtered
+ (instancetype)audioWithAudioSource:(AKParameter *)audioSource;

/// The response curve's half-power point, in Hertz. Half power is defined as peak power / root 2. [Default Value: 1000]
@property AKParameter *halfPowerPoint;

/// Set an optional half power point
/// @param halfPowerPoint The response curve's half-power point, in Hertz. Half power is defined as peak power / root 2. Updated at Control-rate. [Default Value: 1000]
- (void)setOptionalHalfPowerPoint:(AKParameter *)halfPowerPoint;



@end
