region          = "us-east-1"          #--> ex: N. Virginia = "us-east-1",  São Paulo = "sa-east-1"
security_groups = [""]              #--> id do security groups
subnet_ids      = [""]              #--> id das subnet 
variables = {
      "foo" = "bar",
      "environment" = "dev",
      "function" = "lambda"
    }