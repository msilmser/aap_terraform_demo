#!/usr/bin/env python3

"""
AAP API Client
This script provides authentication and job management for Ansible Automation Platform
"""

import requests
import json
import sys
import time
import argparse
from urllib3.exceptions import InsecureRequestWarning

# Disable SSL warnings for self-signed certificates
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

class AAPClient:
    def __init__(self, host, username, password, verify_ssl=False):
        self.host = host
        self.username = username
        self.password = password
        self.verify_ssl = verify_ssl
        self.base_url = f"https://{host}/api/v2"
        self.token = None
        self.session = requests.Session()
        
    def authenticate(self):
        """Authenticate and get API token"""
        auth_url = f"{self.base_url}/tokens/"
        auth_data = {
            "description": "API Token for automation",
            "scope": "write"
        }
        
        response = self.session.post(
            auth_url,
            json=auth_data,
            auth=(self.username, self.password),
            verify=self.verify_ssl
        )
        
        if response.status_code == 201:
            self.token = response.json()["token"]
            self.session.headers.update({
                "Authorization": f"Bearer {self.token}"
            })
            print(f"Successfully authenticated with AAP")
            return True
        else:
            print(f"Authentication failed: {response.status_code} - {response.text}")
            return False
    
    def get_job_templates(self):
        """Get list of job templates"""
        url = f"{self.base_url}/job_templates/"
        response = self.session.get(url, verify=self.verify_ssl)
        
        if response.status_code == 200:
            return response.json()["results"]
        else:
            print(f"Failed to get job templates: {response.status_code}")
            return []
    
    def launch_job_template(self, template_id, extra_vars=None):
        """Launch a job template"""
        url = f"{self.base_url}/job_templates/{template_id}/launch/"
        
        launch_data = {}
        if extra_vars:
            launch_data["extra_vars"] = extra_vars
        
        response = self.session.post(
            url,
            json=launch_data,
            verify=self.verify_ssl
        )
        
        if response.status_code == 201:
            job_id = response.json()["job"]
            print(f"Job launched successfully. Job ID: {job_id}")
            return job_id
        else:
            print(f"Failed to launch job: {response.status_code} - {response.text}")
            return None
    
    def get_job_status(self, job_id):
        """Get job status"""
        url = f"{self.base_url}/jobs/{job_id}/"
        response = self.session.get(url, verify=self.verify_ssl)
        
        if response.status_code == 200:
            return response.json()
        else:
            print(f"Failed to get job status: {response.status_code}")
            return None
    
    def wait_for_job_completion(self, job_id, timeout=300):
        """Wait for job to complete"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            job_status = self.get_job_status(job_id)
            if job_status:
                status = job_status["status"]
                print(f"Job {job_id} status: {status}")
                
                if status in ["successful", "failed", "error", "canceled"]:
                    return job_status
                    
            time.sleep(10)
        
        print(f"Job {job_id} timed out after {timeout} seconds")
        return None
    
    def get_job_output(self, job_id):
        """Get job output"""
        url = f"{self.base_url}/jobs/{job_id}/stdout/"
        response = self.session.get(url, verify=self.verify_ssl)
        
        if response.status_code == 200:
            return response.text
        else:
            print(f"Failed to get job output: {response.status_code}")
            return None

def main():
    parser = argparse.ArgumentParser(description="AAP API Client")
    parser.add_argument("--host", default="192.168.100.10", help="AAP Controller host")
    parser.add_argument("--username", default="admin", help="Username")
    parser.add_argument("--password", default="admin123", help="Password")
    parser.add_argument("--action", choices=["list", "launch", "status", "output"], 
                       required=True, help="Action to perform")
    parser.add_argument("--template-id", type=int, help="Job template ID")
    parser.add_argument("--job-id", type=int, help="Job ID")
    parser.add_argument("--extra-vars", help="Extra variables as JSON string")
    parser.add_argument("--wait", action="store_true", help="Wait for job completion")
    
    args = parser.parse_args()
    
    # Create client and authenticate
    client = AAPClient(args.host, args.username, args.password)
    if not client.authenticate():
        sys.exit(1)
    
    # Perform requested action
    if args.action == "list":
        templates = client.get_job_templates()
        print("\nAvailable Job Templates:")
        print("-" * 50)
        for template in templates:
            print(f"ID: {template['id']} - Name: {template['name']}")
            print(f"   Description: {template['description']}")
            print(f"   Project: {template['project']}")
            print()
    
    elif args.action == "launch":
        if not args.template_id:
            print("Template ID is required for launch action")
            sys.exit(1)
        
        extra_vars = None
        if args.extra_vars:
            try:
                extra_vars = json.loads(args.extra_vars)
            except json.JSONDecodeError:
                print("Invalid JSON in extra-vars")
                sys.exit(1)
        
        job_id = client.launch_job_template(args.template_id, extra_vars)
        
        if job_id and args.wait:
            result = client.wait_for_job_completion(job_id)
            if result:
                print(f"\nJob completed with status: {result['status']}")
                if result['status'] == 'successful':
                    print("Job executed successfully!")
                else:
                    print("Job failed or was canceled")
    
    elif args.action == "status":
        if not args.job_id:
            print("Job ID is required for status action")
            sys.exit(1)
        
        status = client.get_job_status(args.job_id)
        if status:
            print(f"Job Status: {status['status']}")
            print(f"Started: {status['started']}")
            print(f"Finished: {status['finished']}")
    
    elif args.action == "output":
        if not args.job_id:
            print("Job ID is required for output action")
            sys.exit(1)
        
        output = client.get_job_output(args.job_id)
        if output:
            print(output)

if __name__ == "__main__":
    main()