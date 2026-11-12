data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name_prefix        = "${var.name}-"
  description        = "Outline VPN server instance role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = local.tags
}

resource "aws_iam_instance_profile" "this" {
  name_prefix = "${var.name}-"
  role        = aws_iam_role.this.name
  tags        = local.tags
}

# The instance publishes the Outline Manager config to exactly one parameter.
data "aws_iam_policy_document" "publish_manager_config" {
  statement {
    sid       = "PublishOutlineManagerConfig"
    actions   = ["ssm:PutParameter"]
    resources = [local.manager_config_parameter_arn]
  }
}

resource "aws_iam_role_policy" "publish_manager_config" {
  name_prefix = "publish-manager-config-"
  role        = aws_iam_role.this.id
  policy      = data.aws_iam_policy_document.publish_manager_config.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count = var.enable_ssm_session_manager ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
