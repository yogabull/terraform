# Terraform Exercise

# Configure the AWS Provider
provider "aws" {
  profile = "dev"
  region  = "us-east-2"
}

# 1. Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
      Name = "production"
  }
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
      Name = "production"
  }
}

# 3. Create Custom Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# 4. Create Subnet
resource "aws_subnet" "prod-subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
  Name = "Prod-subnet"
  }
  }

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.prod-subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6. Create Securty Group to allow port 22, 80, 443
resource "aws_security_group" "allow-web" {
  name        = "allow-web-traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}


# 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.prod-subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow-web.id]
}

# 8. Assign an elastic IP to the network interface created in step 7
#    Relys on IG being made first.
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw] # note we are referencing the whole GW and do not need the id
}

# Use to output details from terrafrom state show [attribute]
output "server_public_ip" {
  value = aws_eip.one.public_ip
}
output "server_id"{
  value = aws_instance.web-server-instance[0].public_ip
}

# 9. Create Ubuntu server and install/enable apache2
resource "aws_instance" "web-server-instance" {
    count = 1
    ami = "ami-0fb653ca2d3203ac1"
    instance_type = "t2.micro"
    availability_zone = "us-east-2a"
    key_name = "demoKP"
    
    tags = {
        Name = "VPC mirror exercise"
    }
        
    } 
