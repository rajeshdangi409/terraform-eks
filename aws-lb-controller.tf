data "tls_certificate" "eks" {
  url = aws_eks_cluster.my_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.my_cluster.identity[0].oidc[0].issuer
}

data "http" "aws_lb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "aws_lb_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "AWS Load Balancer Controller IAM Policy"
  policy      = data.http.aws_lb_controller_policy.response_body
}

data "aws_iam_policy_document" "aws_lb_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws_lb_controller" {
  assume_role_policy = data.aws_iam_policy_document.aws_lb_controller_assume_role_policy.json
  name               = "aws-load-balancer-controller-role"
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller_attach" {
  role       = aws_iam_role.aws_lb_controller.name
  policy_arn = aws_iam_policy.aws_lb_controller.arn
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.my_cluster.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.my_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.my_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.my_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.my_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  timeout    = 1800
  wait       = true

  set = [
    {
      name  = "clusterName"
      value = aws_eks_cluster.my_cluster.name
    },
    {
      name  = "region"
      value = "ap-south-1"
    },
    {
      name  = "vpcId"
      value = aws_vpc.eks_vpc.id
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.aws_lb_controller.arn
    }
  ]

  depends_on = [aws_eks_node_group.my_nodes, aws_iam_role_policy_attachment.aws_lb_controller_attach]
}