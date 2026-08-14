# -----------------------------
#      EC2 KEY PAIR
# -----------------------------
resource "aws_key_pair" "ubuntu" {
  key_name   = "ubuntu"
  public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
}

# -----------------------------
#      EC2 LAUNCH TEMPLATE
# -----------------------------
resource "aws_launch_template" "asg_lt" {

  depends_on = [
    aws_key_pair.ubuntu
  ]

  name_prefix   = "asg-lt-"
  image_id      = "ami-0345dd2cef523536e"
  instance_type = "t3.medium"
  key_name      = aws_key_pair.ubuntu.key_name

  vpc_security_group_ids = [
    aws_security_group.asg_sg.id
  ]

  user_data = base64encode(<<-EOF
#!/bin/bash

set -e

# -----------------------------
# SYSTEM PACKAGES
# -----------------------------
apt-get update -y

apt-get install -y \
  apache2 \
  php \
  php-mysql \
  php-curl \
  php-gd \
  php-mbstring \
  php-xml \
  php-zip \
  php-intl \
  wget \
  unzip \
  curl \
  nfs-common

systemctl enable apache2
systemctl start apache2


# -----------------------------
# WORDPRESS
# -----------------------------
cd /var/www/html

rm -rf /var/www/html/*

wget -q https://wordpress.org/latest.zip

unzip -q latest.zip

cp -r wordpress/* .

rm -rf wordpress latest.zip


# -----------------------------
# EFS
# -----------------------------
mkdir -p /var/www/html/wp-content

until mount -t nfs4 \
  -o nfsvers=4.1,_netdev \
  ${aws_efs_file_system.wordpress.dns_name}:/ \
  /var/www/html/wp-content
do
  echo "Waiting for EFS..."
  sleep 5
done

# Prevent duplicate fstab entries
grep -q "${aws_efs_file_system.wordpress.dns_name}" /etc/fstab || \
echo "${aws_efs_file_system.wordpress.dns_name}:/ /var/www/html/wp-content nfs4 defaults,_netdev,nofail 0 0" >> /etc/fstab


# -----------------------------
# WORDPRESS HEALTH CHECK
# -----------------------------
cat > /var/www/html/health.html <<'HEALTH'
OK
HEALTH


# -----------------------------
# WORDPRESS CONFIG
# -----------------------------
cat > /var/www/html/wp-config.php <<EOC
<?php

define('DB_NAME', '${var.db_name}');
define('DB_USER', '${var.db_username}');
define('DB_PASSWORD', '${var.db_password}');
define('DB_HOST', '${aws_db_instance.wordpress.address}');

define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

$table_prefix = 'wp_';

define('WP_DEBUG', false);

define('FS_METHOD', 'direct');

if (!defined('ABSPATH')) {
    define('ABSPATH', dirname(__FILE__) . '/');
}

require_once ABSPATH . 'wp-settings.php';

EOC


# -----------------------------
# PERMISSIONS
# -----------------------------
chown -R www-data:www-data /var/www/html

find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

chmod 640 /var/www/html/wp-config.php


# -----------------------------
# APACHE
# -----------------------------
a2enmod rewrite

systemctl restart apache2

echo "WordPress installation completed"
EOF
  )

  # -----------------------------
  # ROOT DISK
  # -----------------------------
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  # -----------------------------
  # INSTANCE TAG
  # -----------------------------
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "asg-instance"
    }
  }
}


# -----------------------------
#       EC2 AUTOSCALING
# -----------------------------
resource "aws_autoscaling_group" "asg" {

  depends_on = [
    aws_launch_template.asg_lt
  ]

  name = "app-asg"

  min_size         = 1
  desired_capacity = 2
  max_size         = 5

  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.asg_lt.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "asg-instance"
    propagate_at_launch = true
  }
}


# -----------------------------
# SCALE UP
# -----------------------------
resource "aws_autoscaling_policy" "scale_up" {

  name = "scale-up"

  autoscaling_group_name = aws_autoscaling_group.asg.name

  adjustment_type   = "ChangeInCapacity"
  scaling_adjustment = 1

  cooldown = 300
}


# -----------------------------
# SCALE DOWN
# -----------------------------
resource "aws_autoscaling_policy" "scale_down" {

  name = "scale-down"

  autoscaling_group_name = aws_autoscaling_group.asg.name

  adjustment_type   = "ChangeInCapacity"
  scaling_adjustment = -1

  cooldown = 300
}


# -----------------------------
# CPU HIGH
# -----------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_high" {

  alarm_name = "cpu-high"

  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2

  metric_name = "CPUUtilization"

  namespace = "AWS/EC2"

  period = 60

  statistic = "Average"

  threshold = 70

  alarm_actions = [
    aws_autoscaling_policy.scale_up.arn
  ]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}


# -----------------------------
# CPU LOW
# -----------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_low" {

  alarm_name = "cpu-low"

  comparison_operator = "LessThanThreshold"

  evaluation_periods = 2

  metric_name = "CPUUtilization"

  namespace = "AWS/EC2"

  period = 60

  statistic = "Average"

  threshold = 20

  alarm_actions = [
    aws_autoscaling_policy.scale_down.arn
  ]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}
