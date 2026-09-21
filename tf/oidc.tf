# GitHub Actions から AssumeRoleWithWebIdentity するための OIDC プロバイダ。
# GitHub は AWS が自前の信頼済み CA で検証するため thumbprint_list は不要。
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
