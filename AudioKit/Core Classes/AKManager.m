//
//  AKManager.m
//  AudioKit
//
//  Created by Aurelius Prochazka on 5/30/12.
//  Copyright (c) 2012 Aurelius Prochazka. All rights reserved.
//

#import "AKManager.h"
#import "CsoundObj.h"

@interface AKManager () <CsoundObjListener> {
    NSString *options;
    NSString *csdFile;
    NSString *templateString;
    
    CsoundObj *csound;
    int totalRunDuration;
}

// Run Csound from a given filename
// @param filename CSD file use when running Csound.
- (void)runCSDFile:(NSString *)filename;

@end

@implementation AKManager

// -----------------------------------------------------------------------------
#  pragma mark - Singleton Setup
// -----------------------------------------------------------------------------

static AKManager *_sharedManager = nil;

+ (AKManager *)sharedManager
{
    @synchronized([AKManager class]) 
    {
        if(!_sharedManager) _sharedManager = [[self alloc] init];
        NSString *name = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
        if (name) {
            // This is an app that will contain the framework
            NSString *rawWavesDir = [NSString stringWithFormat:@"%@.app/Contents/Frameworks/CsoundLib64.framework/Resources/RawWaves", name];
            NSString *opcodeDir = [NSString stringWithFormat:@"%@.app/Contents/Frameworks/CsoundLib64.framework/Resources/Opcodes64", name];
            csoundSetGlobalEnv("OPCODE6DIR64", [opcodeDir cStringUsingEncoding:NSUTF8StringEncoding]);
            csoundSetGlobalEnv("RAWWAVE_PATH", [rawWavesDir cStringUsingEncoding:NSUTF8StringEncoding]);
        } else {
            // This is a command-line program that sits beside the framework
            csoundSetGlobalEnv("RAWWAVE_PATH", "CsoundLib64.framework/Resources/RawWaves");
            csoundSetGlobalEnv("OPCODE6DIR64", "CsoundLib64.framework/Resources/Opcodes64");
        }
        return _sharedManager;
    }
    return nil;
}

- (AKWeightedSumOfSinusoids *)standardSineWave {
    _numberOfSineWaveReferences++;
    return _standardSineWave;
}

+ (AKWeightedSumOfSinusoids *)standardSineWave {
    return [[AKManager sharedManager] standardSineWave];
}

+ (id)alloc {
    @synchronized([AKManager class]) {
        NSAssert(_sharedManager == nil, @"Attempted to allocate a 2nd AKManager");
        _sharedManager = [super alloc];
        return _sharedManager;
    }
    return nil;
}

+ (NSString *)stringFromFile:(NSString *)filename {
    return [[NSString alloc] initWithContentsOfFile:filename 
                                           encoding:NSUTF8StringEncoding 
                                              error:nil];
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        csound = [[CsoundObj alloc] init];
        [csound addListener:self];
        [csound setMessageCallback:@selector(messageCallback:) withListener:self];
        
        _isRunning = NO;
        _isLogging = NO;
        
        totalRunDuration = 10000000;
        _numberOfSineWaveReferences = 0;
        _standardSineWave = [AKWeightedSumOfSinusoids pureSineWave];
        
        _orchestra = [[AKOrchestra alloc] init];
        
//        "-+rtmidi=null    ; Disable the use of any realtime midi plugin\n"
//        "-+rtaudio=null   ; Disable the use of any realtime audio plugin\n"
//        "-+msg_color=0    ; Disable message attributes\n"
        options = @"-o dac           ; Write sound to the host audio output\n"
                   "--expression-opt ; Enable expression optimizations\n"
                   "-m0              ; Print raw amplitudes\n"
                   "-i adc           ; Request sound from the host audio input device";
        
        templateString = @""
        "<CsoundSynthesizer>\n\n"
        "<CsOptions>\n\%@\n</CsOptions>\n\n"
        "<CsInstruments>\n\n"
        "opcode AKControl, k, a\n"
        "aval xin\n"
        "xout downsamp(aval)\n"
        "endop\n"
        "\n"
        "opcode AKControl, k, k\n"
        "kval xin\n"
        "koutput = kval\n"
        "xout koutput\n"
        "endop\n"
        "\n"
        "opcode AKAudio, a, k\n"
        "kval xin\n"
        "xout upsamp(kval)\n"
        "endop\n"
        "\n"
        "opcode AKAudio, a, a\n"
        "aval xin\n"
        "aoutput = aval\n"
        "xout aoutput\n"
        "endop\n"
        "\n"
        "\%@\n\n"
        "; Deactivates a complete instrument\n"
        "instr DeactivateInstrument\n"
        "turnoff2 p4, 0, 1\n"
        "endin\n\n"
        "; Event End or Note Off\n"
        "instr DeactivateNote\n"
        "turnoff2 p4, 4, 1\n"
        "endin\n\n"
        "</CsInstruments>\n\n"
        "<CsScore>\nf0 %d\n</CsScore>\n\n"
        "</CsoundSynthesizer>\n";
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = paths[0];
        csdFile = [NSString stringWithFormat:@"%@/.new.csd", documentsDirectory];
        _midi = [[AKMidi alloc] init];
    }
    return self;
}   

// -----------------------------------------------------------------------------
#  pragma mark - Handling CSD Files
// -----------------------------------------------------------------------------

- (void)runCSDFile:(NSString *)filename 
{
    if(_isRunning) {
        if (_isLogging) NSLog(@"Csound instance already active.");
        [self stop];
    }
    NSString *file = [[NSBundle mainBundle] pathForResource:filename
                                                     ofType:@"csd"];  
    [csound play:file];
    if (_isLogging) NSLog(@"Starting %@ \n\n%@\n",filename, [AKManager stringFromFile:file]);
    while(!_isRunning) {
        if (_isLogging) NSLog(@"Waiting for Csound to startup completely.");
    }
    if (_isLogging) NSLog(@"Started.");
}

- (void)writeCSDFileForOrchestra:(AKOrchestra *)orchestra 
{
    NSString *newCSD = [NSString stringWithFormat:templateString, options, [orchestra stringForCSD], totalRunDuration];

    [newCSD writeToFile:csdFile 
             atomically:YES  
               encoding:NSStringEncodingConversionAllowLossy 
                  error:nil];
}

- (void)runOrchestra
{
    if(_isRunning) {
        if (_isLogging) NSLog(@"Csound instance already active.");
        [self stop];
    }
    [self writeCSDFileForOrchestra:_orchestra];
    [self updateBindingsWithProperties:_orchestra];
    
    [csound play:csdFile];
    if (_isLogging) NSLog(@"Starting \n\n%@\n", [AKManager stringFromFile:csdFile]);
    
    // Clean up the IDs for next time
    //[AKParameter resetID]; //Should work but generating lots of out of bounds errors
    [AKInstrument resetID];
    [AKNote resetID];
    
    // Pause to allow Csound to start, warn if nothing happens after 1 second
    int cycles = 0;
    while(!_isRunning) {
        cycles++;
        if (cycles > 100) {
            if (_isLogging) NSLog(@"Csound has not started in 1 second." );
            break;
        }
        [NSThread sleepForTimeInterval:0.01];
    }
}

- (void)runOrchestraForDuration:(int)duration
{
    totalRunDuration = duration;
    [self runOrchestra];
}

// -----------------------------------------------------------------------------
#  pragma mark Audio Input from Hardware
// -----------------------------------------------------------------------------

/// Enable Audio Input
- (void)enableAudioInput {
    [csound setUseAudioInput:YES];
}

/// Disable AudioInput
- (void)disableAudioInput {
    [csound setUseAudioInput:NO];    
}

// -----------------------------------------------------------------------------
#  pragma mark Recording Interface
// -----------------------------------------------------------------------------

- (void)stopRecording {
    [csound stopRecording];
}

- (void)startRecordingToURL:(NSURL *)url {
    [csound recordToURL:url];
}

// -----------------------------------------------------------------------------
#  pragma mark AKMidi
// -----------------------------------------------------------------------------

- (void)enableMidi
{
    [_midi openMidiIn];
}

- (void)disableMidi
{
    [_midi closeMidiIn];
}

// -----------------------------------------------------------------------------
#  pragma mark - Csound control
// -----------------------------------------------------------------------------

- (void)stop 
{
    if (_isLogging) NSLog(@"Stopping Csound");
    [csound stop];
    while(_isRunning) {} // Do nothing
}

- (void)triggerEvent:(AKEvent *)event
{
    [event runBlock];
}

- (void)stopInstrument:(AKInstrument *)instrument
{
    if (_isLogging) NSLog(@"Stopping Instrument with '%@'", [instrument stopStringForCSD]);
    [csound sendScore:[instrument stopStringForCSD]];
}

- (void)stopNote:(AKNote *)note
{
    if (_isLogging) NSLog(@"Stopping Note with %@", [note stopStringForCSD]);
    [csound sendScore:[note stopStringForCSD]];
}

- (void)updateNote:(AKNote *)note
{
    if (_isLogging) NSLog(@"updating Note with %@", [note stringForCSD]);
    [csound sendScore:[note stringForCSD]];
}

- (void)updateBindingsWithProperties:(AKOrchestra *)orchestra
{
    NSArray *arr = [NSArray arrayWithArray:[orchestra instruments]];
    for (AKInstrument *instrument in arr ) {
        for (AKInstrumentProperty *c in [instrument properties]) {
            [csound addBinding:(AKInstrumentProperty<CsoundBinding> *)c];
        }
    }
}

// -----------------------------------------------------------------------------
#  pragma mark - Csound Callbacks
// -----------------------------------------------------------------------------

- (void)messageCallback:(NSValue *)infoObj
{
	Message info;
	[infoObj getValue:&info];
	char message[1024];
	vsnprintf(message, 1024, info.format, info.valist);
	if (_isLogging) NSLog(@"%s", message);
}

- (void)csoundObjStarted:(CsoundObj *)csoundObj {
    if (_isLogging) NSLog(@"Csound Started.");
    _isRunning = YES;
}

- (void)csoundObjCompleted:(CsoundObj *)csoundObj {
    if (_isLogging) NSLog(@"Csound Completed.");
    _isRunning  = NO;
}

@end
