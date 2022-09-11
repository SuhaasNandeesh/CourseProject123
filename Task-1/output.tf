output "vpc-id" {
  value = aws_vpc.cp-vpc.id
}

output "igw" {
  value = aws_internet_gateway.cp-igw.id
}

output "subnet-public" {
  value = aws_subnet.public.*.id
}

output "route-table" {
  value = aws_route_table.cp-route-table.id
}

output "route-table-association" {
  value = ["${aws_route_table_association.public.*.id}"]
  #value = values(aws_route_table_association.a)[*].id
}

output "subnet-private" {
  value = aws_subnet.private.*.id
  #value = values(aws_subnet.private)[*].id
}

output "sg-id-web" {
  value = aws_security_group.allow_web.id
}

output "sg-bastian" {
  value = aws_security_group.bastion.id
}

output "sg-private" {
  value = aws_security_group.private.id
}

output "sg-public" {
  value = aws_security_group.public.vpc_id
}

output "nat" {
  value = ["${aws_nat_gateway.cp-ngw.*.id}"]
}

output "bastian-ip" {
  value = ["${aws_instance.bastion.*.public_ip}"]
}

output "Jenkins-ip" {
  value = ["${aws_instance.Jenkins.*.private_ip}"]
}

output "app-ip" {
  value = ["${aws_instance.app.*.private_ip}"]
}






