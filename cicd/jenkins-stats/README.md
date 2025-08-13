# Jenkins Job Statistics Exporter

Export Jenkins jobs and analyze build statistics grouped by parameter values.

## Installation

### With pipx (Recommended)
```bash
# Install pipx if you don't have it
python3 -m pip install --user pipx
python3 -m pipx ensurepath

# Install jenkins-stats
pipx install jenkins-stats

# Or install from local source
pipx install .
```

### With pip
```bash
# Install from PyPI (when published)
pip install jenkins-stats

# Install from local source
pip install .

# Install in development mode
pip install -e .
```

### Dependencies
The only runtime dependency is `requests>=2.25.0`, which will be installed automatically.

## Quick Start

After installation, you have two commands available:

- `jenkins-stats` - Direct Python interface
- `jenkins-export` - Bash-style wrapper with enhanced UX

```bash
# Basic usage with jenkins-stats
jenkins-stats http://jenkins.example.com --parameter environment

# Basic usage with jenkins-export (bash-style)
jenkins-export http://jenkins.example.com environment
```

### ⚠️ Important: Use Jenkins Server Root URL

The tool requires the **Jenkins server root URL**, not a specific job or view URL:

✅ **Correct URLs:**
- `http://jenkins.example.com`
- `https://jenkins.company.com`
- `http://jenkins.example.com:8080`

❌ **Incorrect URLs:**
- `http://jenkins.example.com/job/my-project` (specific job)
- `http://jenkins.example.com/view/my-view` (view URL)
- `http://jenkins.example.com/job/folder/job/project` (nested job)

The tool will automatically discover all jobs on the Jenkins server and filter them as needed.

## Usage Examples

### Basic Usage - Multiple Jobs
```bash
# Analyze 'environment' parameter for all jobs on Jenkins server
jenkins-export http://jenkins.example.com environment

# Analyze first 100 jobs by 'branch' parameter  
jenkins-stats http://jenkins.example.com --parameter branch --max-jobs 100
```

### Single Job Analysis
```bash
# Analyze a specific job's builds grouped by parameter
jenkins-export --single-job http://jenkins.example.com/job/my-project environment

# Analyze nested job (folders/pipelines)
jenkins-stats --single-job http://jenkins.example.com/job/folder/job/project --parameter branch

# Analyze single job with more build history
jenkins-export --single-job -b 200 http://jenkins.example.com/job/my-project version
```

### Advanced Usage
```bash
# Filter jobs and export configs (multi-job mode)
jenkins-export -f deploy --export-configs http://jenkins.example.com environment

# Use custom netrc file
jenkins-export --netrc ~/my-jenkins-creds http://jenkins.example.com branch

# Comprehensive analysis with custom output
jenkins-export -n 500 -b 150 -o my_analysis --export-configs --export-build-data -v \
  http://jenkins.example.com version
```

### Using jenkins-stats (Direct Python Interface)
```bash
# Direct interface with all options
jenkins-stats http://jenkins.example.com \
  --parameter environment --max-jobs 100 --verbose --delay 0.2

# Use custom netrc file
jenkins-stats http://jenkins.example.com \
  --parameter branch --netrc ~/alt-creds/.netrc --max-builds 50
```

### Module Usage
```bash
# Run as Python module
python -m jenkins_stats http://jenkins.example.com --parameter environment
```

## Command Line Options

### Bash Wrapper (`jenkins-export`)
```
-n, --max-jobs NUM      Maximum number of jobs to process
-b, --max-builds NUM    Maximum builds per job (default: 100)
-f, --filter PATTERN    Filter jobs by name pattern
-o, --output DIR        Output directory (default: timestamped directory)
-d, --delay SECONDS     Delay between API calls (default: 0.1)
--netrc FILE            Path to netrc file for authentication (default: ~/.netrc)
--single-job            Analyze a single job instead of all jobs on server
--export-configs        Export job configuration XML files
--export-build-data     Export detailed build data JSON files
-v, --verbose           Verbose output
-h, --help              Show help
```

## Output Files

The script generates several output files:

- `statistics_by_{parameter}.csv` - Summary statistics in CSV format
- `statistics_by_{parameter}.json` - Detailed statistics in JSON format
- `{job_name}_config.xml` - Job configurations (if --export-configs)
- `{job_name}_builds.json` - Build data (if --export-build-data)

## CSV Output Columns

### Multi-Job Mode (Default)
- Parameter_Value - The value of the parameter being analyzed
- Total_Builds - Total number of builds for this parameter value
- Successful_Builds - Number of successful builds
- Failed_Builds - Number of failed builds
- Unstable_Builds - Number of unstable builds
- Aborted_Builds - Number of aborted builds
- Success_Rate - Percentage of successful builds
- Failure_Rate - Percentage of failed builds
- Avg_Duration_Minutes - Average build duration in minutes
- Unique_Jobs - Number of unique jobs with this parameter value
- Job_List - Semicolon-separated list of job names

### Single Job Mode (`--single-job`)
- Parameter_Value - The value of the parameter being analyzed
- Total_Builds - Total number of builds for this parameter value
- Successful_Builds - Number of successful builds
- Failed_Builds - Number of failed builds
- Unstable_Builds - Number of unstable builds
- Aborted_Builds - Number of aborted builds
- Success_Rate - Percentage of successful builds
- Failure_Rate - Percentage of failed builds
- Avg_Duration_Minutes - Average build duration in minutes
- Unique_Jobs - Number of unique jobs (always 1 in single job mode)
- Build_Numbers - Comma-separated list of build numbers for this parameter value

## Use Cases

- **Impact Analysis** - Measure how changes to environments, branches, or versions affect build success rates
- **Performance Monitoring** - Track build duration trends across different parameter values
- **Quality Metrics** - Compare success rates between different deployment targets
- **Capacity Planning** - Understand resource usage patterns by analyzing build durations

## Authentication

The script reads credentials from a netrc-formatted file (default: `~/.netrc`). You can specify a custom netrc file using the `--netrc` parameter.

### Default ~/.netrc format:
```
machine jenkins.example.com
login your-username
password your-api-token
```

### Using custom netrc file:
```bash
# Create custom credentials file
cat > ~/jenkins-prod-creds << EOF
machine jenkins-prod.company.com
login prod-user
password prod-api-token
EOF

# Use custom file
./jenkins-export --netrc ~/jenkins-prod-creds http://jenkins-prod.company.com environment
```

This allows you to:
- Use different credentials for different Jenkins instances
- Keep credentials in secure locations
- Share credential files across teams
- Maintain separate dev/staging/prod credentials

## Rate Limiting

The script includes configurable delays between API calls to avoid overwhelming Jenkins. Use `--delay` to adjust the delay between requests (default: 0.1 seconds).

## Error Handling

- Graceful handling of missing jobs or builds
- Continues processing if individual jobs fail
- Detailed error reporting with --verbose flag
- Validates Jenkins connectivity before starting

## Statistical Significance

For meaningful statistics, aim for:
- At least 30+ builds per parameter value
- Multiple jobs using the same parameter value
- Recent build data (consider using --max-builds to limit to recent builds)

## Troubleshooting

### Common Issues

#### "Export failed: 'jobs'" Error
This error occurs when there's a mismatch between the URL type and the mode you're using.

**Solution Options:**

1. **For analyzing all jobs on a Jenkins server:**
   ```bash
   # Use Jenkins server root URL (no --single-job flag)
   jenkins-stats http://jenkins.example.com --parameter environment
   ```

2. **For analyzing a specific job:**
   ```bash
   # Use job URL with --single-job flag
   jenkins-stats --single-job http://jenkins.example.com/job/my-project --parameter environment
   ```

**Common Mistakes:**
- ❌ `jenkins-stats http://jenkins.example.com/job/my-project --parameter env` (job URL without --single-job)
- ❌ `jenkins-stats --single-job http://jenkins.example.com --parameter env` (server URL with --single-job)
- ✅ `jenkins-stats http://jenkins.example.com --parameter env` (server analysis)
- ✅ `jenkins-stats --single-job http://jenkins.example.com/job/my-project --parameter env` (single job analysis)

#### No Jobs Found
- **Check permissions:** Ensure your credentials have access to view jobs
- **Verify URL:** Make sure you can access the Jenkins web interface at the same URL
- **Check authentication:** Verify your `.netrc` file has correct credentials

#### Authentication Failures
- **Verify credentials:** Test your username/token by accessing Jenkins web interface
- **Check netrc format:** Ensure proper format in `~/.netrc`:
  ```
  machine jenkins.example.com
  login your-username
  password your-api-token
  ```
- **File permissions:** Ensure `.netrc` has correct permissions: `chmod 600 ~/.netrc`

#### No Parameter Data Found
- **Verify parameter name:** Check that builds actually use the parameter you're searching for
- **Case sensitivity:** Parameter names are case-sensitive
- **Use `--verbose`:** Shows detailed information about what's being processed

### Debug Commands

```bash
# Test basic connectivity
curl -u username:token http://jenkins.example.com/api/json

# Verbose output to see what's happening
jenkins-stats http://jenkins.example.com --parameter env --verbose

# Start with a small sample
jenkins-stats http://jenkins.example.com --parameter env --max-jobs 5 --max-builds 10

# Filter to specific jobs you know have the parameter
jenkins-export -f "deploy" http://jenkins.example.com environment
```

## Development

### Setup Development Environment
```bash
# Clone/navigate to project directory
cd jenkins-stats

# Install in development mode with dev dependencies
pip install -e ".[dev]"

# Or with pipx for isolated environment
pipx install -e . --include-deps
```

### Running Tests
```bash
# Run tests (when implemented)
pytest

# Run with coverage
pytest --cov=jenkins_stats

# Type checking
mypy jenkins_stats/

# Code formatting
black jenkins_stats/
```

### Project Structure
```
jenkins-stats/
├── jenkins_stats/          # Main package
│   ├── __init__.py         # Package initialization
│   ├── __main__.py         # Module entry point
│   ├── exporter.py         # Core functionality
│   └── cli.py              # Bash-style CLI wrapper
├── pyproject.toml          # Project configuration
├── requirements.txt        # Runtime dependencies
├── LICENSE                 # MIT License
├── README.md               # This file
└── .gitignore             # Git ignore patterns
```

### Building and Publishing
```bash
# Build the package
python -m build

# Install locally from built package
pip install dist/jenkins-stats-*.whl

# Upload to PyPI (maintainers only)
python -m twine upload dist/*
```
