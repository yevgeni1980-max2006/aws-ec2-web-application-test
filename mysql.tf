
# -----------------------------
#   Security group for RDS
# -----------------------------
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow ASG instances to connect to MySQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.asg_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

# -----------------------------
#     RDS MySQL INSTANCE
# -----------------------------
resource "aws_db_instance" "wordpress" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  publicly_accessible  = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  skip_final_snapshot   = true

  depends_on = [aws_nat_gateway.nat]
}
