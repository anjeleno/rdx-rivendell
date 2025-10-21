#!/bin/bash
# RDX AAC+ Streaming Helper
# Professional AAC+ streaming for Rivendell systems

SCRIPT_NAME="rdx-aac-stream"
VERSION="1.0.0"

# Default configuration
INPUT_DEVICE="pulse"
SAMPLE_RATE="44100"
BITRATE="64"
CHANNELS="2"
USE_HE_AAC="true"
USE_HE_AAC_V2="false"
STREAM_URL=""
LOG_FILE="/tmp/rdx-aac-stream.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  RDX AAC+ Streamer v${VERSION}${NC}"
    echo -e "${BLUE}  High-Quality Streaming for Rivendell${NC}" 
    echo -e "${BLUE}============================================${NC}"
}

print_usage() {
    print_header
    echo "Usage: $0 [options] <stream_url>"
    echo ""
    echo "Options:"
    echo "  -i <device>     Input device (default: pulse)"
    echo "  -r <rate>       Sample rate in Hz (default: 44100)"
    echo "  -b <bitrate>    Bitrate in kbps (default: 64)"
    echo "  -c <channels>   Number of channels (default: 2)"
    echo "  -1              Use HE-AAC v1 (default)"
    echo "  -2              Use HE-AAC v2 (stereo only)"
    echo "  -n              Disable HE-AAC (use LC-AAC)"
    echo "  -l <logfile>    Log file path (default: /tmp/rdx-aac-stream.log)"
    echo "  -d              Daemon mode (run in background)"
    echo "  -s              Stop running stream"
    echo "  -t              Test stream configuration"
    echo "  -h              Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 icecast://source:password@server:8000/stream.aac"
    echo "  $0 -b 96 -2 rtmp://server/live/stream"
    echo "  $0 -i alsa_input.pci-0000_00_1b.0.analog-stereo http://server:8000/stream"
    echo ""
    echo "Stream Formats Supported:"
    echo "  • HE-AAC v1 (most efficient for low bitrates)"
    echo "  • HE-AAC v2 (stereo enhancement for very low bitrates)"
    echo "  • LC-AAC (standard AAC for higher bitrates)"
    echo ""
}

check_dependencies() {
    if ! command -v ffmpeg &> /dev/null; then
        echo -e "${RED}Error: FFmpeg not found. Please install ffmpeg.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ FFmpeg found${NC}"
}

get_aac_profile() {
    if [ "$USE_HE_AAC" = "true" ]; then
        if [ "$USE_HE_AAC_V2" = "true" ] && [ "$CHANNELS" = "2" ]; then
            echo "aac_he_v2"
        else
            echo "aac_he"
        fi
    else
        echo "aac_low"
    fi
}

build_ffmpeg_command() {
    local profile=$(get_aac_profile)
    
    echo "ffmpeg \
        -f pulse \
        -i $INPUT_DEVICE \
        -acodec aac \
        -profile:a $profile \
        -ar $SAMPLE_RATE \
        -ac $CHANNELS \
        -b:a ${BITRATE}k \
        -f adts \
        -content_type audio/aac \
        -reconnect 1 \
        -reconnect_streamed 1 \
        -reconnect_delay_max 5 \
        -loglevel info \
        $STREAM_URL"
}

print_config() {
    echo -e "\n${YELLOW}=== Stream Configuration ===${NC}"
    echo "Input Device: $INPUT_DEVICE"
    echo "Stream URL: $STREAM_URL"
    echo "Sample Rate: $SAMPLE_RATE Hz"
    echo "Bitrate: $BITRATE kbps"
    echo "Channels: $CHANNELS"
    echo "AAC Profile: $(get_aac_profile)"
    echo "Log File: $LOG_FILE"
    echo -e "${YELLOW}===============================${NC}\n"
}

test_stream() {
    print_config
    echo -e "${BLUE}Testing stream configuration...${NC}"
    
    # Test for 10 seconds
    local cmd=$(build_ffmpeg_command)
    timeout 10s $cmd > "$LOG_FILE" 2>&1
    
    if [ $? -eq 124 ]; then
        echo -e "${GREEN}✓ Stream test successful (10 seconds)${NC}"
        echo "Check log file for details: $LOG_FILE"
    else
        echo -e "${RED}✗ Stream test failed${NC}"
        echo "Check log file for errors: $LOG_FILE"
        tail -20 "$LOG_FILE"
        exit 1
    fi
}

start_stream() {
    print_config
    
    # Check if already running
    if pgrep -f "ffmpeg.*$STREAM_URL" > /dev/null; then
        echo -e "${YELLOW}Warning: Stream appears to already be running${NC}"
        echo "Use '$0 -s' to stop existing stream first"
        exit 1
    fi
    
    echo -e "${GREEN}Starting AAC+ stream...${NC}"
    
    local cmd=$(build_ffmpeg_command)
    
    if [ "$DAEMON_MODE" = "true" ]; then
        nohup $cmd > "$LOG_FILE" 2>&1 &
        local pid=$!
        echo $pid > /tmp/rdx-aac-stream.pid
        echo -e "${GREEN}Stream started in daemon mode (PID: $pid)${NC}"
        echo "Log file: $LOG_FILE"
    else
        echo "Command: $cmd"
        echo -e "${BLUE}Press Ctrl+C to stop stream${NC}"
        $cmd 2>&1 | tee "$LOG_FILE"
    fi
}

stop_stream() {
    echo -e "${YELLOW}Stopping AAC+ stream...${NC}"
    
    # Kill by URL pattern
    local pids=$(pgrep -f "ffmpeg.*$STREAM_URL")
    if [ -n "$pids" ]; then
        echo $pids | xargs kill -TERM
        sleep 2
        echo $pids | xargs kill -KILL 2>/dev/null
        echo -e "${GREEN}✓ Stream stopped${NC}"
    else
        echo -e "${YELLOW}No stream found for URL: $STREAM_URL${NC}"
    fi
    
    # Clean up PID file
    rm -f /tmp/rdx-aac-stream.pid
}

# Parse command line arguments
DAEMON_MODE="false"
TEST_MODE="false"
STOP_MODE="false"

while getopts "i:r:b:c:12nl:dsth" opt; do
    case $opt in
        i) INPUT_DEVICE="$OPTARG" ;;
        r) SAMPLE_RATE="$OPTARG" ;;
        b) BITRATE="$OPTARG" ;;
        c) CHANNELS="$OPTARG" ;;
        1) USE_HE_AAC="true"; USE_HE_AAC_V2="false" ;;
        2) USE_HE_AAC="true"; USE_HE_AAC_V2="true" ;;
        n) USE_HE_AAC="false"; USE_HE_AAC_V2="false" ;;
        l) LOG_FILE="$OPTARG" ;;
        d) DAEMON_MODE="true" ;;
        s) STOP_MODE="true" ;;
        t) TEST_MODE="true" ;;
        h) print_usage; exit 0 ;;
        *) print_usage; exit 1 ;;
    esac
done

shift $((OPTIND-1))

# Get stream URL
if [ "$STOP_MODE" = "false" ] && [ $# -eq 0 ]; then
    echo -e "${RED}Error: Stream URL required${NC}"
    print_usage
    exit 1
fi

if [ $# -gt 0 ]; then
    STREAM_URL="$1"
fi

# Main execution
print_header
check_dependencies

if [ "$STOP_MODE" = "true" ]; then
    stop_stream
elif [ "$TEST_MODE" = "true" ]; then
    test_stream
else
    start_stream
fi