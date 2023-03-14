locals {
  is_linux = length(regexall("/home/", lower(abspath(path.root)))) > 0
}

data "external" "subnet" {
  program = local.is_linux ? ["/bin/bash", "-c", "docker network inspect --format '{{json .IPAM.Config}}' kind | jq .[0]"] : ["powershell", "docker network inspect --format \"{{json .IPAM.Config}}\" kind | jq .[0]"]
  depends_on = [kind_cluster.k8s-cluster]
}

#https://github.com/metallb/metallb/issues/888
#kubectl create secret generic -n metallb-system metallb-memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
#kubectl create secret generic -n metallb metallb-memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
#kubectl create secret generic -n metallb memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
resource "null_resource" "memberlist" {
  provisioner "local-exec" {
    command = "kubectl create namespace metallb && kubectl create secret generic -n metallb memberlist --from-literal=secretkey='rDjRf01nnsng3XVjs3+CMS2wThYxJVZY+7jVvR0t7ggNTXZqaxce//hHb8UE6M5z699AVbqg9DK4Knad8X97m30arOEG6UijMGMLf4L9NuMLZ2cqVsozIdRhVQpCGNaHVoIJmygf0sA1hBQQa7UppUiGso95aOFIneQgIoLnTVg='"
  }
  depends_on = [kind_cluster.k8s-cluster]
}

resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = "metallb"
  version          = var.METALLB_VERSION
  create_namespace = true
  timeout          = 900
  # wait             = false
  values = [
  <<-EOF
  speaker:
    secretName: memberlist
  configInline:
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      # - ${cidrhost(data.external.subnet.result.Subnet, 150)}-${cidrhost(data.external.subnet.result.Subnet, 200)}
      # for mac
      - 127.0.0.1/32
  EOF
  ]
  depends_on = [
    kind_cluster.k8s-cluster
  ]
}
