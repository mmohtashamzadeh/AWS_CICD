terraform {
  backend "s3" {
    bucket         = "mehdi1361bucket-euc1"
    key            = "eks/dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "mehdi1361_lock_table"
    encrypt        = true
  }
}

