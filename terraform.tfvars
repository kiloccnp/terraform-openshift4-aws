cluster_name = "kilo-ocp"
base_domain = "on-stag.one"
openshift_pull_secret = "./openshift_pull_secret.json"
openshift_version = "4.6.28"

aws_extra_tags = {
  "owner" = "admin"
  }
aws_region = "us-east-1"
aws_publish_strategy = "External"
