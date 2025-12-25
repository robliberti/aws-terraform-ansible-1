resource "aws_security_group" "private_sg" {
  name        = "${var.name_prefix}-private-sg"
  description = "Allow SSH only from the public instance SG"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SSH from public instance"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  ingress {
    description     = "Simpleapp from public instance (reverse proxy)"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  egress {
    description = "All outbound (goes to NAT via route table)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-private-sg" }
}

resource "aws_instance" "private" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = aws_key_pair.lab.key_name

  tags = { Name = "${var.name_prefix}-private-ec2" }
}

output "private_instance_private_ip" {
  value = aws_instance.private.private_ip
}
