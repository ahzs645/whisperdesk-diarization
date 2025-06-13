# WhisperDesk Integration Guide

This guide shows how to integrate `whisperdesk-diarization` into your WhisperDesk application.

## 🔧 Setup as Submodule

### 1. Add Diarization as Submodule

```bash
# In your WhisperDesk root directory
git submodule add https://github.com/whisperdesk/whisperdesk-diarization.git deps/diarization
git submodule update --init --recursive
```

### 2. Update WhisperDesk package.json

```json
{
  "scripts": {
    "build:diarization": "cd deps/diarization && npm run build && cp binaries/* ../../binaries/",
    "setup:diarization": "cd deps/diarization && npm install && npm run build",
    "postinstall": "npm run setup:diarization"
  },
  "devDependencies": {
    "whisperdesk-diarization": "file:deps/diarization"
  }
}
```

### 3. Update .gitignore

```gitignore
# Diarization binaries (will be built)
binaries/diarize-cli*
binaries/libonnxruntime*
binaries/*.dll
binaries/*.dylib
binaries/*.so

# ONNX models (large files, download as needed)
models/segmentation-3.0.onnx
models/embedding-1.0.onnx
```

## 🔗 Integration Code

### 1. Diarization Service (Main Process)

```javascript
// src/main/services/diarization-service.js
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs').promises;

class DiarizationService {
  constructor() {
    this.binaryPath = this.findDiarizationBinary();
    this.modelsPath = path.join(__dirname, '..', '..', '..', 'models');
  }

  findDiarizationBinary() {
    const binariesDir = path.join(__dirname, '..', '..', '..', 'binaries');
    const binaryName = process.platform === 'win32' ? 'diarize-cli.exe' : 'diarize-cli';
    return path.join(binariesDir, binaryName);
  }

  async isDiarizationAvailable() {
    try {
      // Check if binary exists
      await fs.access(this.binaryPath, fs.constants.F_OK | fs.constants.X_OK);
      
      // Check if models exist
      const segmentModel = path.join(this.modelsPath, 'segmentation-3.0.onnx');
      const embeddingModel = path.join(this.modelsPath, 'embedding-1.0.onnx');
      
      await fs.access(segmentModel);
      await fs.access(embeddingModel);
      
      return true;
    } catch (error) {
      console.warn('🎭 Diarization not available:', error.message);
      return false;
    }
  }

  async performDiarization(audioPath, options = {}) {
    const {
      threshold = 0.01,
      maxSpeakers = 10,
      outputPath = null,
      onProgress = null
    } = options;

    if (!(await this.isDiarizationAvailable())) {
      throw new Error('Diarization system not available. Please run: npm run build:diarization');
    }

    const args = [
      '--audio', audioPath,
      '--segment-model', path.join(this.modelsPath, 'segmentation-3.0.onnx'),
      '--embedding-model', path.join(this.modelsPath, 'embedding-1.0.onnx'),
      '--threshold', threshold.toString(),
      '--max-speakers', maxSpeakers.toString(),
      '--verbose'
    ];

    if (outputPath) {
      args.push('--output', outputPath);
    }

    return new Promise((resolve, reject) => {
      const process = spawn(this.binaryPath, args, {
        env: {
          ...process.env,
          // Set library paths for runtime
          ...(process.platform === 'darwin' && {
            DYLD_LIBRARY_PATH: path.dirname(this.binaryPath),
            DYLD_FALLBACK_LIBRARY_PATH: path.dirname(this.binaryPath)
          }),
          ...(process.platform === 'linux' && {
            LD_LIBRARY_PATH: path.dirname(this.binaryPath)
          })
        }
      });

      let output = '';
      let error = '';

      process.stdout.on('data', (data) => {
        const text = data.toString();
        output += text;
        
        // Parse progress from verbose output
        if (onProgress && text.includes('progress:')) {
          const match = text.match(/progress:\s*(\d+\.?\d*)%/);
          if (match) {
            onProgress(parseFloat(match[1]));
          }
        }
      });

      process.stderr.on('data', (data) => {
        error += data.toString();
      });

      process.on('close', (code) => {
        if (code === 0) {
          try {
            const result = JSON.parse(output);
            resolve(result);
          } catch (parseError) {
            reject(new Error(`Failed to parse diarization output: ${parseError.message}`));
          }
        } else {
          reject(new Error(`Diarization failed (exit code ${code}): ${error}`));
        }
      });

      process.on('error', (err) => {
        reject(new Error(`Failed to start diarization process: ${err.message}`));
      });
    });
  }

  async getDiarizationStatus() {
    const available = await this.isDiarizationAvailable();
    
    return {
      available,
      binaryPath: this.binaryPath,
      modelsPath: this.modelsPath,
      platform: process.platform,
      arch: process.arch
    };
  }
}

module.exports = { DiarizationService };
```

### 2. Enhanced Transcription with Diarization

```javascript
// src/main/services/enhanced-transcription-service.js
const { TranscriptionService } = require('./transcription-service');
const { DiarizationService } = require('./diarization-service');
const path = require('path');

class EnhancedTranscriptionService extends TranscriptionService {
  constructor() {
    super();
    this.diarizationService = new DiarizationService();
  }

  async transcribeWithDiarization(audioPath, options = {}) {
    const {
      enableDiarization = false,
      speakerThreshold = 0.01,
      maxSpeakers = 10,
      ...transcriptionOptions
    } = options;

    // Step 1: Regular transcription
    console.log('🎵 Starting transcription...');
    const transcriptionResult = await this.transcribe(audioPath, transcriptionOptions);

    if (!enableDiarization) {
      return {
        ...transcriptionResult,
        diarization: null,
        speakers: []
      };
    }

    // Step 2: Speaker diarization
    console.log('🎭 Starting speaker diarization...');
    
    try {
      const diarizationResult = await this.diarizationService.performDiarization(audioPath, {
        threshold: speakerThreshold,
        maxSpeakers: maxSpeakers,
        onProgress: (progress) => {
          // You can emit this to the renderer process
          console.log(`🔄 Diarization progress: ${progress}%`);
        }
      });

      // Step 3: Merge transcription with speaker information
      const enhancedResult = this.mergeTranscriptionWithDiarization(
        transcriptionResult,
        diarizationResult
      );

      return enhancedResult;

    } catch (diarizationError) {
      console.warn('⚠️ Diarization failed, returning transcription only:', diarizationError.message);
      
      return {
        ...transcriptionResult,
        diarization: null,
        speakers: [],
        diarizationError: diarizationError.message
      };
    }
  }

  mergeTranscriptionWithDiarization(transcription, diarization) {
    const { segments: diarizationSegments, speakers: speakerStats } = diarization;
    
    // Simple time-based matching
    const enhancedSegments = transcription.segments.map(transcriptSegment => {
      const matchingDiarizationSegment = diarizationSegments.find(diarizationSegment => {
        const transcriptStart = transcriptSegment.start;
        const transcriptEnd = transcriptSegment.end;
        const diarizationStart = diarizationSegment.start_time;
        const diarizationEnd = diarizationSegment.end_time;
        
        // Check for overlap
        return (transcriptStart < diarizationEnd && transcriptEnd > diarizationStart);
      });

      return {
        ...transcriptSegment,
        speaker_id: matchingDiarizationSegment ? matchingDiarizationSegment.speaker_id : 0,
        speaker_confidence: matchingDiarizationSegment ? matchingDiarizationSegment.confidence : 0.5
      };
    });

    return {
      ...transcription,
      segments: enhancedSegments,
      diarization: diarization,
      speakers: speakerStats || [],
      enhanced: true
    };
  }
}

module.exports = { EnhancedTranscriptionService };
```

### 3. Renderer Integration

```javascript
// src/renderer/components/DiarizationSettings.vue
<template>
  <div class="diarization-settings">
    <div class="setting-group">
      <label class="toggle-label">
        <input 
          type="checkbox" 
          v-model="enableDiarization"
          :disabled="!diarizationAvailable"
        />
        <span class="toggle-text">
          🎭 Multi-Speaker Detection
          <span v-if="!diarizationAvailable" class="status-badge unavailable">
            Unavailable
          </span>
          <span v-else class="status-badge available">
            Available
          </span>
        </span>
      </label>
    </div>

    <div v-if="enableDiarization && diarizationAvailable" class="advanced-settings">
      <div class="setting-group">
        <label>Speaker Sensitivity</label>
        <select v-model="speakerThreshold">
          <option value="0.001">High (3+ speakers)</option>
          <option value="0.01">Balanced (2-3 speakers)</option>
          <option value="0.05">Conservative (1-2 speakers)</option>
        </select>
      </div>

      <div class="setting-group">
        <label>Maximum Speakers</label>
        <input 
          type="number" 
          v-model="maxSpeakers" 
          min="2" 
          max="20" 
          step="1"
        />
      </div>
    </div>

    <div v-if="!diarizationAvailable" class="setup-instructions">
      <p>🔧 To enable multi-speaker detection:</p>
      <ol>
        <li>Run: <code>npm run build:diarization</code></li>
        <li>Restart WhisperDesk</li>
      </ol>
    </div>
  </div>
</template>

<script>
export default {
  name: 'DiarizationSettings',
  data() {
    return {
      enableDiarization: false,
      diarizationAvailable: false,
      speakerThreshold: 0.01,
      maxSpeakers: 10
    };
  },
  async mounted() {
    this.diarizationAvailable = await window.electronAPI.checkDiarizationAvailable();
  },
  computed: {
    diarizationOptions() {
      return {
        enableDiarization: this.enableDiarization,
        speakerThreshold: parseFloat(this.speakerThreshold),
        maxSpeakers: parseInt(this.maxSpeakers)
      };
    }
  },
  watch: {
    diarizationOptions: {
      handler(newOptions) {
        this.$emit('options-changed', newOptions);
      },
      deep: true
    }
  }
};
</script>
```

## 🚀 Build Integration

### Update WhisperDesk Build Scripts

```javascript
// scripts/build-all.js - Add diarization to main build
async function buildAll() {
  console.log('🔧 Building WhisperDesk with enhanced diarization...');
  
  // Build whisper.cpp
  await execAsync('npm run build:whisper');
  
  // Build diarization system
  try {
    await execAsync('npm run build:diarization');
    console.log('✅ Multi-speaker diarization enabled');
  } catch (error) {
    console.warn('⚠️ Diarization build failed - single speaker mode only');
  }
  
  // Build renderer
  await execAsync('npm run build:renderer');
  
  // Build electron app
  await execAsync('npm run build:electron');
}
```

## 🎯 Testing Integration

```bash
# Test diarization availability
npm run debug:diarization

# Test full transcription with diarization
npm run test:enhanced-transcription

# Build everything
npm run build:all
```

## 📊 Expected Results

When properly integrated, WhisperDesk will:

1. **Detect multiple speakers** automatically
2. **Label transcript segments** by speaker
3. **Show speaker statistics** in the UI
4. **Gracefully fallback** to single-speaker mode if diarization fails
5. **Maintain performance** with optimized C++ implementation

## 🔧 Troubleshooting

### Common Issues:

1. **"diarize-cli not found"**
   - Run: `npm run build:diarization`
   - Check: `binaries/` directory for executable

2. **"Models not found"**
   - Models should be in `models/` directory
   - Check internet connection for downloads

3. **"Only 1 speaker detected"**
   - Lower threshold to 0.001
   - Check audio quality and length

4. **"Library errors"**
   - Verify ONNX Runtime libraries in `binaries/`
   - Check platform compatibility

### Debug Commands:

```bash
# Check diarization status
npm run debug:diarization

# Test with sample audio
./binaries/diarize-cli --audio samples/test.wav --segment-model models/segmentation-3.0.onnx --embedding-model models/embedding-1.0.onnx --verbose

# Check library dependencies
otool -L binaries/diarize-cli  # macOS
ldd binaries/diarize-cli       # Linux
```
```

---

## 📖 examples/cli/usage-examples.md

```markdown
# CLI Usage Examples

This document provides comprehensive examples of using the `diarize-cli` command-line tool.

## 🚀 Quick Start

### Basic Usage

```bash
# Simple diarization with default settings
./diarize-cli --audio recording.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx
```

### With Verbose Output

```bash
# Get detailed processing information
./diarize-cli --audio recording.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --verbose
```

## 🎚️ Sensitivity Examples

### High Sensitivity (Detect Many Speakers)

```bash
# Detect 3+ speakers in conversation
./diarize-cli --audio meeting.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --threshold 0.001 \
              --max-speakers 15 \
              --verbose
```

**Use for:** Meetings, conferences, group discussions

### Balanced Detection

```bash
# Standard detection for 2-3 speakers
./diarize-cli --audio interview.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --threshold 0.01 \
              --max-speakers 5
```

**Use for:** Interviews, dialogues, phone calls

### Conservative Detection

```bash
# Conservative detection for clear speaker differences
./diarize-cli --audio podcast.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --threshold 0.05 \
              --max-speakers 3
```

**Use for:** Podcasts, lectures, clean recordings

## 📁 File Processing Examples

### Single File with JSON Output

```bash
# Process single file and save results
./diarize-cli --audio recording.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --output results.json \
              --verbose
```

### Batch Processing Script

```bash
#!/bin/bash
# batch_diarize.sh - Process multiple audio files

MODELS_DIR="./models"
SEGMENT_MODEL="$MODELS_DIR/segmentation-3.0.onnx"
EMBEDDING_MODEL="$MODELS_DIR/embedding-1.0.onnx"

# Process all WAV files in directory
for audio_file in *.wav; do
    if [ -f "$audio_file" ]; then
        echo "🎵 Processing: $audio_file"
        
        # Generate output filename
        output_file="${audio_file%.wav}_diarization.json"
        
        # Run diarization
        ./diarize-cli --audio "$audio_file" \
                      --segment-model "$SEGMENT_MODEL" \
                      --embedding-model "$EMBEDDING_MODEL" \
                      --output "$output_file" \
                      --threshold 0.01 \
                      --max-speakers 10
        
        echo "✅ Results saved to: $output_file"
        echo ""
    fi
done

echo "🎉 Batch processing complete!"
```

### Different Audio Formats

```bash
# Convert and process MP3
ffmpeg -i input.mp3 -ar 16000 -ac 1 -c:a pcm_s16le temp.wav
./diarize-cli --audio temp.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --output results.json

# Convert and process M4A
ffmpeg -i input.m4a -ar 16000 -ac 1 -c:a pcm_s16le temp.wav
./diarize-cli --audio temp.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --threshold 0.005
```

## 📊 Output Examples

### Standard JSON Output

```json
{
  "segments": [
    {
      "start_time": 0.0,
      "end_time": 3.2,
      "speaker_id": 0,
      "confidence": 0.89,
      "duration": 3.2
    },
    {
      "start_time": 3.2,
      "end_time": 7.1,
      "speaker_id": 1,
      "confidence": 0.92,
      "duration": 3.9
    }
  ],
  "total_speakers": 2,
  "total_duration": 45.3,
  "audio_path": "recording.wav",
  "model_info": {
    "segment_model": "models/segmentation-3.0.onnx",
    "embedding_model": "models/embedding-1.0.onnx",
    "max_speakers": 10,
    "threshold": 0.01
  },
  "speakers": [
    {
      "speaker_id": 0,
      "segment_count": 5,
      "total_duration": 22.1,
      "average_confidence": 0.87
    },
    {
      "speaker_id": 1,
      "segment_count": 4,
      "total_duration": 23.2,
      "average_confidence": 0.91
    }
  ]
}
```

## 🔧 Troubleshooting Examples

### Check Installation

```bash
# Verify binary works
./diarize-cli --help

# Check models exist
ls -la models/
# Should show:
# segmentation-3.0.onnx (>5MB)
# embedding-1.0.onnx (>15MB)
```

### Debug Mode

```bash
# Maximum verbosity for debugging
./diarize-cli --audio problem_file.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --threshold 0.001 \
              --verbose \
              --debug
```

### Library Dependencies (macOS)

```bash
# Check what libraries the binary needs
otool -L ./diarize-cli

# Should show:
# libonnxruntime.dylib
# libjsoncpp.dylib
# System libraries
```

### Library Dependencies (Linux)

```bash
# Check library dependencies
ldd ./diarize-cli

# Should show:
# libonnxruntime.so
# libjsoncpp.so
# System libraries
```

## 🎯 Use Case Examples

### Meeting Transcription

```bash
# Corporate meeting with 4-6 participants
./diarize-cli --audio team_meeting.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --threshold 0.005 \
              --max-speakers 8 \
              --output meeting_speakers.json \
              --verbose
```

### Interview Analysis

```bash
# One-on-one interview
./diarize-cli --audio interview.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --threshold 0.02 \
              --max-speakers 2 \
              --output interview_analysis.json
```

### Podcast Processing

```bash
# Podcast with host and guests
./diarize-cli --audio podcast_episode.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --threshold 0.01 \
              --max-speakers 4 \
              --output podcast_speakers.json
```

### Conference Call

```bash
# Large conference call
./diarize-cli --audio conference_call.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --threshold 0.001 \
              --max-speakers 20 \
              --output conference_speakers.json \
              --verbose
```

## 📈 Performance Tips

### For Long Audio Files (>1 hour)

```bash
# Use conservative settings for performance
./diarize-cli --audio long_recording.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --threshold 0.02 \
              --max-speakers 6
```

### For Real-time Processing

```bash
# Optimize for speed
./diarize-cli --audio live_stream_chunk.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --threshold 0.01 \
              --max-speakers 4
```

## 🔄 Integration with Other Tools

### With whisper.cpp

```bash
# 1. First, diarize the audio
./diarize-cli --audio recording.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --output speakers.json

# 2. Then transcribe with whisper
./whisper-cli -m models/ggml-base.en.bin -f recording.wav -of speakers.json

# 3. Merge results with custom script
python merge_transcription_speakers.py speakers.json transcription.json
```

### With FFmpeg Pre-processing

```bash
# Clean audio before diarization
ffmpeg -i noisy_audio.wav \
       -af "highpass=f=80,lowpass=f=8000,volume=1.5" \
       -ar 16000 -ac 1 \
       clean_audio.wav

# Then diarize the cleaned audio
./diarize-cli --audio clean_audio.wav \
              --segment-model models/segmentation-3.0.onnx \
              --embedding-model models/embedding-1.0.onnx \
              --threshold 0.01
```

## 📋 Command Reference

### Required Arguments
- `--audio <PATH>` - Input audio file
- `--segment-model <PATH>` - Segmentation ONNX model
- `--embedding-model <PATH>` - Embedding ONNX model

### Optional Arguments
- `--threshold <FLOAT>` - Speaker similarity threshold (0.001-0.1)
- `--max-speakers <NUM>` - Maximum speakers to detect
- `--output <PATH>` - Output JSON file
- `--verbose` - Detailed progress output
- `--help` - Show help message
- `--version` - Show version information

### Threshold Guidelines
- **0.001-0.005**: Very sensitive, detects subtle speaker differences
- **0.005-0.01**: Balanced, good for most use cases
- **0.01-0.05**: Conservative, clear speaker differences only
- **0.05-0.1**: Very conservative, obvious speaker changes only

### Expected Performance
- **Processing Speed**: 3-10x real-time on modern hardware
- **Memory Usage**: 200MB-800MB depending on audio length
- **Accuracy**: 85-95% on clean audio with distinct speakers