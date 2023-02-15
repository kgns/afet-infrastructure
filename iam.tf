resource "aws_iam_policy" "ecs_exec" {
  name        = "ecs-exec"
  description = "Policy for ECS exec command"
  policy      = data.aws_iam_policy_document.ecs_exec.json
}

data "aws_iam_policy_document" "ecs_exec" {
  statement {
    effect = "Allow"

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]

    resources = ["*"]
  }
}
