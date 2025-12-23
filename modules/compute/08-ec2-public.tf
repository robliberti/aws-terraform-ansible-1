# Generate an SSH keypair locally and register the public key with AWS
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "lab" {
  key_name   = "${var.name_prefix}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_file" "private_key_pem" {
  filename        = "${path.root}/${var.name_prefix}.pem"
  content         = tls_private_key.ssh.private_key_pem
  file_permission = "0400"
}

# Find a current Amazon Linux AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "public_sg" {
  name        = "${var.name_prefix}-public-sg"
  description = "Allow SSH from my IP"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "HTTP from my IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-public-sg" }
}

resource "aws_instance" "public" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = true

  tags = { Name = "${var.name_prefix}-public-ec2" }
}

output "public_instance_public_ip" {
  value = aws_instance.public.public_ip
}

output "public_instance_private_ip" {
  value = aws_instance.public.private_ip
}

output "ssh_private_key_file" {
  value = local_file.private_key_pem.filename
}
