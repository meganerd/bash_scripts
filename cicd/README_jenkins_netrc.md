# Jenkins Builds Fetcher - .netrc Authentication

Bash script to fetch all builds for Jenkins jobs via the API with secure `.netrc` authentication support.

## Features

* **Secure Authentication** - Uses `.netrc` files (no credentials in command line)  
* **Nested Job Support** - Handle jobs in folders/subfolders  
* **Full URL Only** - Simplified to accept only complete Jenkins job URLs
* **Custom .netrc Files** - Use specific .netrc files or default ~/.netrc  
* **Formatted Output** - Total count + one build per line with console URLs  

## Quick Start

### 1. Set up Authentication

Create a `.netrc` file with your Jenkins credentials:

```bash
# Create .netrc file
cat > ~/.netrc << 'EOF'
machine jenkins.example.com
login your-username
password your-api-token
EOF

# Set proper permissions (important!)
chmod 600 ~/.netrc
```

### 2. Run the Script

```bash
# Simple job
./jenkins_builds.sh "https://jenkins.example.com/job/job-name"

# Nested job
./jenkins_builds.sh "https://jenkins.example.com/job/folder/job/subfolder/job/jobname"

# With custom .netrc file
./jenkins_builds.sh "https://jenkins.example.com/job/folder/job/jobname" "/path/to/custom.netrc"
```

## Usage Examples

### Basic Usage
```bash
# Simple job with default ~/.netrc
./jenkins_builds.sh "https://jenkins.example.com/job/my-job"

# Nested job in folders
./jenkins_builds.sh "https://jenkins.example.com/job/team-folder/job/project-folder/job/build-job"
```

### Custom .netrc File
```bash
# Use custom .netrc file
./jenkins_builds.sh "https://jenkins.example.com/job/folder/job/jobname" "/path/to/custom.netrc"
```

### Public Jenkins (No Authentication)
```bash
# Public Jenkins instances (like ci.jenkins.io)
./jenkins_builds.sh "https://ci.jenkins.io/job/some-public-job"
```

## .netrc File Format

The `.netrc` file should contain entries for each Jenkins instance:

```
machine jenkins.example.com
login your-username
password your-api-token

machine ci.company.com  
login another-username
password another-api-token
```

### Important Notes:
- **machine**: Use the hostname only (without `https://` or paths)
- **login**: Your Jenkins username
- **password**: Use API token (not your login password)
- **permissions**: File must be `chmod 600` (read/write for owner only)

## Getting Jenkins API Token

1. Log into Jenkins
2. Go to **Your Profile** → **Configure**
3. Scroll to **API Token** section
4. Click **Add new Token**
5. Give it a name and click **Generate**
6. Copy the token and use it in your `.netrc` file

## Output Format

```
Jenkins Base URL: https://jenkins.example.com
Job Path: folder/jobname
Using default ~/.netrc for authentication (if it exists)

Total number of builds: 25

Build List:
--------------------------------------------------------
Build #  | Display Name | Result | Duration | Console URL
---------|--------------|--------|----------|-------------
123      | Build #123   | SUCCESS| 2m 45s   | https://jenkins.example.com/job/folder/job/jobname/123/console
122      | Build #122   | FAILURE| 1m 30s   | https://jenkins.example.com/job/folder/job/jobname/122/console
121      | Build #121   | SUCCESS| 3m 12s   | https://jenkins.example.com/job/folder/job/jobname/121/console
...

Execution completed in 2 seconds
```

## Jenkins URL Structure

### Understanding Jenkins URLs

**Simple Job:**
- Browser URL: `https://jenkins.example.com/job/jobname/`
- API URL: `https://jenkins.example.com/job/jobname/api/json`

**Nested Job (in folders):**
- Browser URL: `https://jenkins.example.com/job/folder/job/subfolder/job/jobname/`
- API URL: `https://jenkins.example.com/job/folder/job/subfolder/job/jobname/api/json`

### Input Format

The script now only accepts complete Jenkins job URLs:

- **Full Job URL**: `https://jenkins.example.com/job/folder/job/jobname`

The script will automatically extract the Jenkins base URL and job path from the provided URL.

## Authentication Methods

### 1. Default ~/.netrc (Recommended)
```bash
./jenkins_builds.sh "https://jenkins.example.com/job/jobname"
```

### 2. Custom .netrc File
```bash
./jenkins_builds.sh "https://jenkins.example.com/job/jobname" "/path/to/project.netrc"
```

### 3. No Authentication (Public Jenkins)
```bash
./jenkins_builds.sh "https://ci.jenkins.io/job/public-job"
```

## Multiple Jenkins Instances

You can manage multiple Jenkins instances in a single `.netrc` file:

```
# Production Jenkins
machine jenkins.prod.company.com
login prod-user
password prod-api-token

# Staging Jenkins  
machine jenkins.staging.company.com
login staging-user
password staging-api-token

# Development Jenkins
machine jenkins.dev.company.com
login dev-user
password dev-api-token
```

## Troubleshooting

### Common Issues

**1. Authentication Errors**
```
Error: Invalid response from Jenkins API
Response: {"error": "Unauthorized"}
```
**Solutions:**
- Check your `.netrc` file exists and has correct permissions (`chmod 600`)
- Verify the machine name matches the Jenkins hostname exactly
- Ensure you're using an API token, not your login password
- Test API token manually: `curl -n https://jenkins.example.com/api/json`

**2. Job Not Found**
```
Error: Invalid response from Jenkins API
Response: {"error": "Not Found"}
```
**Solutions:**
- Verify the job name/path is correct
- Check if the job exists and you have permissions to access it
- For nested jobs, ensure the folder structure is correct

**3. Permission Issues**
```
curl: (77) error setting certificate verify locations
```
**Solutions:**
- Check `.netrc` file permissions: `ls -la ~/.netrc` should show `-rw-------`
- Fix permissions: `chmod 600 ~/.netrc`

**4. Invalid URL Format**
```
Error: Please provide a full Jenkins job URL containing '/job/'
```
**Solutions:**
- Ensure the URL contains `/job/` for job URLs
- Check the URL format matches Jenkins conventions
- Provide the complete Jenkins job URL (e.g., `https://jenkins.example.com/job/jobname`)

### Debug Mode

To see what curl command is being executed:

```bash
# Add -v to see verbose curl output
# Edit the script temporarily to add -v to the curl command
curl_cmd="curl -s -n -v"
```

### Manual Testing

Test your `.netrc` setup manually:

```bash
# Test authentication
curl -n "https://jenkins.example.com/api/json"

# Test specific job API
curl -n "https://jenkins.example.com/job/jobname/api/json"
```

## Security Best Practices

1. **File Permissions**: Always set `.netrc` to `600` permissions
2. **API Tokens**: Use API tokens instead of passwords
3. **Token Scope**: Create job-specific tokens when possible
4. **File Location**: Keep `.netrc` files in secure locations
5. **Token Rotation**: Regularly rotate API tokens

## Requirements

- **bash** - Bash shell (version 4.0+)
- **curl** - For API requests with .netrc support
- **jq** - For JSON parsing

### Install Requirements

```bash
# Ubuntu/Debian
sudo apt-get install curl jq

# macOS (with Homebrew)  
brew install curl jq

# RHEL/CentOS
sudo yum install curl jq
```

## Examples Directory

See the included `example.netrc` file for a complete example of .netrc format.

## Related Tools

- **Jenkins CLI**: Official Jenkins command-line interface
- **jenkins-api**: Python library for Jenkins API
- **curl**: Direct API calls with .netrc authentication
