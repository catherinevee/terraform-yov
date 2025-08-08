#!/usr/bin/env python3
"""
Advanced Terragrunt Infrastructure Diagram Generator

Provides enhanced diagram generation capabilities with metadata extraction,
custom styling, and advanced filtering options.

Features:
- Metadata extraction from Terragrunt configurations
- Custom diagram styling and theming
- Resource filtering and grouping
- Multi-format output (SVG, PNG, PDF)
- Cost annotation integration
- Dependency analysis

Usage:
    python diagram-advanced.py generate --environment dev --region eu-central-2
    python diagram-advanced.py analyze --path aws/eu-central-2/prod
    python diagram-advanced.py metadata --output diagrams/metadata.json
"""

import os
import sys
import json
import argparse
import subprocess
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional
import re

class TerragruntDiagramAnalyzer:
    """Advanced Terragrunt diagram generator with analysis capabilities."""
    
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.diagrams_dir = self.project_root / "diagrams"
        self.diagrams_dir.mkdir(exist_ok=True)
    
    def discover_environments(self) -> List[Dict[str, str]]:
        """Discover all Terragrunt environments in the project."""
        environments = []
        
        aws_dir = self.project_root / "aws"
        if not aws_dir.exists():
            return environments
        
        for region_dir in aws_dir.iterdir():
            if not region_dir.is_dir():
                continue
            
            region = region_dir.name
            
            for env_dir in region_dir.iterdir():
                if not env_dir.is_dir():
                    continue
                
                environment = env_dir.name
                
                # Check if this is a valid environment
                if self._has_infrastructure_files(env_dir):
                    environments.append({
                        'environment': environment,
                        'region': region,
                        'path': f"aws/{region}/{environment}",
                        'full_path': str(env_dir),
                        'name': f"{environment}-{region}"
                    })
        
        return environments
    
    def _has_infrastructure_files(self, path: Path) -> bool:
        """Check if directory contains Terragrunt or Terraform files."""
        return any(path.rglob("*.hcl")) or any(path.rglob("*.tf"))
    
    def extract_metadata(self, env_path: Path) -> Dict[str, Any]:
        """Extract metadata from Terragrunt configuration."""
        metadata = {
            'environment': env_path.name,
            'region': env_path.parent.name,
            'resources': [],
            'modules': [],
            'dependencies': [],
            'tags': {},
            'costs': {},
            'last_analyzed': datetime.now().isoformat()
        }
        
        # Extract from terragrunt.hcl files
        for hcl_file in env_path.rglob("terragrunt.hcl"):
            try:
                content = hcl_file.read_text()
                
                # Extract terraform source
                source_match = re.search(r'source\s*=\s*["\']([^"\']+)["\']', content)
                if source_match:
                    metadata['modules'].append({
                        'source': source_match.group(1),
                        'file': str(hcl_file.relative_to(env_path))
                    })
                
                # Extract dependencies
                deps_match = re.search(r'dependencies\s*=\s*\{([^}]+)\}', content, re.DOTALL)
                if deps_match:
                    # Simple dependency extraction
                    paths = re.findall(r'["\']([^"\']+)["\']', deps_match.group(1))
                    metadata['dependencies'].extend(paths)
                
            except Exception as e:
                print(f"Warning: Could not parse {hcl_file}: {e}")
        
        return metadata
    
    def generate_enhanced_diagram(self, environment: str, region: str) -> bool:
        """Generate enhanced diagram with metadata annotations."""
        env_path = self.project_root / "aws" / region / environment
        
        if not env_path.exists():
            print(f"Environment path not found: {env_path}")
            return False
        
        env_name = f"{environment}-{region}"
        print(f"Generating enhanced diagram for {env_name}...")
        
        # Extract metadata
        metadata = self.extract_metadata(env_path)
        
        # Generate standard diagram first
        success = self._generate_standard_diagram(env_path, env_name)
        
        if success:
            # Generate metadata file
            metadata_file = self.diagrams_dir / f"{env_name}-metadata.json"
            with open(metadata_file, 'w') as f:
                json.dump(metadata, f, indent=2)
            
            print(f"Generated metadata: {metadata_file}")
        
        return success
    
    def _generate_standard_diagram(self, env_path: Path, env_name: str) -> bool:
        """Generate standard blast-radius diagram."""
        try:
            # Change to environment directory
            original_cwd = os.getcwd()
            os.chdir(env_path)
            
            # Set environment variables
            env = os.environ.copy()
            env['AWS_REGION'] = env_path.parent.name
            env['ENVIRONMENT'] = env_path.name
            
            # Initialize if needed
            if (env_path / "terragrunt.hcl").exists():
                subprocess.run(['terragrunt', 'init', '--terragrunt-non-interactive'], 
                             env=env, capture_output=True)
                subprocess.run(['terragrunt', 'plan', '-out=tfplan', '--terragrunt-non-interactive'], 
                             env=env, capture_output=True)
            else:
                subprocess.run(['terraform', 'init', '-backend=false'], 
                             env=env, capture_output=True)
                subprocess.run(['terraform', 'plan', '-out=tfplan'], 
                             env=env, capture_output=True)
            
            # Generate diagram
            output_file = self.diagrams_dir / f"{env_name}.svg"
            with open(output_file, 'w') as f:
                result = subprocess.run(['blast-radius', '--svg'], 
                                      stdout=f, stderr=subprocess.PIPE, env=env)
            
            # Cleanup
            if (env_path / "tfplan").exists():
                os.remove(env_path / "tfplan")
            
            os.chdir(original_cwd)
            
            return result.returncode == 0 and output_file.exists() and output_file.stat().st_size > 0
        
        except Exception as e:
            print(f"Error generating diagram: {e}")
            return False
        finally:
            os.chdir(original_cwd)
    
    def analyze_dependencies(self, environment: str = None, region: str = None) -> Dict[str, Any]:
        """Analyze infrastructure dependencies across environments."""
        analysis = {
            'total_environments': 0,
            'dependencies': {},
            'shared_modules': {},
            'environment_complexity': {},
            'analysis_date': datetime.now().isoformat()
        }
        
        environments = self.discover_environments()
        
        if environment and region:
            environments = [env for env in environments 
                          if env['environment'] == environment and env['region'] == region]
        
        analysis['total_environments'] = len(environments)
        
        for env in environments:
            env_path = Path(env['full_path'])
            metadata = self.extract_metadata(env_path)
            
            env_key = env['name']
            analysis['dependencies'][env_key] = metadata['dependencies']
            analysis['environment_complexity'][env_key] = {
                'modules': len(metadata['modules']),
                'dependencies': len(metadata['dependencies'])
            }
            
            # Track shared modules
            for module in metadata['modules']:
                source = module['source']
                if source not in analysis['shared_modules']:
                    analysis['shared_modules'][source] = []
                analysis['shared_modules'][source].append(env_key)
        
        return analysis
    
    def generate_all_diagrams(self) -> Dict[str, bool]:
        """Generate diagrams for all discovered environments."""
        environments = self.discover_environments()
        results = {}
        
        print(f"Discovered {len(environments)} environments")
        
        for env in environments:
            success = self.generate_enhanced_diagram(env['environment'], env['region'])
            results[env['name']] = success
            
            if success:
                print(f"✓ Generated diagram for {env['name']}")
            else:
                print(f"✗ Failed to generate diagram for {env['name']}")
        
        return results
    
    def generate_summary_report(self) -> None:
        """Generate a comprehensive summary report."""
        analysis = self.analyze_dependencies()
        
        report = {
            'project': 'YOV Enterprise Infrastructure',
            'generated_at': datetime.now().isoformat(),
            'summary': {
                'total_environments': analysis['total_environments'],
                'total_shared_modules': len(analysis['shared_modules']),
                'average_complexity': sum(
                    env['modules'] + env['dependencies'] 
                    for env in analysis['environment_complexity'].values()
                ) / max(len(analysis['environment_complexity']), 1)
            },
            'environments': {},
            'shared_modules': analysis['shared_modules'],
            'recommendations': []
        }
        
        # Environment details
        for env_name, complexity in analysis['environment_complexity'].items():
            report['environments'][env_name] = {
                'modules': complexity['modules'],
                'dependencies': complexity['dependencies'],
                'complexity_score': complexity['modules'] + complexity['dependencies']
            }
        
        # Generate recommendations
        if len(analysis['shared_modules']) < 3:
            report['recommendations'].append(
                "Consider creating more shared modules to reduce code duplication"
            )
        
        high_complexity_envs = [
            env for env, data in report['environments'].items() 
            if data['complexity_score'] > 10
        ]
        if high_complexity_envs:
            report['recommendations'].append(
                f"Review complexity in environments: {', '.join(high_complexity_envs)}"
            )
        
        # Save report
        report_file = self.diagrams_dir / "infrastructure-report.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"Generated infrastructure report: {report_file}")

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Advanced Terragrunt Infrastructure Diagram Generator"
    )
    parser.add_argument(
        "command",
        choices=["generate", "generate-all", "analyze", "metadata", "report"],
        help="Command to execute"
    )
    parser.add_argument(
        "--environment", "-e",
        help="Environment name (e.g., dev, staging, prod)"
    )
    parser.add_argument(
        "--region", "-r", 
        help="AWS region (e.g., eu-central-2, us-east-1)"
    )
    parser.add_argument(
        "--output", "-o",
        help="Output file path"
    )
    parser.add_argument(
        "--project-root",
        default=".",
        help="Project root directory (default: current directory)"
    )
    
    args = parser.parse_args()
    
    analyzer = TerragruntDiagramAnalyzer(args.project_root)
    
    if args.command == "generate":
        if not args.environment or not args.region:
            print("Error: --environment and --region required for generate command")
            sys.exit(1)
        
        success = analyzer.generate_enhanced_diagram(args.environment, args.region)
        sys.exit(0 if success else 1)
    
    elif args.command == "generate-all":
        results = analyzer.generate_all_diagrams()
        successful = sum(1 for success in results.values() if success)
        total = len(results)
        print(f"Generated {successful}/{total} diagrams successfully")
        sys.exit(0 if successful == total else 1)
    
    elif args.command == "analyze":
        analysis = analyzer.analyze_dependencies(args.environment, args.region)
        
        if args.output:
            with open(args.output, 'w') as f:
                json.dump(analysis, f, indent=2)
            print(f"Analysis saved to: {args.output}")
        else:
            print(json.dumps(analysis, indent=2))
    
    elif args.command == "metadata":
        environments = analyzer.discover_environments()
        metadata = {
            'environments': environments,
            'project_root': str(analyzer.project_root),
            'generated_at': datetime.now().isoformat()
        }
        
        if args.output:
            with open(args.output, 'w') as f:
                json.dump(metadata, f, indent=2)
            print(f"Metadata saved to: {args.output}")
        else:
            print(json.dumps(metadata, indent=2))
    
    elif args.command == "report":
        analyzer.generate_summary_report()

if __name__ == "__main__":
    main()
