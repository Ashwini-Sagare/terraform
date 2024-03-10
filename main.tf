provider "aws" {
  region = "us-east-1"
  access_key = var.access_key_id
  secret_key = var.secret_access_key
}

#ec2 creation
resource "aws_instance" "windows_instances" {
  count = var.count_value
  ami = var.ami_value
  instance_type = var.instance_type_value
  tags = {
    Name = "windowsec2-${count.index + 1}"
  }
}
output "instance_ids" {
  value = aws_instance.windows_instances[*].id
}


