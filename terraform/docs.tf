# =============================================================================
# Documentação pública da API (Swagger UI)
#
#   GET /docs                    página Swagger UI (seletor dos 4 serviços)
#   GET /docs/<serviço>.json     OpenAPI de cada serviço
#
# - Tudo é MOCK do API Gateway: não passa por VPC Link, NLB nem pelos serviços. A página e os specs
#   são arquivos de terraform/docs/ (gerados do que roda no cluster).
# - Sem authorizer (authorization = NONE), como /auth: documentação não é segredo. A API em si
#   continua protegida: o "Try it out" chama as rotas reais, no mesmo endereço, com o JWT do usuário
#   (Authorize), então não precisa de CORS.
# - servers.url dos specs é "/<estágio>" (o Terraform troca /__STAGE__ por var.environment). Uma URL
#   relativa como "../" depende da barra final de /docs: o Swagger UI resolve contra a página e erraria.
# - Mapping templates são VTL: "$" e "#" do conteúdo são escapados com ${D} e ${H}, senão o "$ref" do
#   OpenAPI sumiria (testado em um REST API descartável: o JSON volta idêntico).
# =============================================================================

locals {
  docs_specs = toset(["os-service", "customer-service", "billing-service", "execution-service"])

  docs_index_template = "#set($D = '$')#set($H = '#')${replace(replace(file("${path.module}/docs/index.html"), "$", "$${D}"), "#", "$${H}")}"

  docs_spec_templates = {
    for s in local.docs_specs :
    s => "#set($D = '$')#set($H = '#')${replace(replace(replace(jsonencode(jsondecode(file("${path.module}/docs/${s}.json"))), "/__STAGE__", "/${var.environment}"), "$", "$${D}"), "#", "$${H}")}"
  }
}

resource "aws_api_gateway_resource" "docs" {
  rest_api_id = aws_api_gateway_rest_api.os_management.id
  parent_id   = aws_api_gateway_rest_api.os_management.root_resource_id
  path_part   = "docs"
}

resource "aws_api_gateway_method" "docs_index" {
  rest_api_id   = aws_api_gateway_rest_api.os_management.id
  resource_id   = aws_api_gateway_resource.docs.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "docs_index" {
  rest_api_id = aws_api_gateway_rest_api.os_management.id
  resource_id = aws_api_gateway_resource.docs.id
  http_method = aws_api_gateway_method.docs_index.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "docs_index" {
  rest_api_id = aws_api_gateway_rest_api.os_management.id
  resource_id = aws_api_gateway_resource.docs.id
  http_method = aws_api_gateway_method.docs_index.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Content-Type" = true
  }
}

resource "aws_api_gateway_integration_response" "docs_index" {
  rest_api_id = aws_api_gateway_rest_api.os_management.id
  resource_id = aws_api_gateway_resource.docs.id
  http_method = aws_api_gateway_method.docs_index.http_method
  status_code = aws_api_gateway_method_response.docs_index.status_code

  response_parameters = {
    "method.response.header.Content-Type" = "'text/html; charset=utf-8'"
  }

  response_templates = {
    "application/json" = local.docs_index_template
  }

  depends_on = [aws_api_gateway_integration.docs_index]
}

# --- /docs/<serviço>.json ---------------------------------------------------------------------------

resource "aws_api_gateway_resource" "docs_spec" {
  for_each    = local.docs_specs
  rest_api_id = aws_api_gateway_rest_api.os_management.id
  parent_id   = aws_api_gateway_resource.docs.id
  path_part   = "${each.key}.json"
}

resource "aws_api_gateway_method" "docs_spec" {
  for_each      = local.docs_specs
  rest_api_id   = aws_api_gateway_rest_api.os_management.id
  resource_id   = aws_api_gateway_resource.docs_spec[each.key].id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "docs_spec" {
  for_each    = local.docs_specs
  rest_api_id = aws_api_gateway_rest_api.os_management.id
  resource_id = aws_api_gateway_resource.docs_spec[each.key].id
  http_method = aws_api_gateway_method.docs_spec[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "docs_spec" {
  for_each    = local.docs_specs
  rest_api_id = aws_api_gateway_rest_api.os_management.id
  resource_id = aws_api_gateway_resource.docs_spec[each.key].id
  http_method = aws_api_gateway_method.docs_spec[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Content-Type" = true
  }
}

resource "aws_api_gateway_integration_response" "docs_spec" {
  for_each    = local.docs_specs
  rest_api_id = aws_api_gateway_rest_api.os_management.id
  resource_id = aws_api_gateway_resource.docs_spec[each.key].id
  http_method = aws_api_gateway_method.docs_spec[each.key].http_method
  status_code = aws_api_gateway_method_response.docs_spec[each.key].status_code

  response_parameters = {
    "method.response.header.Content-Type" = "'application/json'"
  }

  response_templates = {
    "application/json" = local.docs_spec_templates[each.key]
  }

  depends_on = [aws_api_gateway_integration.docs_spec]
}
