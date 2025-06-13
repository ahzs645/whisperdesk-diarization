#!/bin/bash
# Build script for whisperdesk-diarization

set -e
set -x

echo "🎭 Building whisperdesk-diarization..."
node scripts/build.js "$@"