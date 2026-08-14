# -----------------------------
# EFS for wp-content
# -----------------------------
resource "aws_efs_file_system" "wordpress" {
  #depends_on = [aws_launch_template.asg_lt]
  creation_token   = "wordpress-efs"
  performance_mode = "generalPurpose"
  encrypted        = true

  tags = {
    Name = "wordpress-efs"
  }
}

resource "aws_efs_mount_target" "wordpress" {
  for_each = { for idx, subnet in aws_subnet.public : idx => subnet }
  file_system_id = aws_efs_file_system.wordpress.id
  subnet_id      = each.value.id
  security_groups = [aws_security_group.asg_sg.id]

  depends_on = [
    aws_efs_file_system.wordpress
  ]
}
