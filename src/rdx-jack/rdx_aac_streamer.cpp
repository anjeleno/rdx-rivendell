// RDX AAC+ Stream Generator
// Provides high-quality AAC+ streaming for Rivendell systems
// Supports HE-AAC v1 and v2 for efficient internet streaming

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <cstdlib>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libswresample/swresample.h>
}

class AACStreamer {
private:
    std::string input_device;
    std::string output_url;
    int sample_rate;
    int bitrate;
    int channels;
    bool use_he_aac;
    bool use_he_aac_v2;
    pid_t ffmpeg_pid;
    
public:
    AACStreamer() 
        : input_device("pulse"), 
          output_url(""),
          sample_rate(44100),
          bitrate(64),
          channels(2),
          use_he_aac(true),
          use_he_aac_v2(false),
          ffmpeg_pid(-1) {}
    
    void setInputDevice(const std::string& device) { input_device = device; }
    void setOutputURL(const std::string& url) { output_url = url; }
    void setSampleRate(int rate) { sample_rate = rate; }
    void setBitrate(int rate) { bitrate = rate; }
    void setChannels(int ch) { channels = ch; }
    void setHEAAC(bool enable) { use_he_aac = enable; }
    void setHEAACv2(bool enable) { use_he_aac_v2 = enable; }
    
    bool startStream() {
        if (output_url.empty()) {
            std::cerr << "Error: Output URL not specified" << std::endl;
            return false;
        }
        
        // Build FFmpeg command for AAC+ streaming
        std::vector<std::string> cmd = {
            "ffmpeg",
            "-f", "pulse",
            "-i", input_device,
            "-acodec", getAACCodec(),
            "-ar", std::to_string(sample_rate),
            "-ac", std::to_string(channels),
            "-b:a", std::to_string(bitrate) + "k"
        };
        
        // Add HE-AAC specific options
        if (use_he_aac) {
            cmd.push_back("-profile:a");
            if (use_he_aac_v2 && channels == 2) {
                cmd.push_back("aac_he_v2");
            } else {
                cmd.push_back("aac_he");
            }
        }
        
        // Add streaming format options
        cmd.insert(cmd.end(), {
            "-f", getStreamFormat(),
            "-content_type", "audio/aac",
            "-ice_name", "RDX AAC+ Stream",
            "-ice_description", "High Quality AAC+ Stream from Rivendell",
            "-ice_genre", "Radio",
            "-reconnect", "1",
            "-reconnect_streamed", "1",
            "-reconnect_delay_max", "5",
            output_url
        });
        
        return executeFFmpeg(cmd);
    }
    
    void stopStream() {
        if (ffmpeg_pid > 0) {
            kill(ffmpeg_pid, SIGTERM);
            int status;
            waitpid(ffmpeg_pid, &status, 0);
            ffmpeg_pid = -1;
            std::cout << "AAC+ stream stopped" << std::endl;
        }
    }
    
    bool isStreaming() const {
        return ffmpeg_pid > 0;
    }
    
    void printConfig() const {
        std::cout << "\n=== RDX AAC+ Streamer Configuration ===" << std::endl;
        std::cout << "Input Device: " << input_device << std::endl;
        std::cout << "Output URL: " << output_url << std::endl;
        std::cout << "Sample Rate: " << sample_rate << " Hz" << std::endl;
        std::cout << "Bitrate: " << bitrate << " kbps" << std::endl;
        std::cout << "Channels: " << channels << std::endl;
        std::cout << "Codec: " << getAACCodec() << std::endl;
        if (use_he_aac) {
            std::cout << "HE-AAC: Enabled";
            if (use_he_aac_v2 && channels == 2) {
                std::cout << " (v2)";
            } else {
                std::cout << " (v1)";
            }
            std::cout << std::endl;
        }
        std::cout << "=====================================\n" << std::endl;
    }
    
private:
    std::string getAACCodec() const {
        // Use libfdk_aac if available, fallback to aac
        return "aac";  // FFmpeg's native AAC encoder supports HE-AAC
    }
    
    std::string getStreamFormat() const {
        if (output_url.find("icecast://") == 0 || output_url.find("shoutcast://") == 0) {
            return "mp3";  // Some servers need this format specifier
        }
        return "adts";  // Raw AAC with ADTS headers
    }
    
    bool executeFFmpeg(const std::vector<std::string>& cmd) {
        // Convert to char* array for execvp
        std::vector<char*> argv;
        for (const auto& arg : cmd) {
            argv.push_back(const_cast<char*>(arg.c_str()));
        }
        argv.push_back(nullptr);
        
        // Print command for debugging
        std::cout << "Starting AAC+ stream: ";
        for (const auto& arg : cmd) {
            std::cout << arg << " ";
        }
        std::cout << std::endl;
        
        ffmpeg_pid = fork();
        if (ffmpeg_pid == 0) {
            // Child process - execute FFmpeg
            execvp("ffmpeg", argv.data());
            perror("execvp failed");
            exit(1);
        } else if (ffmpeg_pid > 0) {
            // Parent process
            std::cout << "AAC+ stream started with PID: " << ffmpeg_pid << std::endl;
            return true;
        } else {
            perror("fork failed");
            return false;
        }
    }
};

// Global streamer instance for signal handling
AACStreamer* g_streamer = nullptr;

void signalHandler(int signal) {
    if (g_streamer) {
        std::cout << "\nReceived signal " << signal << ", stopping AAC+ stream..." << std::endl;
        g_streamer->stopStream();
        exit(0);
    }
}

void printUsage(const char* program_name) {
    std::cout << "RDX AAC+ Streamer - High Quality Audio Streaming for Rivendell" << std::endl;
    std::cout << "Usage: " << program_name << " [options] <output_url>" << std::endl;
    std::cout << "\nOptions:" << std::endl;
    std::cout << "  -i <device>     Input device (default: pulse)" << std::endl;
    std::cout << "  -r <rate>       Sample rate in Hz (default: 44100)" << std::endl;
    std::cout << "  -b <bitrate>    Bitrate in kbps (default: 64)" << std::endl;
    std::cout << "  -c <channels>   Number of channels (default: 2)" << std::endl;
    std::cout << "  -1              Use HE-AAC v1 (default)" << std::endl;
    std::cout << "  -2              Use HE-AAC v2 (stereo only)" << std::endl;
    std::cout << "  -n              Disable HE-AAC (use LC-AAC)" << std::endl;
    std::cout << "  -h              Show this help" << std::endl;
    std::cout << "\nExamples:" << std::endl;
    std::cout << "  " << program_name << " icecast://source:password@server:8000/stream.aac" << std::endl;
    std::cout << "  " << program_name << " -b 96 -2 rtmp://server/live/stream" << std::endl;
    std::cout << "  " << program_name << " -i alsa_input.pci-0000_00_1b.0.analog-stereo http://server:8000/stream" << std::endl;
}

int main(int argc, char* argv[]) {
    AACStreamer streamer;
    g_streamer = &streamer;
    
    // Set up signal handlers
    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);
    
    // Parse command line arguments
    int opt;
    while ((opt = getopt(argc, argv, "i:r:b:c:12nh")) != -1) {
        switch (opt) {
            case 'i':
                streamer.setInputDevice(optarg);
                break;
            case 'r':
                streamer.setSampleRate(atoi(optarg));
                break;
            case 'b':
                streamer.setBitrate(atoi(optarg));
                break;
            case 'c':
                streamer.setChannels(atoi(optarg));
                break;
            case '1':
                streamer.setHEAAC(true);
                streamer.setHEAACv2(false);
                break;
            case '2':
                streamer.setHEAAC(true);
                streamer.setHEAACv2(true);
                break;
            case 'n':
                streamer.setHEAAC(false);
                streamer.setHEAACv2(false);
                break;
            case 'h':
                printUsage(argv[0]);
                return 0;
            default:
                printUsage(argv[0]);
                return 1;
        }
    }
    
    // Get output URL
    if (optind >= argc) {
        std::cerr << "Error: Output URL required" << std::endl;
        printUsage(argv[0]);
        return 1;
    }
    
    streamer.setOutputURL(argv[optind]);
    streamer.printConfig();
    
    // Start streaming
    if (!streamer.startStream()) {
        std::cerr << "Failed to start AAC+ stream" << std::endl;
        return 1;
    }
    
    // Wait for stream to finish
    std::cout << "AAC+ stream running... Press Ctrl+C to stop" << std::endl;
    while (streamer.isStreaming()) {
        sleep(1);
    }
    
    return 0;
}