data "aws_vpc" "dev-env-default_vpc" {
  tags = {
    Name = "dev-env-default_vpc"
  }
}

data "aws_subnet" "private-1-subnet" {
  vpc_id = data.aws_vpc.dev-env-default_vpc.id
  tags = {
    Name = "private-1"
  }
}

data "aws_subnet" "private-2-subnet" {
  vpc_id = data.aws_vpc.dev-env-default_vpc.id
  tags = {
    Name = "private-2"
  }
}

data "aws_subnet" "private-3-subnet" {
  vpc_id = data.aws_vpc.dev-env-default_vpc.id
  tags = {
    Name = "private-3"
  }
}

data "aws_subnet" "public-1-subnet" {
  vpc_id = data.aws_vpc.dev-env-default_vpc.id
  tags = {
    Name = "public-1"
  }
}

data "aws_subnet" "public-2-subnet" {
  vpc_id = data.aws_vpc.dev-env-default_vpc.id
  tags = {
    Name = "public-2"
  }
}

data "aws_subnet" "public-3-subnet" {
  vpc_id = data.aws_vpc.dev-env-default_vpc.id
  tags = {
    Name = "public-3"
  }
}
data "aws_ssm_parameter" "ddagent-example-key-id" {
  name = "/ddagent/key-id"
}

data "aws_ssm_parameter" "ddagent-example-key-value" {
  name = "/ddagent/key-value"
}
