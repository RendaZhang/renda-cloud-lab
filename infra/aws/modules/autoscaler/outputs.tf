output "release_name" {
  value = try(helm_release.this[0].name, null)
}
