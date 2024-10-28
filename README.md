# Technical-Assessment-Terraform
Requirements: - Terraform, Helm, Kubectl, Minikube

1. Run minikube 
`minikube start`

2. Configure kubectl to minikube
 `kubectl config use-context minikube`
3. Initialize a working directory containing Terraform configuration file
`terraform init`
4. Plan the deployment
`terraform plan`
5. Execute the actions proposed in a Terraform plan
`terraform apply`
6. Access the application
Open `http://httpd.local` in browser
