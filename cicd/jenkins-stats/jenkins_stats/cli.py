#!/usr/bin/env python3
"""
Command-line interface wrapper for bash-style usage
"""

import sys
import os
import subprocess
from pathlib import Path

# Colors for output
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color


def print_colored(message, color=NC):
    """Print colored message"""
    print(f"{color}{message}{NC}")


def error(message):
    """Print error message and exit"""
    print_colored(f"ERROR: {message}", RED)
    sys.exit(1)


def info(message):
    """Print info message"""
    print_colored(f"INFO: {message}", BLUE)


def success(message):
    """Print success message"""
    print_colored(f"SUCCESS: {message}", GREEN)


def warning(message):
    """Print warning message"""
    print_colored(f"WARNING: {message}", YELLOW)


def usage():
    """Print usage information"""
    prog_name = Path(sys.argv[0]).name
    print(f"""Jenkins Job Exporter - Bash-style Wrapper

USAGE:
    {prog_name} [OPTIONS] JENKINS_URL PARAMETER

ARGUMENTS:
    JENKINS_URL     Jenkins server URL (e.g., http://jenkins.example.com)
    PARAMETER       Parameter name to group builds by (e.g., environment, branch)

OPTIONS:
    -n, --max-jobs NUM      Maximum number of jobs to process
    -b, --max-builds NUM    Maximum builds per job (default: 100)
    -f, --filter PATTERN    Filter jobs by name pattern
    -o, --output DIR        Output directory (default: timestamped directory)
    -d, --delay SECONDS     Delay between API calls (default: 0.1)
    --netrc FILE            Path to netrc file for authentication (default: ~/.netrc)
    --export-configs        Export job configuration XML files
    --export-build-data     Export detailed build data JSON files
    -v, --verbose           Verbose output
    -h, --help              Show this help

EXAMPLES:
    # Basic usage - analyze 'environment' parameter for all jobs
    {prog_name} http://jenkins.example.com environment

    # Limit to 50 jobs and analyze 'branch' parameter
    {prog_name} -n 50 http://jenkins.example.com branch

    # Filter jobs containing 'deploy' and export configs
    {prog_name} -f deploy --export-configs http://jenkins.example.com environment

    # Use custom netrc file
    {prog_name} --netrc ~/my-jenkins-creds http://jenkins.example.com branch

    # Comprehensive export with custom output directory
    {prog_name} -n 100 -b 200 -o my_analysis --export-configs --export-build-data -v \\
       http://jenkins.example.com version

AUTHENTICATION:
    Add credentials to netrc file (default: ~/.netrc):
    machine jenkins.example.com
    login your-username
    password your-api-token

INSTALLATION:
    # Install with pipx (recommended)
    pipx install jenkins-stats

    # Install with pip
    pip install jenkins-stats

    # Install from source
    pip install -e .
""")


def check_dependencies():
    """Check if required dependencies are available"""
    try:
        import requests
        import netrc
    except ImportError as e:
        error(f"Required Python modules missing: {e}. Install with: pip install requests")


def validate_jenkins_url(url):
    """Validate Jenkins URL format"""
    if not url.startswith(('http://', 'https://')):
        error(f"Invalid Jenkins URL: {url} (must start with http:// or https://)")
    return url


def check_jenkins_connectivity(url):
    """Check if Jenkins is reachable"""
    try:
        import requests
        response = requests.get(url, timeout=10)
        return True
    except Exception:
        return False


def check_netrc_credentials(netrc_file, jenkins_url):
    """Check if netrc file contains credentials for Jenkins host"""
    import netrc as netrc_module
    from urllib.parse import urlparse
    
    # Expand tilde if present
    netrc_path = os.path.expanduser(netrc_file)
    
    if not os.path.isfile(netrc_path):
        warning(f"Netrc file not found: {netrc_file} - authentication may fail")
        return False
    
    try:
        netrc_auth = netrc_module.netrc(file=netrc_path)
        host = urlparse(jenkins_url).hostname
        
        auth_info = netrc_auth.authenticators(host)
        if auth_info:
            success(f"Found credentials for {host} in {netrc_file}")
            return True
        else:
            warning(f"No credentials found for {host} in {netrc_file}")
            return False
    except Exception as e:
        warning(f"Error reading {netrc_file}: {e}")
        return False


def main():
    """Main entry point for bash-style wrapper"""
    import argparse
    from datetime import datetime
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(
        description="Jenkins Job Exporter - Bash-style Wrapper",
        add_help=False  # We'll handle help ourselves
    )
    
    parser.add_argument('jenkins_url', nargs='?', help='Jenkins server URL')
    parser.add_argument('parameter', nargs='?', help='Parameter name to group builds by')
    parser.add_argument('-n', '--max-jobs', type=int, help='Maximum number of jobs to process')
    parser.add_argument('-b', '--max-builds', type=int, default=100, help='Maximum builds per job')
    parser.add_argument('-f', '--filter', help='Filter jobs by name pattern')
    parser.add_argument('-o', '--output', help='Output directory')
    parser.add_argument('-d', '--delay', type=float, default=0.1, help='Delay between API calls')
    parser.add_argument('--netrc', default='~/.netrc', help='Path to netrc file for authentication')
    parser.add_argument('--export-configs', action='store_true', help='Export job configuration XML files')
    parser.add_argument('--export-build-data', action='store_true', help='Export detailed build data JSON files')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    parser.add_argument('-h', '--help', action='store_true', help='Show help')
    
    args = parser.parse_args()
    
    # Handle help
    if args.help or not args.jenkins_url or not args.parameter:
        usage()
        if args.help:
            sys.exit(0)
        else:
            sys.exit(1)
    
    # Set default output directory if not specified
    if not args.output:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        args.output = f"jenkins_export_{timestamp}"
        info(f"Using default output directory: {args.output}")
    
    # Pre-flight checks
    info("Checking dependencies...")
    check_dependencies()
    
    # Validate Jenkins URL
    validate_jenkins_url(args.jenkins_url)
    
    info("Checking Jenkins connectivity...")
    if not check_jenkins_connectivity(args.jenkins_url):
        warning(f"Cannot reach Jenkins at {args.jenkins_url} (continuing anyway)")
    
    info("Checking for netrc credentials...")
    check_netrc_credentials(args.netrc, args.jenkins_url)
    
    # Build command for jenkins-stats module
    cmd = [
        sys.executable, '-m', 'jenkins_stats',
        args.jenkins_url,
        '--parameter', args.parameter,
    ]
    
    # Add optional arguments
    if args.max_jobs:
        cmd.extend(['--max-jobs', str(args.max_jobs)])
    if args.max_builds != 100:
        cmd.extend(['--max-builds', str(args.max_builds)])
    if args.filter:
        cmd.extend(['--filter', args.filter])
    if args.output:
        cmd.extend(['--output', args.output])
    if args.delay != 0.1:
        cmd.extend(['--delay', str(args.delay)])
    if args.netrc != '~/.netrc':
        cmd.extend(['--netrc', args.netrc])
    if args.export_configs:
        cmd.append('--export-configs')
    if args.export_build_data:
        cmd.append('--export-build-data')
    if args.verbose:
        cmd.append('--verbose')
    
    # Execute the command
    info("Starting Jenkins job export...")
    if args.verbose:
        print(f"Command: {' '.join(cmd)}")
    print()
    
    try:
        result = subprocess.run(cmd, check=True)
        success("Jenkins job export completed successfully!")
        
        # Show output directory contents if it exists
        if os.path.isdir(args.output):
            print()
            info("Output files:")
            subprocess.run(['ls', '-la', args.output])
            
    except subprocess.CalledProcessError as e:
        error(f"Jenkins job export failed with exit code {e.returncode}")
    except KeyboardInterrupt:
        error("Export interrupted by user")
    except Exception as e:
        error(f"Unexpected error: {e}")


if __name__ == "__main__":
    main()
