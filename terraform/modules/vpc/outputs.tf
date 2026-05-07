output "vpc_id" {
  value = aws_vpc.main.id # וודא שזה השם של ה-resource בתוך המודול
}

output "public_subnet_id" {
  value = aws_subnet.public.id # וודא שזה השם של ה-resource בתוך המודול
}