resource "null_resource" "openshift_installer" {
  provisioner "local-exec" {
      command = "wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.6.28/openshift-install-linux-4.6.28.tar.gz"

  }

  provisioner "local-exec" {
    command = "tar zxvf ./openshift-install-linux-4.6.28.tar.gz -C ./"
  }

  provisioner "local-exec" {

    command = "rm -f ./openshift-install-linux-4.6.28.tar.gz .//robots*.txt* .//README.md"
  }
}

resource "null_resource" "openshift_client" {


  provisioner "local-exec" {

    command = "wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.6.28/openshift-client-linux-4.6.28.tar.gz"
  }

  provisioner "local-exec" {
    command = "rm -f ./openshift-client-linux-4.6.28.tar.gz .//robots*.txt* .//README.md"
  }
}

resource "null_resource" "generate_manifests" {
  triggers = {
    install_config =  data.template_file.install_config_yaml.rendered
  }

  depends_on = [
    local_file.install_config,
    # null_resource.aws_credentials,
    null_resource.openshift_installer,
  ]

  provisioner "local-exec" {
    command = "rm -rf .//temp"
  }

  provisioner "local-exec" {
    command = "mkdir -p .//temp"
  }

  provisioner "local-exec" {
    command = "mv .//install-config.yaml .//temp"
  }

  provisioner "local-exec" {
    command = ".//openshift-install --dir=.//temp create manifests"
  }
}

# because we're providing our own control plane machines, remove it from the installer
resource "null_resource" "manifest_cleanup_control_plane_machineset" {
  depends_on = [
    null_resource.generate_manifests
  ]

  triggers = {
    install_config =  data.template_file.install_config_yaml.rendered
    local_file     =  local_file.install_config.id
  }

  provisioner "local-exec" {
    command = "rm -f .//temp/openshift/99_openshift-cluster-api_master-machines-*.yaml"
  }
}

# build the bootstrap ignition config
resource "null_resource" "generate_ignition_config" {
  depends_on = [
    null_resource.manifest_cleanup_control_plane_machineset,
    local_file.airgapped_registry_upgrades,
    local_file.create_worker_machineset,
    local_file.airgapped_registry_upgrades,
    local_file.cluster-dns-02-config,
    local_file.create_infra_machineset,
    local_file.cluster-monitoring-configmap,
    local_file.configure-image-registry-job-serviceaccount,
    local_file.configure-image-registry-job-clusterrole,
    local_file.configure-image-registry-job-clusterrolebinding,
    local_file.configure-image-registry-job,
    local_file.configure-ingress-job-serviceaccount,
    local_file.configure-ingress-job-clusterrole,
    local_file.configure-ingress-job-clusterrolebinding,
    local_file.configure-ingress-job,
  ]

  triggers = {
    install_config                   =  data.template_file.install_config_yaml.rendered
    local_file_install_config        =  local_file.install_config.id
  }

  provisioner "local-exec" {
    command = "mkdir -p .//temp"
  }

  provisioner "local-exec" {
    command = "rm -rf .//temp/_manifests .//temp/_openshift"
  }

  provisioner "local-exec" {
    command = "cp -r .//temp/manifests .//temp/_manifests"
  }

  provisioner "local-exec" {
    command = "cp -r .//temp/openshift .//temp/_openshift"
  }

  provisioner "local-exec" {
    command = ".//openshift-install --dir=.//temp create ignition-configs"
  }
}

resource "null_resource" "delete_aws_resources" {
  depends_on = [
    null_resource.cleanup
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/aws_cleanup.sh"
    #command = ".//openshift-install --dir=./temp destroy cluster"
  }

}

resource "null_resource" "cleanup" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf .//temp"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f .//openshift-install"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f .//oc"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f .//kubectl"
  }
}

data "local_file" "bootstrap_ign" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  filename =  ".//temp/bootstrap.ign"
}

data "local_file" "master_ign" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  filename =  ".//temp/master.ign"
}

data "local_file" "worker_ign" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  filename =  ".//temp/worker.ign"
}

resource "null_resource" "get_auth_config" {
  depends_on = [null_resource.generate_ignition_config]
  provisioner "local-exec" {
    when    = create
    command = "cp .//temp/auth/* ${path.root}/ "
  }
  provisioner "local-exec" {
    when    = destroy
    command = "rm ${path.root}/kubeconfig ${path.root}/kubeadmin-password "
  }
}
