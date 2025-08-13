"""Jenkins Job Statistics Exporter

A tool for exporting Jenkins jobs and analyzing build statistics grouped by parameter values.
"""

__version__ = "1.0.0"
__author__ = "Jenkins Stats Team"
__email__ = "jenkins-stats@example.com"

from .exporter import JenkinsJobExporter

__all__ = ["JenkinsJobExporter"]
