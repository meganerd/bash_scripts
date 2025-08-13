"""Tests for Jenkins Stats package."""

import pytest
from unittest.mock import Mock, patch
from jenkins_stats.exporter import JenkinsJobExporter


def test_jenkins_job_exporter_init():
    """Test JenkinsJobExporter initialization."""
    exporter = JenkinsJobExporter("http://jenkins.example.com", delay=0.5)
    assert exporter.jenkins_url == "http://jenkins.example.com"
    assert exporter.delay == 0.5
    assert exporter.netrc_file.endswith("/.netrc")


def test_jenkins_job_exporter_init_with_custom_netrc():
    """Test JenkinsJobExporter initialization with custom netrc file."""
    exporter = JenkinsJobExporter(
        "http://jenkins.example.com", 
        netrc_file="/custom/netrc"
    )
    assert exporter.netrc_file == "/custom/netrc"


def test_extract_parameter_value():
    """Test parameter value extraction from build data."""
    exporter = JenkinsJobExporter("http://jenkins.example.com")
    
    build = {
        "actions": [
            {
                "parameters": [
                    {"name": "environment", "value": "production"},
                    {"name": "branch", "value": "main"}
                ]
            }
        ]
    }
    
    assert exporter.extract_parameter_value(build, "environment") == "production"
    assert exporter.extract_parameter_value(build, "branch") == "main"
    assert exporter.extract_parameter_value(build, "nonexistent") is None


def test_extract_parameter_value_no_actions():
    """Test parameter extraction with no actions."""
    exporter = JenkinsJobExporter("http://jenkins.example.com")
    
    build = {"actions": []}
    assert exporter.extract_parameter_value(build, "environment") is None


def test_extract_parameter_value_no_parameters():
    """Test parameter extraction with no parameters in actions."""
    exporter = JenkinsJobExporter("http://jenkins.example.com")
    
    build = {"actions": [{"someOtherData": "value"}]}
    assert exporter.extract_parameter_value(build, "environment") is None


@patch('jenkins_stats.exporter.netrc.netrc')
def test_setup_auth_with_credentials(mock_netrc):
    """Test authentication setup with valid credentials."""
    mock_auth = Mock()
    mock_auth.authenticators.return_value = ("user", None, "token")
    mock_netrc.return_value = mock_auth
    
    with patch('builtins.print') as mock_print:
        exporter = JenkinsJobExporter("http://jenkins.example.com")
        
    mock_print.assert_called_with("Using credentials from ~/.netrc for jenkins.example.com")


@patch('jenkins_stats.exporter.netrc.netrc')
def test_setup_auth_no_credentials(mock_netrc):
    """Test authentication setup with no credentials found."""
    mock_auth = Mock()
    mock_auth.authenticators.return_value = None
    mock_netrc.return_value = mock_auth
    
    with patch('builtins.print') as mock_print:
        exporter = JenkinsJobExporter("http://jenkins.example.com")
        
    mock_print.assert_called_with("No credentials found in ~/.netrc for jenkins.example.com")


@patch('jenkins_stats.exporter.netrc.netrc')
def test_setup_auth_file_not_found(mock_netrc):
    """Test authentication setup when netrc file not found."""
    mock_netrc.side_effect = FileNotFoundError()
    
    with patch('builtins.print') as mock_print:
        exporter = JenkinsJobExporter("http://jenkins.example.com")
        
    mock_print.assert_called_with("Netrc file not found: ~/.netrc, proceeding without authentication")


def test_url_normalization():
    """Test that URLs are properly normalized."""
    exporter = JenkinsJobExporter("http://jenkins.example.com/")
    assert exporter.jenkins_url == "http://jenkins.example.com"
    
    exporter = JenkinsJobExporter("http://jenkins.example.com")
    assert exporter.jenkins_url == "http://jenkins.example.com"


if __name__ == "__main__":
    pytest.main([__file__])
