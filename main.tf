provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAZ7AO4L7E4JWATXVT"
  secret_key = "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"
}

resource "aws_vpc" "pico_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "dev"
  }
}

resource "aws_internet_gateway" "pico-gw" {
  vpc_id    = aws_vpc.pico_vpc.id
  

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.pico_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "private"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.pico_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "public"
  }
}

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.pico_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pico-gw.id
  }

  tags = {
    Name = "private"
  }
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.pico_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pico-gw.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private-route-table.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public-route-table.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.pico_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "pico-web-server" {
  subnet_id       = aws_subnet.private_subnet.id
  private_ips     = ["10.0.1.40"]
  security_groups = [aws_security_group.allow_web.id]

#   attachment {
#     instance     = aws_instance.pico-bastion-server-instance
#     device_index = 0
#   }
 }

resource "aws_eip" "pico" {
  vpc                       = true
  network_interface         = aws_network_interface.pico-web-server.id
  associate_with_private_ip = "10.0.1.40"
  depends_on                = [aws_internet_gateway.pico-gw]
}

resource "aws_instance" "pico-bastion-server-instance" {
  ami               = "ami-042e8287309f5df03"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "pico-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.pico-web-server.id
  }

  tags = {
    Name = "pico_bastion_server"
  }
}
