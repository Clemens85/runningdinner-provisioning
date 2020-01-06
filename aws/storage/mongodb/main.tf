# Configure the MongoDB Atlas Provider
provider "mongodbatlas" {
  public_key = var.public_key
  private_key  = var.private_key
}

terraform {
  backend "s3" {
    bucket = "runyourdinner-terraform-backend"
    key = "storage/mongodb/state.tfstate"
    region = "eu-central-1"
  }
}

resource "mongodbatlas_project" "runyourdinner" {
  name   = "runyourdinner"
  org_id = var.organization
}

// Must be created manually (due to M0 cannot be used for infrastructure as code)
data "mongodbatlas_cluster" "runyourdinner-cluster" {
  project_id = "${mongodbatlas_project.runyourdinner.id}"
  name       = "runyourdinner"
}

data "http" "myip" {
  url = "https://api.ipify.org/"
}
resource "mongodbatlas_project_ip_whitelist" "test" {
  project_id = "${mongodbatlas_project.runyourdinner.id}"
  whitelist {
    cidr_block = "172.31.48.0/24"
    comment    = "Subnet of EC2 Instance"
  }
  whitelist {
    ip_address = "${chomp(data.http.myip.body)}"
    comment    = "My IP"
  }
}

resource "mongodbatlas_database_user" "app-user" {
  username      = "runyourdinner"
  password      = var.password
  project_id    = "${mongodbatlas_project.runyourdinner.id}"
  database_name = "admin"
  roles {
    role_name     = "dbAdmin"
    database_name = "${data.mongodbatlas_cluster.runyourdinner-cluster.name}"
  }
}
