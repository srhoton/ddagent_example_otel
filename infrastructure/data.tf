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
