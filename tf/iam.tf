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
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:winebarrel/digger-example:*"]
    }
  }
}

resource "aws_iam_role" "digger" {
  name               = "digger-gha"
  assume_role_policy = data.aws_iam_policy_document.digger_assume_role.json
}

data "aws_iam_policy_document" "digger" {
  # state と tfplan の読み書き。use_lockfile のロックも同じバケットを使う。
  statement {
    sid    = "State"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.digger.arn}/*"]
  }

  statement {
    sid       = "ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.digger.arn]
  }

  # digger の PR ロック。backendless では DynamoDB に記録される。
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

  # tf/ 自身を digger に管理させるため、この構成が触るリソースへの権限を渡す。
  # 実運用では扱うリソースに合わせて絞る。
  statement {
    sid    = "ManageSelf"
    effect = "Allow"

    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:GetOpenIDConnectProvider",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:PutRolePolicy",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "s3:GetBucket*",
      "s3:GetLifecycleConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:PutBucket*",
      "s3:PutLifecycleConfiguration",
      "s3:PutEncryptionConfiguration",
    ]

    resources = [
      aws_iam_role.digger.arn,
      aws_iam_openid_connect_provider.github.arn,
      aws_s3_bucket.digger.arn,
    ]
  }
}

resource "aws_iam_role_policy" "digger" {
  name   = "digger-gha"
  role   = aws_iam_role.digger.id
  policy = data.aws_iam_policy_document.digger.json
}
