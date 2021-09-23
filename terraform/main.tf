provider "hcp" {}

data "hcp_packer_image_iteration" "loki" {
  bucket_name  = var.hcp_bucket_loki
  channel = var.hcp_channel
}

data "hcp_packer_image_iteration" "hashicups" {
  bucket_name  = var.hcp_bucket_hashicups
  channel = var.hcp_channel
}

// data "hcp_packer_image" "loki_east" {
//   bucket_name     = data.hcp_packer_iteration.loki.id
//   region          = "us-east-2"
// }

// data "hcp_packer_image" "hashicups_east" {
//   bucket_name    = var.hcp_bucket_hashicups
//   cloud_provider = "aws"
//   iteration      = var.hcp_bucket_loki
//   cloud_provider = "aws"
//   iteration_id   = data.hcp_packer_iteration.hashicups.id
//   region         = "us-east-2"
// }

locals {
  # AMI for Loki and HashiCups image
  loki_images          = flatten(flatten(data.hcp_packer_image_iteration.loki.builds[*].images[*]))
  image_loki_us_east_2 = [for x in local.loki_images: x if x.region == "us-east-2"][0]

  hashicups_images          = flatten(flatten(data.hcp_packer_image_iteration.hashicups.builds[*].images[*]))
  image_hashicups_us_east_2 = [for x in local.hashicups_images: x if x.region == "us-east-2"][0]
  image_hashicups_us_west_2 = [for x in local.hashicups_images: x if x.region == "us-west-2"][0]
}

provider "aws" {
  region = var.region_east
}

provider "aws" {
  alias  = "west"
  region = var.region_west
}

resource "aws_instance" "loki" {
  ami           = local.image_loki_us_east_2.image_id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_public_east.id
  vpc_security_group_ids = [
    aws_security_group.ssh_east.id,
    aws_security_group.allow_egress_east.id,
    aws_security_group.loki_grafana_east.id,
  ]
  associate_public_ip_address = true

  tags = {
    Name = "Learn-Packer-LokiGrafana"
  }
}


resource "aws_instance" "hashicups_east" {
  ami           = local.image_hashicups_us_east_2.image_id
  // ami           = data.hcp_packer_image.hashicups_east.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_public_east.id
  vpc_security_group_ids = [
    aws_security_group.ssh_east.id,
    aws_security_group.allow_egress_east.id,
    aws_security_group.promtail_east.id,
    aws_security_group.hashicups_east.id,
  ]
  associate_public_ip_address = true

  tags = {
    Name = "Learn-Packer-HashiCups"
  }

  depends_on = [
    aws_instance.loki
  ]
}

resource "aws_instance" "hashicups_west" {
  provider      = aws.west
  ami           = local.image_hashicups_us_west_2.image_id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_public_west.id
  vpc_security_group_ids = [
    aws_security_group.ssh_west.id,
    aws_security_group.allow_egress_west.id,
    aws_security_group.promtail_west.id,
    aws_security_group.hashicups_west.id,
  ]
  associate_public_ip_address = true

  tags = {
    Name = "Learn-Packer-HashiCups"
  }

  depends_on = [
    aws_instance.loki
  ]
}
