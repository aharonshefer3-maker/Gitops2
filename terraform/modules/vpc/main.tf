resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = { Name = "vpc-${var.env_name}" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       =var.availability_zone
  tags = { Name = "pub-sub-${var.env_name}" }
}
# resource "aws_s3_bucket" "k3s_storage" {
#   bucket = "quakewatch-storage-${var.env_name}-${random_id.bucket_suffix.hex}"
#
#   # מונע מחיקה בטעות של הדלי אם יש בו נתונים
#   force_destroy = false
#
#   tags = {
#     Name        = "QuakeWatch Storage"
#     Environment = var.env_name
#   }
# }
#
# # סיומת רנדומלית לשם הדלי (כי שמות S3 חייבים להיות יוניקיים בעולם)
# resource "random_id" "bucket_suffix" {
#   byte_length = 4
# }
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}
#//
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}
