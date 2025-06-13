# whisperdesk-diarization

> **Advanced Multi-Speaker Diarization Engine**  
> Cross-platform C++ implementation with PyAnnote 3.0 ONNX models

## 🎭 Features

- **🎯 Speaker Segmentation** - Detect when speakers change using PyAnnote 3.0
- **👥 Speaker Embedding** - Generate speaker embeddings for identification  
- **🔧 Cross-Platform** - Windows, macOS, Linux support via ONNX Runtime
- **⚡ High Performance** - Optimized C++ implementation
- **🎚️ Configurable** - Adjustable sensitivity and speaker limits
- **📊 Rich Output** - JSON results with speaker statistics
- **🔗 Easy Integration** - Simple CLI interface or C++ library

## 🚀 Quick Start

### CLI Usage
```bash
# Basic diarization
./diarize-cli --audio recording.wav \
              --segment-model segmentation-3.0.onnx \
              --embedding-model embedding-1.0.onnx

# High sensitivity (detect more speakers)
./diarize-cli --audio recording.wav \
              --segment-model segmentation-3.0.onnx \
              --embedding-model embedding-1.0.onnx \
              --threshold 0.001 --verbose

# Conservative detection
./diarize-cli --audio recording.wav \
              --segment-model segmentation-3.0.onnx \
              --embedding-model embedding-1.0.onnx \
              --threshold 0.05 --max-speakers 3
```

### Library Usage
```cpp
#include "diarize-cli.h"

DiarizationEngine engine(true); // verbose=true
engine.initialize("segmentation-3.0.onnx", "embedding-1.0.onnx");

DiarizeOptions options;
options.threshold = 0.01f;
options.max_speakers = 10;

auto segments = engine.process_audio(audio_samples, options);
```

## 📦 Installation

### Pre-built Binaries
Download from [Releases](https://github.com/whisperdesk/whisperdesk-diarization/releases):
- `diarize-cli-windows-x64.zip`
- `diarize-cli-macos-x64.zip` 
- `diarize-cli-macos-arm64.zip`
- `diarize-cli-linux-x64.tar.gz`

### Build from Source
```bash
git clone https://github.com/whisperdesk/whisperdesk-diarization.git
cd whisperdesk-diarization
./scripts/build.sh
```

## 🧠 Models

Download PyAnnote 3.0 ONNX models:
```bash
# Segmentation model (speaker change detection)
wget https://huggingface.co/pyannote/segmentation-3.0/resolve/main/pytorch_model.onnx \
     -O segmentation-3.0.onnx

# Embedding model (speaker identification)  
wget https://huggingface.co/pyannote/embedding/resolve/main/pytorch_model.onnx \
     -O embedding-1.0.onnx
```

## 📋 API Reference

### Command Line Options
```
--audio <PATH>              Input audio file
--segment-model <PATH>      Segmentation ONNX model
--embedding-model <PATH>    Embedding ONNX model
--threshold <FLOAT>         Speaker similarity threshold (0.001-0.1)
--max-speakers <NUM>        Maximum speakers to detect
--output <PATH>             Output JSON file
--verbose                   Detailed progress output
```

### Threshold Guidelines
- **0.001-0.01**: High sensitivity, detects 3+ speakers
- **0.01-0.05**: Balanced detection
- **0.05-0.1**: Conservative, 1-2 speakers

## 🏗️ Architecture

```
whisperdesk-diarization/
├── include/
│   ├── diarize-cli.h           # Main engine interface
│   ├── speaker-segmenter.h     # PyAnnote segmentation
│   ├── speaker-embedder.h      # PyAnnote embedding
│   └── utils.h                 # Utilities
├── src/
│   ├── diarize-cli.cpp         # Main implementation
│   ├── speaker-segmenter.cpp   # Segmentation logic
│   ├── speaker-embedder.cpp    # Embedding logic
│   └── utils.cpp               # Utility functions
├── scripts/
│   ├── build.sh                # Cross-platform build
│   └── download-models.sh      # Model download
├── examples/
│   ├── cpp/                    # C++ integration examples
│   ├── python/                 # Python binding examples
│   └── integration/            # Integration examples
└── CMakeLists.txt              # Build configuration
```

## 🔧 Dependencies

- **ONNX Runtime** 1.16.3+
- **jsoncpp** (JSON output)
- **CMake** 3.15+
- **C++17** compiler

## 🤝 Integration

### WhisperDesk Integration
```bash
# Add as submodule
git submodule add https://github.com/whisperdesk/whisperdesk-diarization.git deps/diarization

# Build in your project
cd deps/diarization && ./scripts/build.sh
cp deps/diarization/build/diarize-cli ./binaries/
```

### Other Projects
```bash
# Use as CLI tool
./diarize-cli --audio audio.wav --segment-model seg.onnx --embedding-model emb.onnx

# Or link as library
find_package(WhisperDeskDiarization REQUIRED)
target_link_libraries(your_app WhisperDeskDiarization::diarization)
```

## 📊 Performance

| Audio Length | Processing Time | Memory Usage | Speakers Detected |
|-------------|----------------|--------------|-------------------|
| 1 minute    | ~5 seconds     | ~200MB       | 1-3               |
| 10 minutes  | ~30 seconds    | ~400MB       | 2-5               |
| 1 hour      | ~3 minutes     | ~800MB       | 3-8               |

*Tested on Intel i7-10700K, 32GB RAM*

## 🔬 Technical Details

- **Segmentation**: PyAnnote 3.0 transformer model for speaker change detection
- **Embedding**: PyAnnote embedding model for speaker representation  
- **Clustering**: Cosine similarity-based speaker clustering
- **Runtime**: ONNX Runtime for cross-platform AI inference
- **Audio**: 16kHz mono audio processing
- **Output**: JSON format with timestamps and confidence scores

## 🚀 Roadmap

- [ ] **Python Bindings** - PyPI package
- [ ] **Node.js Bindings** - npm package  
- [ ] **REST API** - HTTP service mode
- [ ] **Real-time Processing** - Streaming audio support
- [ ] **More Models** - Additional embedding models
- [ ] **GPU Acceleration** - CUDA/Metal support

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **PyAnnote Team** - For the excellent segmentation and embedding models
- **ONNX Runtime** - For cross-platform AI inference
- **whisper.cpp** - For inspiration on clean C++ AI implementations

## 📞 Support

- **GitHub Issues** - Bug reports and feature requests
- **Discussions** - General questions and community chat
- **Documentation** - [Wiki](https://github.com/whisperdesk/whisperdesk-diarization/wiki)

---

**Made with ❤️ by the WhisperDesk Team**
