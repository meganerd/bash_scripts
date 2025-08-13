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

## Usage Examples

### Basic Usage
```bash
# Analyze 'environment' parameter for all jobs
jenkins-export http://jenkins.example.com environment

# Analyze first 100 jobs by 'branch' parameter  
jenkins-stats http://jenkins.example.com --parameter branch --max-jobs 100
```

### Advanced Usage
```bash
# Filter jobs and export configs
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
