# Audio Router Scripts

A collection of scripts for managing audio routing between devices using PulseAudio/PipeWire.

## Files

- `audio_router.sh` - Main audio routing script with full functionality
- `audio_quick.sh` - Quick shortcuts for common tasks
- `README.md` - This documentation

## Quick Start

### Common Tasks

```bash
# List all audio devices
./audio_quick.sh list

# Route SPDIF to Model 12 (normal latency)
./audio_quick.sh stm

# Route SPDIF to Model 12 (low latency)
./audio_quick.sh stml

# Stop all audio routing
./audio_quick.sh reset
```

### Advanced Usage

```bash
# Route multiple inputs to multiple outputs
./audio_router.sh -i spdif -i usb -o model -o hdmi

# Custom latency settings
./audio_router.sh -i spdif -o model --latency 25

# Verbose output for troubleshooting
./audio_router.sh -i spdif -o model --verbose
```

## Main Script Options

### Flags

- `-i, --input DEVICE` - Input device (can be used multiple times)
- `-o, --output DEVICE` - Output device (can be used multiple times)
- `-l, --list` - List all available devices
- `-r, --reset` - Reset all audio routing
- `--low-latency` - Enable low latency mode (10ms)
- `--high-latency` - Use normal latency mode (50ms)
- `--latency MS` - Set custom latency in milliseconds
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help

### Device Matching

Device names are matched as case-insensitive substrings:

- `spdif` matches devices containing "spdif"
- `model` matches devices containing "model" 
- `usb` matches devices containing "usb"
- `hdmi` matches devices containing "hdmi"

You can also use full device names for exact matching.

## Examples

### Basic Routing

```bash
# Route SPDIF input to Model 12 output
./audio_router.sh -i spdif -o model

# Same with low latency
./audio_router.sh -i spdif -o model --low-latency
```

### Multiple Devices

```bash
# Route SPDIF to both Model 12 and HDMI
./audio_router.sh -i spdif -o model -o hdmi

# Route both SPDIF and USB input to Model 12
./audio_router.sh -i spdif -i usb -o model
```

### Latency Control

```bash
# Low latency (10ms) - good for real-time monitoring
./audio_router.sh -i spdif -o model --low-latency

# Custom latency (25ms) - balance between latency and stability
./audio_router.sh -i spdif -o model --latency 25

# High latency (50ms) - most stable, default
./audio_router.sh -i spdif -o model --high-latency
```

### Troubleshooting

```bash
# List devices to see what's available
./audio_router.sh --list

# Use verbose mode to see what's happening
./audio_router.sh -i spdif -o model --verbose

# Reset everything if something goes wrong
./audio_router.sh --reset
```

## Requirements

- PulseAudio or PipeWire with PulseAudio compatibility
- `pactl` command available
- Bash shell

## Notes

- The script creates loopback modules that persist until reset or system restart
- Multiple routes can be active simultaneously
- Lower latency settings may cause audio dropouts on slower systems
- Use `--reset` to clean up all routing before creating new routes
- Monitor sources (ending in `.monitor`) are automatically filtered out

## Troubleshooting

### Audio Dropouts
- Try higher latency: `--latency 100`
- Check system load and close unnecessary applications
- Ensure audio devices are properly connected

### Device Not Found
- Use `--list` to see available devices
- Check device name spelling and try partial matches
- Ensure the device is connected and recognized by the system

### No Sound
- Check volume levels on both input and output devices
- Verify the correct devices are being used with `--verbose`
- Try `--reset` and recreate the routing

### Permission Issues
- Ensure you're in the `audio` group: `groups $USER`
- Check that PulseAudio/PipeWire is running for your user session
