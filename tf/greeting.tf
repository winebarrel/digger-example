# terraform_data は provider のいらない組み込みリソース。
# null_resource の置き換えとして OpenTofu が用意しているもの。
# input を書き換えると plan に差分が出る。
resource "terraform_data" "greeting" {
  input = "hello digger"
}

output "greeting" {
  value = terraform_data.greeting.output
}
