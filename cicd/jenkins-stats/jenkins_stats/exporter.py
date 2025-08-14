#!/usr/bin/env python3
"""
Jenkins Job Exporter - Export Jenkins jobs and analyze by parameter values
Reads credentials from ~/.netrc file
"""

import argparse
import csv
import json
import netrc
import os
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Set
from urllib.parse import urljoin, urlparse

import requests
from requests.auth import HTTPBasicAuth


class JenkinsJobExporter:
    def __init__(self, jenkins_url: str, delay: float = 0.1, netrc_file: Optional[str] = None):
        self.jenkins_url = jenkins_url.rstrip('/')
        self.delay = delay
        self.netrc_file = netrc_file or os.path.expanduser('~/.netrc')
        self.session = requests.Session()
        self._validate_jenkins_url()
        self._setup_auth()

    def _validate_jenkins_url(self):
        """Validate that the Jenkins URL looks correct"""
        # Note: This validation runs before we know if --single-job is set,
        # so we show warnings that may not apply. The actual validation
        # happens in the respective methods.
        pass

    def _setup_auth(self):
        """Setup authentication from netrc file"""
        try:
            netrc_auth = netrc.netrc(file=self.netrc_file)
            parsed_url = urlparse(self.jenkins_url)
            host = parsed_url.hostname
            
            auth_info = netrc_auth.authenticators(host)
            if auth_info:
                username, _, password = auth_info
                self.session.auth = HTTPBasicAuth(username, password)
                print(f"Using credentials from {self.netrc_file} for {host}")
            else:
                print(f"No credentials found in {self.netrc_file} for {host}")
                
        except FileNotFoundError:
            print(f"Netrc file not found: {self.netrc_file}, proceeding without authentication")
        except Exception as e:
            print(f"Error reading {self.netrc_file}: {e}")

    def get_all_jobs(self, job_filter: Optional[str] = None, max_jobs: Optional[int] = None) -> List[Dict]:
        """Get list of all jobs, optionally filtered"""
        print("Fetching job list...")
        url = f"{self.jenkins_url}/api/json"
        params = {'tree': 'jobs[name,url,fullName]'}
        
        try:
            response = self.session.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            
            # Check if this is a Jenkins server root or a specific job/project
            if 'jobs' not in data:
                if 'name' in data and 'builds' in data:
                    # This looks like a single job URL, not Jenkins root
                    raise ValueError(
                        f"The URL appears to point to a specific Jenkins job, not the Jenkins server root.\n"
                        f"Expected: http://jenkins.example.com\n"
                        f"Got: {self.jenkins_url}\n"
                        f"Please use the Jenkins server root URL instead, or use --single-job mode."
                    )
                else:
                    # Unknown structure
                    available_keys = list(data.keys()) if isinstance(data, dict) else "non-dict response"
                    raise ValueError(
                        f"Unexpected API response structure. Expected 'jobs' key but got: {available_keys}\n"
                        f"Make sure you're using the Jenkins server root URL (e.g., http://jenkins.example.com)\n"
                        f"Response: {data}"
                    )
            
            jobs = data['jobs']
            
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"Failed to connect to Jenkins at {url}: {e}")
        except ValueError as e:
            raise e
        except Exception as e:
            raise RuntimeError(f"Failed to parse Jenkins API response: {e}")
        
        # Apply filter if specified
        if job_filter:
            jobs = [job for job in jobs if job_filter.lower() in job['name'].lower()]
            print(f"Filtered to {len(jobs)} jobs matching '{job_filter}'")
        
        # Limit number of jobs if specified
        if max_jobs and max_jobs > 0:
            jobs = jobs[:max_jobs]
            print(f"Limited to first {len(jobs)} jobs")
        
        print(f"Found {len(jobs)} jobs to process")
        return jobs

    def analyze_single_job(self, target_parameter: str, max_builds: int = 100) -> Dict:
        """Analyze a single job by its direct URL"""
        print(f"Analyzing single job: {self.jenkins_url}")
        
        # Validate that this looks like a job URL
        if '/job/' not in self.jenkins_url:
            raise ValueError(
                f"For single job analysis, the URL must contain '/job/'.\n"
                f"Example: http://jenkins.example.com/job/my-project\n"
                f"Got: {self.jenkins_url}"
            )
        
        # Extract job name from URL for display
        job_name = self.jenkins_url.split('/job/')[-1].split('/')[0]
        
        try:
            # Get job data directly
            url = f"{self.jenkins_url}/api/json"
            params = {
                'tree': f'name,builds[number,result,duration,timestamp,actions[parameters[name,value]]]{{0,{max_builds}}}'
            }
            response = self.session.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            
            if 'builds' not in data:
                raise ValueError(
                    f"No builds found for job at {self.jenkins_url}\n"
                    f"Make sure the URL points to a valid Jenkins job."
                )
            
            builds = data['builds']
            job_display_name = data.get('name', job_name)
            
            print(f"Found {len(builds)} builds for job '{job_display_name}'")
            print(f"Looking for parameter: '{target_parameter}'")
            
            # Process builds to extract parameter statistics
            param_stats = {}
            processed_builds = 0
            
            for build in builds:
                param_value = self.extract_parameter_value(build, target_parameter)
                if param_value is not None:
                    if param_value not in param_stats:
                        param_stats[param_value] = {
                            'total_builds': 0,
                            'successful_builds': 0,
                            'failed_builds': 0,
                            'unstable_builds': 0,
                            'aborted_builds': 0,
                            'total_duration': 0,
                            'build_numbers': [],
                            'jobs': {job_display_name}
                        }
                    
                    stats = param_stats[param_value]
                    stats['total_builds'] += 1
                    stats['build_numbers'].append(build.get('number', 'unknown'))
                    processed_builds += 1
                    
                    result = build.get('result', '').upper()
                    if result == 'SUCCESS':
                        stats['successful_builds'] += 1
                    elif result == 'FAILURE':
                        stats['failed_builds'] += 1
                    elif result == 'UNSTABLE':
                        stats['unstable_builds'] += 1
                    elif result == 'ABORTED':
                        stats['aborted_builds'] += 1
                    
                    duration = build.get('duration', 0)
                    if duration and duration > 0:
                        stats['total_duration'] += duration
            
            print(f"Processed {processed_builds} builds with parameter '{target_parameter}'")
            
            if not param_stats:
                print(f"⚠️  No builds found with parameter '{target_parameter}'")
                print(f"   Make sure the parameter name is correct and case-sensitive.")
                
                # Show available parameters from the first few builds
                print("\n   Available parameters in recent builds:")
                for i, build in enumerate(builds[:3]):
                    if i == 0:
                        print(f"     Build #{build.get('number', 'unknown')}:")
                    params = []
                    for action in build.get('actions', []):
                        if action and 'parameters' in action:
                            for param in action['parameters']:
                                if param.get('name') not in params:
                                    params.append(param.get('name'))
                    if params:
                        print(f"       {', '.join(params)}")
                        break
                    elif i == 2:
                        print("       No parameters found in recent builds")
            
            return param_stats
            
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"Failed to connect to Jenkins job at {self.jenkins_url}: {e}")
        except Exception as e:
            raise RuntimeError(f"Failed to analyze Jenkins job: {e}")

    def export_jobs_with_stats(self, 
                             output_dir: str, 
                             target_parameter: str,
                             max_jobs: Optional[int] = None,
                             max_builds: int = 100,
                             job_filter: Optional[str] = None,
                             export_configs: bool = False,
                             export_build_data: bool = False,
                             single_job: bool = False) -> Dict:
        """Export jobs and collect statistics grouped by parameter"""
        
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        if single_job:
            # Analyze single job mode
            aggregated_stats = self.analyze_single_job(target_parameter, max_builds)
            
            if export_build_data and aggregated_stats:
                # Export build data for single job
                job_name = self.jenkins_url.split('/job/')[-1].split('/')[0]
                builds_data = self.get_job_builds_direct(max_builds)
                builds_file = output_path / f"{job_name}_builds.json"
                builds_file.write_text(json.dumps(builds_data, indent=2), encoding='utf-8')
            
        else:
            # Multi-job analysis mode (original behavior)
            jobs = self.get_all_jobs(job_filter, max_jobs)
            
            if not jobs:
                print("No jobs found matching criteria")
                return {}
            
            aggregated_stats = {}
            processed_count = 0
            
            print(f"\nProcessing {len(jobs)} jobs...")
            print(f"Looking for parameter: '{target_parameter}'")
            print(f"Max builds per job: {max_builds}")
            
            for i, job in enumerate(jobs, 1):
                job_name = job['name']
                print(f"[{i:3d}/{len(jobs)}] Processing: {job_name}")
                
                # Add delay to be nice to Jenkins
                if self.delay > 0:
                    time.sleep(self.delay)
                
                try:
                    # Export job configuration if requested
                    if export_configs:
                        config_xml = self.get_job_config(job_name)
                        config_file = output_path / f"{job_name}_config.xml"
                        config_file.write_text(config_xml, encoding='utf-8')
                    
                    # Process job builds
                    job_stats = self.process_job(job_name, target_parameter, max_builds)
                    
                    # Export build data if requested
                    if export_build_data and job_stats:
                        builds_data = self.get_job_builds(job_name, max_builds)
                        builds_file = output_path / f"{job_name}_builds.json"
                        builds_file.write_text(json.dumps(builds_data, indent=2), encoding='utf-8')
                    
                    # Merge job stats into aggregated stats
                    for param_value, stats in job_stats.items():
                        if param_value not in aggregated_stats:
                            aggregated_stats[param_value] = {
                                'total_builds': 0,
                                'successful_builds': 0,
                                'failed_builds': 0,
                                'unstable_builds': 0,
                                'aborted_builds': 0,
                                'total_duration': 0,
                                'jobs': set()
                            }
                        
                        agg_stats = aggregated_stats[param_value]
                        agg_stats['total_builds'] += stats['total_builds']
                        agg_stats['successful_builds'] += stats['successful_builds']
                        agg_stats['failed_builds'] += stats['failed_builds']
                        agg_stats['unstable_builds'] += stats['unstable_builds']
                        agg_stats['aborted_builds'] += stats['aborted_builds']
                        agg_stats['total_duration'] += stats['total_duration']
                        agg_stats['jobs'].update(stats['jobs'])
                    
                    if job_stats:
                        processed_count += 1
                        
                except Exception as e:
                    print(f"    ERROR: {e}")
                    continue
            
            print(f"\nSuccessfully processed {processed_count}/{len(jobs)} jobs")
        
        if aggregated_stats:
            self.save_statistics(aggregated_stats, output_path, target_parameter)
            self.print_summary(aggregated_stats)
        else:
            print(f"No builds found with parameter '{target_parameter}'")
        
        return aggregated_stats

    def get_job_builds_direct(self, max_builds: int = 100) -> Dict:
        """Get job build history directly from job URL"""
        url = f"{self.jenkins_url}/api/json"
        params = {
            'tree': f'builds[number,result,duration,timestamp,actions[parameters[name,value]]]{{0,{max_builds}}}'
        }
        response = self.session.get(url, params=params)
        response.raise_for_status()
        return response.json()

    def get_job_config(self, job_name: str) -> str:
        """Get job configuration XML"""
        url = f"{self.jenkins_url}/job/{job_name}/config.xml"
        response = self.session.get(url)
        response.raise_for_status()
        return response.text

    def get_job_builds(self, job_name: str, max_builds: int = 100) -> Dict:
        """Get job build history with parameters"""
        url = f"{self.jenkins_url}/job/{job_name}/api/json"
        params = {
            'tree': f'builds[number,result,duration,timestamp,actions[parameters[name,value]]]{{0,{max_builds}}}'
        }
        response = self.session.get(url, params=params)
        response.raise_for_status()
        return response.json()

    def extract_parameter_value(self, build: Dict, parameter_name: str) -> Optional[str]:
        """Extract specific parameter value from build"""
        for action in build.get('actions', []):
            if action and 'parameters' in action:
                for param in action['parameters']:
                    if param.get('name') == parameter_name:
                        return str(param.get('value', ''))
        return None

    def process_job(self, job_name: str, target_parameter: str, max_builds: int) -> Dict:
        """Process a single job and return its statistics"""
        job_stats = {}
        
        try:
            builds_data = self.get_job_builds(job_name, max_builds)
            
            for build in builds_data.get('builds', []):
                param_value = self.extract_parameter_value(build, target_parameter)
                if param_value is not None:
                    if param_value not in job_stats:
                        job_stats[param_value] = {
                            'total_builds': 0,
                            'successful_builds': 0,
                            'failed_builds': 0,
                            'unstable_builds': 0,
                            'aborted_builds': 0,
                            'total_duration': 0,
                            'jobs': set()
                        }
                    
                    stats = job_stats[param_value]
                    stats['total_builds'] += 1
                    stats['jobs'].add(job_name)
                    
                    result = build.get('result', '').upper()
                    if result == 'SUCCESS':
                        stats['successful_builds'] += 1
                    elif result == 'FAILURE':
                        stats['failed_builds'] += 1
                    elif result == 'UNSTABLE':
                        stats['unstable_builds'] += 1
                    elif result == 'ABORTED':
                        stats['aborted_builds'] += 1
                    
                    duration = build.get('duration', 0)
                    if duration and duration > 0:
                        stats['total_duration'] += duration
                        
        except Exception as e:
            print(f"Error processing job {job_name}: {e}")
            
        return job_stats



    def save_statistics(self, job_stats: Dict, output_path: Path, parameter_name: str):
        """Save statistical analysis to files"""
        
        # Prepare data for serialization
        stats_for_json = {}
        for param_value, stats in job_stats.items():
            stats_copy = stats.copy()
            
            # Handle both multi-job and single-job formats
            if 'jobs' in stats and isinstance(stats['jobs'], set):
                stats_copy['jobs'] = list(stats['jobs'])
            elif 'jobs' in stats:
                stats_copy['jobs'] = list(stats['jobs']) if isinstance(stats['jobs'], (list, set)) else [str(stats['jobs'])]
            else:
                stats_copy['jobs'] = []
            
            # Add build numbers if available (single job mode)
            if 'build_numbers' in stats:
                stats_copy['build_numbers'] = stats['build_numbers']
            
            stats_copy['success_rate'] = (stats['successful_builds'] / stats['total_builds'] 
                                        if stats['total_builds'] > 0 else 0)
            stats_copy['failure_rate'] = (stats['failed_builds'] / stats['total_builds'] 
                                        if stats['total_builds'] > 0 else 0)
            stats_copy['avg_duration_ms'] = (stats['total_duration'] / stats['total_builds'] 
                                           if stats['total_builds'] > 0 else 0)
            stats_copy['avg_duration_min'] = stats_copy['avg_duration_ms'] / (1000 * 60)
            stats_for_json[param_value] = stats_copy
        
        # Save JSON
        json_file = output_path / f"statistics_by_{parameter_name}.json"
        json_file.write_text(json.dumps(stats_for_json, indent=2), encoding='utf-8')
        
        # Save CSV
        csv_file = output_path / f"statistics_by_{parameter_name}.csv"
        with csv_file.open('w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            
            # Determine if we have build numbers (single job mode)
            has_build_numbers = any('build_numbers' in stats for stats in stats_for_json.values())
            
            if has_build_numbers:
                writer.writerow([
                    'Parameter_Value', 'Total_Builds', 'Successful_Builds', 'Failed_Builds',
                    'Unstable_Builds', 'Aborted_Builds', 'Success_Rate', 'Failure_Rate',
                    'Avg_Duration_Minutes', 'Unique_Jobs', 'Build_Numbers'
                ])
            else:
                writer.writerow([
                    'Parameter_Value', 'Total_Builds', 'Successful_Builds', 'Failed_Builds',
                    'Unstable_Builds', 'Aborted_Builds', 'Success_Rate', 'Failure_Rate',
                    'Avg_Duration_Minutes', 'Unique_Jobs', 'Job_List'
                ])
            
            # Sort by total builds descending
            sorted_stats = sorted(stats_for_json.items(), 
                                key=lambda x: x[1]['total_builds'], 
                                reverse=True)
            
            for param_value, stats in sorted_stats:
                if has_build_numbers:
                    # Single job mode - show build numbers
                    build_numbers = ', '.join(map(str, stats.get('build_numbers', [])))
                    writer.writerow([
                        param_value,
                        stats['total_builds'],
                        stats['successful_builds'],
                        stats['failed_builds'],
                        stats['unstable_builds'],
                        stats['aborted_builds'],
                        f"{stats['success_rate']:.2%}",
                        f"{stats['failure_rate']:.2%}",
                        f"{stats['avg_duration_min']:.2f}",
                        len(stats['jobs']),
                        build_numbers
                    ])
                else:
                    # Multi-job mode - show job list
                    writer.writerow([
                        param_value,
                        stats['total_builds'],
                        stats['successful_builds'],
                        stats['failed_builds'],
                        stats['unstable_builds'],
                        stats['aborted_builds'],
                        f"{stats['success_rate']:.2%}",
                        f"{stats['failure_rate']:.2%}",
                        f"{stats['avg_duration_min']:.2f}",
                        len(stats['jobs']),
                        '; '.join(sorted(stats['jobs']))
                    ])
        
        print(f"\nStatistics saved to:")
        print(f"  JSON: {json_file}")
        print(f"  CSV:  {csv_file}")

    def print_summary(self, job_stats: Dict):
        """Print summary statistics"""
        print(f"\n{'='*80}")
        print("SUMMARY STATISTICS")
        print(f"{'='*80}")
        
        total_param_values = len(job_stats)
        total_builds = sum(stats['total_builds'] for stats in job_stats.values())
        total_jobs = len(set().union(*(stats['jobs'] for stats in job_stats.values())))
        
        print(f"Parameter values found: {total_param_values}")
        print(f"Total builds analyzed: {total_builds}")
        print(f"Unique jobs analyzed: {total_jobs}")
        
        print(f"\n{'Parameter Value':<20} {'Builds':<8} {'Success%':<9} {'Avg Min':<8} {'Jobs':<5}")
        print("-" * 60)
        
        # Sort by total builds descending
        sorted_stats = sorted(job_stats.items(), 
                            key=lambda x: x[1]['total_builds'], 
                            reverse=True)
        
        for param_value, stats in sorted_stats:
            success_rate = (stats['successful_builds'] / stats['total_builds'] 
                          if stats['total_builds'] > 0 else 0)
            avg_duration_min = (stats['total_duration'] / stats['total_builds'] / (1000 * 60)
                              if stats['total_builds'] > 0 else 0)
            
            print(f"{param_value:<20} {stats['total_builds']:<8} "
                  f"{success_rate:<8.1%} {avg_duration_min:<8.1f} {len(stats['jobs']):<5}")


def main():
    """Main entry point for the command-line interface."""
    parser = argparse.ArgumentParser(
        description="Export Jenkins jobs and analyze build statistics by parameter values",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Export 100 jobs, analyze by 'environment' parameter
  %(prog)s http://jenkins.example.com -p environment -n 100

  # Analyze a specific job by parameter
  %(prog)s --single-job http://jenkins.example.com/job/my-project -p environment

  # Analyze nested job
  %(prog)s --single-job http://jenkins.example.com/job/folder/job/project -p branch

  # Filter jobs by name pattern and export configs
  %(prog)s http://jenkins.example.com -p branch -f "deploy" --export-configs

  # Analyze all jobs with verbose output
  %(prog)s http://jenkins.example.com -p version -v --max-builds 200

Authentication:
  Add your Jenkins credentials to ~/.netrc:
  machine jenkins.example.com
  login your-username
  password your-api-token
        """)
    
    parser.add_argument('jenkins_url', 
                       help='Jenkins server URL (e.g., http://jenkins.example.com)')
    
    parser.add_argument('-p', '--parameter', 
                       required=True,
                       help='Parameter name to group builds by (e.g., environment, branch)')
    
    parser.add_argument('-n', '--max-jobs', 
                       type=int, 
                       help='Maximum number of jobs to process (default: all jobs) - ignored in --single-job mode')
    
    parser.add_argument('-b', '--max-builds', 
                       type=int, 
                       default=100,
                       help='Maximum number of builds per job to analyze (default: 100)')
    
    parser.add_argument('-f', '--filter', 
                       help='Filter jobs by name (case-insensitive substring match) - ignored in --single-job mode')
    
    parser.add_argument('-o', '--output', 
                       default='jenkins_export',
                       help='Output directory (default: jenkins_export)')
    
    parser.add_argument('--export-configs', 
                       action='store_true',
                       help='Export job configuration XML files')
    
    parser.add_argument('--export-build-data', 
                       action='store_true',
                       help='Export detailed build data JSON files')
    
    parser.add_argument('--delay', 
                       type=float, 
                       default=0.1,
                       help='Delay between API calls in seconds (default: 0.1)')
    
    parser.add_argument('--netrc', 
                       help='Path to netrc file for authentication (default: ~/.netrc)')
    
    parser.add_argument('--single-job', 
                       action='store_true',
                       help='Analyze a single job instead of all jobs on server (URL must point to specific job)')
    
    parser.add_argument('-v', '--verbose', 
                       action='store_true',
                       help='Verbose output')
    
    args = parser.parse_args()
    
    if args.verbose:
        print(f"Jenkins URL: {args.jenkins_url}")
        print(f"Target parameter: {args.parameter}")
        print(f"Max jobs: {args.max_jobs or 'unlimited'}")
        print(f"Max builds per job: {args.max_builds}")
        print(f"Job filter: {args.filter or 'none'}")
        print(f"Output directory: {args.output}")
        print(f"Netrc file: {args.netrc or '~/.netrc'}")
        print(f"API delay: {args.delay}s")
        print()
    
    try:
        exporter = JenkinsJobExporter(args.jenkins_url, args.delay, args.netrc)
        
        stats = exporter.export_jobs_with_stats(
            output_dir=args.output,
            target_parameter=args.parameter,
            max_jobs=args.max_jobs,
            max_builds=args.max_builds,
            job_filter=args.filter,
            export_configs=args.export_configs,
            export_build_data=args.export_build_data,
            single_job=args.single_job
        )
        
        if stats:
            print(f"\n✅ Export completed successfully!")
            print(f"Results saved in: {args.output}/")
        else:
            print(f"\n❌ No data found for parameter '{args.parameter}'")
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n❌ Export interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Export failed: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
