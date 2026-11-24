/*
 * Copyright @ 2021-present Meet Hour, LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "include/MHBroadcastSampleHandler.h"
#import "MHBroadcastSocketConnection.h"
#import "MHBroadcastSampleUploader.h"
#import "MHBroadcastDarwinNotificationCenter.h"

#include <fcntl.h>
#include <math.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

// MARK: - Device audio ("Share your device's audio")
//
// ReplayKit also hands the extension the sound other apps are playing. When the
// user ticked "Share your device's audio", it is converted to 48 kHz mono 16-bit
// and written into a small ring buffer in a file in the app group container;
// the Meet Hour SDK in the app mixes it into the microphone audio it sends.
//
// The layout below MUST match ios/sdk/src/ScreenShareAudio.mm (the app side).

static const uint32_t kMHRingMagic = 0x4D485341; // "MHSA"
static const uint32_t kMHRingVersion = 1;
static const uint32_t kMHRingSampleRate = 48000; // 16-bit mono
static const uint32_t kMHRingCapacity = 48000;   // frames, i.e. 1 second

typedef struct {
  uint32_t magic;
  uint32_t version;
  uint32_t sampleRate;
  uint32_t capacity;
  uint32_t enabled;   // Written by the app: the user ticked "Share your device's audio".
  uint32_t reserved;
  uint64_t writePos;  // Written here: total frames written so far.
  int16_t samples[];
} MHScreenAudioRing;

static MHScreenAudioRing *MHOpenScreenAudioRing(NSURL *sharedContainer) {
  if (!sharedContainer) {
    return NULL;
  }

  const char *path = [[sharedContainer URLByAppendingPathComponent:@"mh_screen_audio"] fileSystemRepresentation];
  const size_t size = sizeof(MHScreenAudioRing) + kMHRingCapacity * sizeof(int16_t);
  int fd = open(path, O_RDWR | O_CREAT, 0644);
  if (fd < 0) {
    return NULL;
  }

  struct stat st;
  if (fstat(fd, &st) != 0 || ((size_t)st.st_size < size && ftruncate(fd, (off_t)size) != 0)) {
    close(fd);
    return NULL;
  }

  void *mapped = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  close(fd);
  if (mapped == MAP_FAILED) {
    return NULL;
  }

  MHScreenAudioRing *ring = (MHScreenAudioRing *)mapped;
  if (__atomic_load_n(&ring->magic, __ATOMIC_ACQUIRE) != kMHRingMagic
      || ring->version != kMHRingVersion
      || ring->capacity != kMHRingCapacity) {
    ring->version = kMHRingVersion;
    ring->sampleRate = kMHRingSampleRate;
    ring->capacity = kMHRingCapacity;
    ring->enabled = 0;
    __atomic_store_n(&ring->writePos, (uint64_t)0, __ATOMIC_RELEASE);
    __atomic_store_n(&ring->magic, kMHRingMagic, __ATOMIC_RELEASE);
  }

  return ring;
}

/** Reads one sample as a float in [-1, 1], whatever PCM layout ReplayKit used. */
static float MHReadSample(const AudioBufferList *list, const AudioStreamBasicDescription *format,
                          CMItemCount frame, UInt32 channel) {
  const BOOL nonInterleaved = (format->mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
  const UInt32 channels = MAX(format->mChannelsPerFrame, 1);
  const UInt32 bytes = format->mBitsPerChannel / 8;
  const AudioBuffer *buffer = &list->mBuffers[nonInterleaved ? MIN(channel, list->mNumberBuffers - 1) : 0];
  const size_t index = nonInterleaved ? (size_t)frame : (size_t)frame * channels + channel;

  if (!buffer->mData || (index + 1) * bytes > buffer->mDataByteSize) {
    return 0;
  }

  const BOOL bigEndian = (format->mFormatFlags & kAudioFormatFlagIsBigEndian) != 0;

  if (format->mFormatFlags & kAudioFormatFlagIsFloat) {
    uint32_t raw = ((const uint32_t *)buffer->mData)[index];
    if (bigEndian) {
      raw = CFSwapInt32(raw);
    }
    float value;
    memcpy(&value, &raw, sizeof(value));
    return value;
  }

  if (bytes == 2) {
    uint16_t raw = ((const uint16_t *)buffer->mData)[index];
    if (bigEndian) {
      raw = CFSwapInt16(raw);
    }
    return (int16_t)raw / 32768.0f;
  }

  uint32_t raw = ((const uint32_t *)buffer->mData)[index];
  if (bigEndian) {
    raw = CFSwapInt32(raw);
  }
  return (int32_t)raw / 2147483648.0f;
}


@interface MHBroadcastSampleHandler ()

@property (nonatomic, retain) MHBroadcastSocketConnection *clientConnection;
@property (nonatomic, retain) MHBroadcastSampleUploader *uploader;

@end

@implementation MHBroadcastSampleHandler {
  // Device audio ("Share your device's audio"); used on ReplayKit's audio queue only.
  MHScreenAudioRing *_audioRing;
  BOOL _hasPreviousAudioSample;
  float _previousAudioSample;
  double _audioPhase;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.clientConnection = [[MHBroadcastSocketConnection alloc] initWithFilePath:self.socketFilePath];
    [self setupConnection];
    
    self.uploader = [[MHBroadcastSampleUploader alloc] initWithConnection:self.clientConnection];    
  }
  
  return self;
}

- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo {
  // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
  NSLog(@"broadcast started");
  
  [[MHBroadcastDarwinNotificationCenter sharedInstance] postNotificationWithName:kMHBroadcastStartedNotification];
  [self openConnection];
}

- (void)broadcastPaused {
    // User has requested to pause the broadcast. Samples will stop being delivered.
}

- (void)broadcastResumed {
    // User has requested to resume the broadcast. Samples delivery will resume.
}

- (void)broadcastFinished {
    // User has requested to finish the broadcast.
  [[MHBroadcastDarwinNotificationCenter sharedInstance] postNotificationWithName:kMHBroadcastStoppedNotification];
  [self.clientConnection close];
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {
  static NSUInteger frameCount = 0;
  switch (sampleBufferType) {
    case RPSampleBufferTypeVideo:
      // adjust frame rate by using every third frame
      if (++frameCount%3 == 0 && self.uploader.isReady) {
        [self.uploader sendSample:sampleBuffer];
      }
      break;

    case RPSampleBufferTypeAudioApp:
      [self writeAppAudio:sampleBuffer];
      break;

    default:
      break;
  }
}

// MARK: Private Methods

/**
 * The app group shared with the app, from this extension's Info.plist. It must
 * be the same RTCAppGroupIdentifier as in the app's Info.plist.
 */
- (NSURL *)sharedContainer {
  NSString *appGroupIdentifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"RTCAppGroupIdentifier"];

  if (appGroupIdentifier.length == 0) {
    NSLog(@"MHBroadcastSampleHandler: RTCAppGroupIdentifier is missing from the broadcast extension's Info.plist");
    return nil;
  }

  return [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:appGroupIdentifier];
}

- (void)writeAppAudio:(CMSampleBufferRef)sampleBuffer {
  if (!_audioRing) {
    _audioRing = MHOpenScreenAudioRing([self sharedContainer]);
    if (!_audioRing) {
      return;
    }
  }

  if (!__atomic_load_n(&_audioRing->enabled, __ATOMIC_ACQUIRE)) {
    _hasPreviousAudioSample = NO;
    return;
  }

  CMFormatDescriptionRef description = CMSampleBufferGetFormatDescription(sampleBuffer);
  const AudioStreamBasicDescription *format = description ? CMAudioFormatDescriptionGetStreamBasicDescription(description) : NULL;
  const CMItemCount frames = CMSampleBufferGetNumSamples(sampleBuffer);

  if (!format || format->mFormatID != kAudioFormatLinearPCM || format->mSampleRate <= 0 || frames <= 0) {
    return;
  }

  const BOOL isFloat = (format->mFormatFlags & kAudioFormatFlagIsFloat) != 0;
  if (!((isFloat && format->mBitsPerChannel == 32) || (!isFloat && (format->mBitsPerChannel == 16 || format->mBitsPerChannel == 32)))) {
    return;
  }

  size_t listSize = 0;
  CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, &listSize, NULL, 0, NULL, NULL,
                                                         kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, NULL);
  if (listSize == 0) {
    return;
  }

  AudioBufferList *list = malloc(listSize);
  float *mono = malloc((size_t)frames * sizeof(float));
  CMBlockBufferRef blockBuffer = NULL;

  if (list && mono
      && CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, list, listSize, NULL, NULL,
                                                                 kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                 &blockBuffer) == noErr) {
    const UInt32 channels = MAX(format->mChannelsPerFrame, 1);

    // Down-mix to mono.
    for (CMItemCount frame = 0; frame < frames; frame++) {
      float sum = 0;
      for (UInt32 channel = 0; channel < channels; channel++) {
        sum += MHReadSample(list, format, frame, channel);
      }
      mono[frame] = sum / channels;
    }

    // Resample (linearly) to 48 kHz. Position -1 is the last sample of the
    // previous buffer, so there is no click between buffers.
    if (!_hasPreviousAudioSample) {
      _previousAudioSample = mono[0];
      _audioPhase = 0;
      _hasPreviousAudioSample = YES;
    }

    MHScreenAudioRing *ring = _audioRing;
    const double step = format->mSampleRate / kMHRingSampleRate;
    const uint64_t writePos = __atomic_load_n(&ring->writePos, __ATOMIC_RELAXED);
    uint64_t written = 0;
    double position = _audioPhase;

    while (position < (double)(frames - 1) && written < kMHRingCapacity) {
      const CMItemCount index = (CMItemCount)floor(position);
      const float a = index < 0 ? _previousAudioSample : mono[index];
      const float b = mono[index + 1];
      float value = a + (b - a) * (float)(position - (double)index);

      value = MAX(-1.0f, MIN(1.0f, value));
      ring->samples[(writePos + written) % kMHRingCapacity] = (int16_t)lrintf(value * 32767.0f);
      written++;
      position += step;
    }

    _audioPhase = position - (double)frames;
    _previousAudioSample = mono[frames - 1];
    __atomic_store_n(&ring->writePos, writePos + written, __ATOMIC_RELEASE);
  }

  if (blockBuffer) {
    CFRelease(blockBuffer);
  }
  free(mono);
  free(list);
}

- (NSString *)socketFilePath {
    NSURL *sharedContainer = [self sharedContainer];
    NSString *socketFilePath = [[sharedContainer URLByAppendingPathComponent:@"rtc_SSFD"] path];

    return socketFilePath ?: @"";
}

- (void)setupConnection {
  __weak __typeof(self) weakSelf = self;
  self.clientConnection.didClose = ^(NSError *error) {
    NSLog(@"client connection did close: %@", error);
    if (error) {
      [weakSelf finishBroadcastWithError:error];
    }
    else {
      NSInteger JMScreenSharingStopped = 10001;
      NSError *customError = [NSError errorWithDomain:RPRecordingErrorDomain
                                                 code:JMScreenSharingStopped
                                             userInfo:@{NSLocalizedDescriptionKey: @"Screen sharing stopped"}];
      [weakSelf finishBroadcastWithError:customError];
    }
  };
}

- (void)openConnection {
  dispatch_queue_t queue = dispatch_queue_create("go.meethour.io.broadcast.connectTimer", 0);
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
  dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), 0.1 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
  
  dispatch_source_set_event_handler(timer, ^{
    BOOL success = [self.clientConnection open];
    if (success) {
      dispatch_source_cancel(timer);
    }
  });

  dispatch_resume(timer);
}

@end
