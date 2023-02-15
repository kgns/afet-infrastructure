resource "aws_ecs_cluster" "cluster" {
  name = "afet"

  tags = {
    Name = "afet"
  }
}
