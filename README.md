<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/117a4ad9-d0a1-4c0c-aa4b-6345045a2232" />


## AWS | Web Autoscaling
Architecture with public and private subnets, an Application Load Balancer (ALB), EC2 instances, and private resources. It demonstrates how users interact with the system, and how scaling and secure resource access are managed.



🎯 Architecture Overview
```
✅ VPC containing Public and Private Subnets
✅ Internet Gateway for outbound internet access
✅ NAT Gateway in the public subnet for private subnet egress
✅ Auto Scaling Group (ASG) using a Launch Template
✅ EC2 instances in the ASG, scaling in/out automatically
✅ Users hitting the system via the public internet
✅ Private resources (like RDS, caches) in the private subnets
```


🧱 Features
```
✔ Fully automated provisioning with Terraform
✔ High availability using multiple subnets in different Availability Zones
✔ Secure connectivity between Application and RDS
✔ Configurable environment variables for database credentials
✔ Easy to extend for other JSON data source
```



🚀 Deployment Options
```
terraform init
terraform validate
terraform plan -var-file="template.tfvars"
terraform apply -var-file="template.tfvars" -auto-approve
```

