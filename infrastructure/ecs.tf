resource "aws_ecs_cluster" "ddagent-example" {
    name = "ddagent-example"
}

resource "aws_ecs_cluster_capacity_providers" "ddagent-example" {
    cluster_name = aws_ecs_cluster.ddagent-example.name
    capacity_providers = ["FARGATE"]
    default_capacity_provider_strategy {
        capacity_provider = "FARGATE"
        weight = 1
    }
}

resource "aws_iam_role" "ddagent-example" {
    name = "ddagent-example"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
  
}
EOF
}

resource "aws_iam_policy" "ddagent-example" {
    name = "ddagent-example"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:BatchGetImage",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        }, 
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameters"
            ],
            "Resource": [
                "${data.aws_ssm_parameter.ddagent-example-key-id.arn}",
                "${data.aws_ssm_parameter.ddagent-example-key-value.arn}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "S3:GetObject",
                "S3:ListBucket",
                "S3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::b2c-tfstate/*",
                "arn:aws:s3:::b2c-tfstate"
            ]
        },
        {
          "Effect": "Allow",
          "Action": [
              "logs:CreateLogStream",
              "logs:CreateLogGroup",
              "logs:PutLogEvents",
              "logs:DescribeLogStreams"
          ],
          "Resource": [
              "arn:aws:logs:*:*:*"
          ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ddagent-example" {
    role = aws_iam_role.ddagent-example.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ddagent-example-perms" {
    role = aws_iam_role.ddagent-example.name
    policy_arn = aws_iam_policy.ddagent-example.arn
  
}
resource "aws_ecs_task_definition" "ddagent-example" {
    family = "ddagent-example"
    network_mode = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu = "512"
    memory = "1024"
    execution_role_arn = aws_iam_role.ddagent-example.arn
    task_role_arn = aws_iam_role.ddagent-example.arn
    volume {
        name = "log"
    }
    container_definitions = <<EOF
[
    {
        "essential": true,
        "image": "amazon/aws-for-fluent-bit:init-latest",
        "name": "log_router",
        "firelensConfiguration": {
            "type": "fluentbit",
            "options": { "enable-ecs-log-metadata": "true" }
        },
        "mountPoints": [
            {
                "containerPath": "/logs/",
                "sourceVolume": "log"
            }
        ],
        "environment": [
            {
              "name": "aws_fluent_bit_init_s3_1",
              "value": "arn:aws:s3:::b2c-tfstate/logging-config/datadog.config"
            },
            {
              "name": "aws_fluent_bit_init_s3_2",
              "value": "arn:aws:s3:::b2c-tfstate/logging-config/cloudwatch.config"
            }
        ],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "firelens-container",
                "awslogs-region": "us-east-1",
                "awslogs-create-group": "true",
                "awslogs-stream-prefix": "firelens-init"
                }
            }
    },
    {
        "name": "ddagent-example",
        "image": "public.ecr.aws/datadog/agent:latest",
        "cpu": 256,
        "memory": 512,
        "essential": true,
        "environment": [
            {
                "name": "ECS_FARGATE",
                "value": "true"
            },
            {
                "name": "DD_LOGS_ENABLED",
                "value": "true"
            },
            {
                "name": "DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL",
                "value": "true"
            }, 
            {
                "name": "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_GRPC_ENDPOINT",
                "value": "http://0.0.0.0:4317"
            },
            {
                "name": "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT",
                "value": "http://0.0.0.0:4318"

            },
            {
                "name": "DD_OTLP_CONFIG_LOGS_ENABLED",
                "value": "true"
            },
            {
                "name": "DD_PROCESS_CONFIG_PROCESS_COLLECTION_ENABLED",
                "value": "true"
            }

        ],
        "secrets": [
            {
                "name": "DD_API_KEY",
                "valueFrom": "${data.aws_ssm_parameter.ddagent-example-key-value.arn}"
            }
        ],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "ddagent-container",
                "awslogs-region": "us-east-1",
                "awslogs-create-group": "true",
                "awslogs-stream-prefix": "firelens-init"
            }
        }
    },
    {
        "name": "dotnet-example",
        "image": "705740530616.dkr.ecr.us-east-1.amazonaws.com/ddagent-example:latest",
        "cpu": 256,
        "memory": 512,
        "essential": true,
        "portMappings": [
          {
            "containerPort": 8080,
            "hostPort": 8080
          }
        ],
        "logConfiguration": {
            "logDriver": "awsfirelens"
        }
    }
]
EOF
}

resource "aws_lb" "ddagent-example" {
    name = "ddagent-example"
    internal = false
    load_balancer_type = "network"
    security_groups = [aws_security_group.ddagent-example.id]
    subnets = [data.aws_subnet.public-1-subnet.id, data.aws_subnet.public-2-subnet.id, data.aws_subnet.public-3-subnet.id]
    tags = {
        Name = "ddagent-example"
    }
}

resource "aws_lb_target_group" "ddagent-example" {
    name = "ddagent-example"
    port = 8080
    protocol = "TCP"
    target_type = "ip"
    vpc_id = data.aws_vpc.dev-env-default_vpc.id
}

resource "aws_lb_listener" "ddagent-example" {
    load_balancer_arn = aws_lb.ddagent-example.arn
    port = 80
    protocol = "TCP"

    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.ddagent-example.arn
    }
}

resource "aws_security_group" "ddagent-example" {
    name = "ddagent-example"
    vpc_id = data.aws_vpc.dev-env-default_vpc.id
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_ecs_service" "ddagent-example" {
    name = "ddagent-example"
    cluster = aws_ecs_cluster.ddagent-example.id
    task_definition = aws_ecs_task_definition.ddagent-example.arn
    desired_count = 1
    launch_type = "FARGATE"
    network_configuration {
      assign_public_ip = true
        subnets = [data.aws_subnet.public-1-subnet.id, data.aws_subnet.public-2-subnet.id, data.aws_subnet.public-3-subnet.id]
        security_groups = [aws_security_group.ddagent-example.id]
    }
    load_balancer {
        target_group_arn = aws_lb_target_group.ddagent-example.arn
        container_name = "dotnet-example"
        container_port = 8080
    }
}
