#!/usr/bin/env python3
"""
Generate infrastructure diagram from Terraform configuration
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import Lambda
from diagrams.aws.integration import StepFunctions
from diagrams.aws.storage import S3
from diagrams.aws.database import Dynamodb, AuroraInstance
from diagrams.aws.network import APIGateway, CloudFront
from diagrams.aws.security import Cognito, IAM, KMS
from diagrams.aws.management import Cloudwatch, CloudwatchEventEventBased
from diagrams.aws.integration import Eventbridge, SNS

# Configuration
graph_attr = {
    "fontsize": "45",
    "bgcolor": "white",
    "layout": "dot",
    "concentrate": "true",
    "rankdir": "TB",
    "splines": "ortho",
    "nodesep": "1.0",
    "ranksep": "2.0",
    "dpi": "150"
}

node_attr = {
    "fontsize": "14",
    "fontname": "Arial",
    "shape": "box",
    "style": "rounded,filled",
    "fillcolor": "lightblue"
}

edge_attr = {
    "fontsize": "12",
    "fontname": "Arial"
}

with Diagram("Serverless REST API Platform",
             filename="infrastructure_diagram",
             show=False,
             direction="TB",
             graph_attr=graph_attr,
             node_attr=node_attr,
             edge_attr=edge_attr):

    # External users
    with Cluster("Users"):
        users = [
            APIGateway("API Clients"),
            Cognito("Authenticated Users")
        ]

    # CDN Layer
    with Cluster("Content Delivery"):
        cdn = CloudFront("CloudFront CDN")

    # API Layer
    with Cluster("API Gateway", graph_attr={"bgcolor": "lightcyan"}):
        api_gateway = APIGateway("REST API")
        api_keys = IAM("API Keys & Usage Plans")

    # Compute Layer
    with Cluster("Serverless Compute", graph_attr={"bgcolor": "lightyellow"}):
        with Cluster("Lambda Functions"):
            lambdas = [
                Lambda("Validate Function"),
                Lambda("Process Function"),
                Lambda("Transform Function"),
                Lambda("Aggregate Function")
            ]

        orchestrator = StepFunctions("Step Functions\nOrchestrator")

    # Database Layer
    with Cluster("Data Storage", graph_attr={"bgcolor": "lightgreen"}):
        with Cluster("DynamoDB"):
            dynamodb_tables = [
                Dynamodb("Tenants Table"),
                Dynamodb("API Data Table"),
                Dynamodb("Analytics Table")
            ]

        aurora = AuroraInstance("Aurora Serverless v2\n(Reporting)")

    # Storage Layer
    with Cluster("Object Storage"):
        s3_buckets = [
            S3("Documents Bucket"),
            S3("Uploads Bucket"),
            S3("Logs Bucket")
        ]

    # Security Layer
    with Cluster("Security & Auth", graph_attr={"bgcolor": "lavender"}):
        cognito_pool = Cognito("User Pool")
        kms = KMS("Encryption Keys")
        iam_roles = IAM("Lambda Roles")

    # Monitoring Layer
    with Cluster("Monitoring & Events", graph_attr={"bgcolor": "mistyrose"}):
        cloudwatch = Cloudwatch("CloudWatch\nDashboards & Alarms")
        eventbridge = CloudwatchEventEventBased("EventBridge")
        sns = SNS("Alert Topics")
        xray = Cloudwatch("X-Ray Tracing")

    # Connections
    users[0] >> Edge(label="HTTPS", style="bold") >> cdn
    users[1] >> Edge(label="Auth Token", color="blue") >> cognito_pool

    cdn >> Edge(label="API Requests", style="bold") >> api_gateway
    api_gateway >> Edge(label="Authorize") >> api_keys
    api_gateway >> Edge(label="Invoke", color="orange") >> lambdas
    api_gateway >> Edge(label="Orchestrate", color="purple") >> orchestrator

    cognito_pool >> Edge(style="dashed") >> api_gateway

    orchestrator >> Edge(label="Execute", style="dashed") >> lambdas

    for lambda_func in lambdas:
        lambda_func >> Edge(label="Read/Write", color="green") >> dynamodb_tables[0]
        lambda_func >> Edge(label="Query", color="darkgreen") >> aurora
        lambda_func >> Edge(label="Store", color="blue") >> s3_buckets[0]
        lambda_func >> Edge(style="dashed") >> cloudwatch

    s3_buckets >> Edge(label="Events", color="red") >> eventbridge
    eventbridge >> Edge(label="Trigger") >> lambdas[0]

    cloudwatch >> Edge(label="Alerts", color="red") >> sns

    kms >> Edge(label="Encrypt", style="dashed", color="gray") >> dynamodb_tables
    kms >> Edge(label="Encrypt", style="dashed", color="gray") >> s3_buckets
    kms >> Edge(label="Encrypt", style="dashed", color="gray") >> aurora

    iam_roles >> Edge(style="dashed", color="gray") >> lambdas

print("Infrastructure diagram generated: infrastructure_diagram.png")