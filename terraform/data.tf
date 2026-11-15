# Reads the auth Lambda functions (issuer + authorizer) from the workbench-lambda
# Terraform state, so their invoke ARNs don't have to be passed in manually.
data "terraform_remote_state" "lambda" {
  backend = "s3"
  config = {
    bucket = var.lambda_state_bucket
    key    = "lambda/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  issuer_invoke_arn          = data.terraform_remote_state.lambda.outputs.issuer_invoke_arn
  issuer_function_name       = data.terraform_remote_state.lambda.outputs.issuer_function_name
  staff_issuer_invoke_arn    = data.terraform_remote_state.lambda.outputs.staff_issuer_invoke_arn
  staff_issuer_function_name = data.terraform_remote_state.lambda.outputs.staff_issuer_function_name
  authorizer_invoke_arn      = data.terraform_remote_state.lambda.outputs.authorizer_invoke_arn
  authorizer_function_name   = data.terraform_remote_state.lambda.outputs.authorizer_function_name
}

# NLBs INTERNOS dos microsserviços (Service type LoadBalancer com
# aws-load-balancer-internal no k8s/app.yaml de cada serviço). O controlador da AWS
# marca cada NLB com a tag kubernetes.io/service-name = <namespace>/<service>; é por
# ela que o gateway os encontra, sem URL nem ARN passados à mão. Os serviços precisam
# estar no ar antes deste apply.
locals {
  k8s_services = {
    os        = "os-service/os-service"
    customer  = "customer-service/customer-service"
    billing   = "billing-service/billing-service"
    execution = "execution-service/execution-service"
  }
}

data "aws_lb" "service" {
  for_each = local.k8s_services
  tags = {
    "kubernetes.io/service-name" = each.value
  }
}
