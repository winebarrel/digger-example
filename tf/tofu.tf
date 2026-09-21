terraform {
  required_version = "~> 1.12"

  # 初回は下の backend ブロックをコメントアウトしてローカルの state で apply し、
  # バケットができてから戻して `tofu init -migrate-state` で移す。
  #
  # state と tfplan は同じバケットに置く。state は tf/terraform.tfstate に、
  # tfplan は digger が <owner>-<repo>-<PR番号>-<プロジェクト名>.tfplan という
  # 名前でルート直下に書く。
  backend "s3" {
    bucket = "winebarrel-digger-example"
    key    = "tf/terraform.tfstate"
    region = "ap-northeast-1"

    # DynamoDB を使わない S3 ネイティブのロック
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

data "aws_caller_identity" "current" {}
