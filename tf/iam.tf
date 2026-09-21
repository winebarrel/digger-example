data "aws_iam_policy_document" "digger_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # このリポジトリからのワークフローだけに限定する。
    #
    # 2026-07-15 以降に作られたリポジトリは sub が immutable subject claim
    # 形式になり、オーナーとリポジトリの数値 ID が埋め込まれる。
    # repo:<owner>/<repo>:* では一致しない。
    # 値は gh api repos/<owner>/<repo>/actions/oidc/customization/sub で確認できる。
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:winebarrel@117768/digger-example@1378927815:*"]
    }
  }
}

resource "aws_iam_role" "digger" {
  name               = "digger-gha"
  assume_role_policy = data.aws_iam_policy_document.digger_assume_role.json
}

data "aws_iam_policy_document" "digger" {
  # state、そのロックファイル、tfplan の読み書き。全て同じバケットに置く。
  # digger に許す書き込みはここだけ。
  statement {
    sid    = "StateObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.digger.arn}/*"]
  }

  statement {
    sid       = "StateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.digger.arn]
  }

  # digger の PR ロック。pr_locks を使う以上ここは書き込みが要る。
  # テーブルは初回実行時に digger が自分で作る。
  statement {
    sid    = "PrLockCreate"
    effect = "Allow"

    actions = [
      "dynamodb:List*",
      "dynamodb:DescribeLimits",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PrLock"
    effect = "Allow"

    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DescribeTable",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]

    resources = ["arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/DiggerDynamoDBLockTable"]
  }

  # plan に必要な読み取り。apply は人間がやるので書き込みは渡さない。
  # この構成が管理しているリソースだけに絞る。
  statement {
    sid    = "ReadIam"
    effect = "Allow"

    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRoleTags",
      "iam:GetOpenIDConnectProvider",
    ]

    resources = [
      aws_iam_role.digger.arn,
      aws_iam_openid_connect_provider.github.arn,
    ]
  }

  statement {
    sid    = "ReadBucketConfig"
    effect = "Allow"

    actions = [
      "s3:GetAccelerateConfiguration",
      "s3:GetBucket*",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
    ]

    resources = [aws_s3_bucket.digger.arn]
  }
}

resource "aws_iam_role_policy" "digger" {
  name   = "digger-gha"
  role   = aws_iam_role.digger.id
  policy = data.aws_iam_policy_document.digger.json
}
